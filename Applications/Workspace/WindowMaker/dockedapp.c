/* dockedapp.c- docked application settings panel
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 1998-2003 Alfredo K. Kojima
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */


#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdlib.h>
#include <string.h>

#include "WindowMaker.h"
#include "wcore.h"
#include "window.h"
#include "icon.h"
#include "appicon.h"
#include "dock.h"
#include "dialog.h"
#include "funcs.h"
#include "defaults.h"
#include "framewin.h"
#include "xinerama.h"


/**** Global variables ****/
extern WPreferences wPreferences;



typedef struct _AppSettingsPanel {
    WMWindow *win;
    WAppIcon *editedIcon;

    WWindow *wwin;

    WMLabel *iconLabel;
    WMLabel *nameLabel;

    WMFrame *commandFrame;
    WMTextField *commandField;

    WMFrame *dndCommandFrame;
    WMTextField *dndCommandField;
    WMLabel *dndCommandLabel;

    WMFrame *pasteCommandFrame;
    WMTextField *pasteCommandField;
    WMLabel *pasteCommandLabel;

    WMFrame *iconFrame;
    WMTextField *iconField;
    WMButton *browseBtn;

    WMButton *autoLaunchBtn;
    WMButton *lockBtn;

    WMButton *okBtn;
    WMButton *cancelBtn;

    Window parent;

    /* kluge */
    unsigned int destroyed:1;
    unsigned int choosingIcon:1;
} AppSettingsPanel;


void DestroyDockAppSettingsPanel(AppSettingsPanel *panel);


static void
updateCommand(WAppIcon *icon, char *command)
{
    if (icon->command)
        wfree(icon->command);
    if (command && (command[0]==0 || (command[0]=='-' && command[1]==0))) {
        wfree(command);
        command = NULL;
    }
    icon->command = command;

    if (!icon->wm_class && !icon->wm_instance && icon->command
        && strlen(icon->command)>0) {
        icon->forced_dock = 1;
    }
}


static void
updatePasteCommand(WAppIcon *icon, char *command)
{
    if (icon->paste_command)
        wfree(icon->paste_command);
    if (command && (command[0]==0 || (command[0]=='-' && command[1]==0))) {
        wfree(command);
        command = NULL;
    }
    icon->paste_command = command;
}



#ifdef XDND
static void
updateDNDCommand(WAppIcon *icon, char *command)
{
    if (icon->dnd_command)
        wfree(icon->dnd_command);
    if (command && (command[0]==0 || (command[0]=='-' && command[1]==0))) {
        wfree(command);
        command = NULL;
    }
    icon->dnd_command = command;
}
#endif /* XDND */


static void
updateSettingsPanelIcon(AppSettingsPanel *panel)
{
    char *file;

    file = WMGetTextFieldText(panel->iconField);
    if (!file)
        WMSetLabelImage(panel->iconLabel, NULL);
    else {
        char *path;

        path = FindImage(wPreferences.icon_path, file);
        if (!path) {
            wwarning(_("could not find icon %s, used in a docked application"),
                     file);
            wfree(file);
            WMSetLabelImage(panel->iconLabel, NULL);
            return;
        } else {
            WMPixmap *pixmap;
            RColor color;

            color.red = 0xae;
            color.green = 0xaa;
            color.blue = 0xae;
            color.alpha = 0;
            pixmap = WMCreateBlendedPixmapFromFile(WMWidgetScreen(panel->win),
                                                   path, &color);
            if (!pixmap) {
                WMSetLabelImage(panel->iconLabel, NULL);
            } else {
                WMSetLabelImage(panel->iconLabel, pixmap);
                WMReleasePixmap(pixmap);
            }
        }
        wfree(file);
        wfree(path);
    }
}


static void
chooseIconCallback(WMWidget *self, void *clientData)
{
    char *file;
    AppSettingsPanel *panel = (AppSettingsPanel*)clientData;
    int result;

    panel->choosingIcon = 1;

    WMSetButtonEnabled(panel->browseBtn, False);

    result = wIconChooserDialog(panel->wwin->screen_ptr, &file,
                                panel->editedIcon->wm_instance,
                                panel->editedIcon->wm_class);

    panel->choosingIcon = 0;
    if (!panel->destroyed) {
        if (result) {
            WMSetTextFieldText(panel->iconField, file);
            wfree(file);
            updateSettingsPanelIcon(panel);
        }

        WMSetButtonEnabled(panel->browseBtn, True);
    } else {
        /* kluge for the case, the user asked to close the panel before
         * the icon chooser */
        DestroyDockAppSettingsPanel(panel);
    }
}


static void
panelBtnCallback(WMWidget *self, void *data)
{
    WMButton *btn = self;
    AppSettingsPanel *panel = (AppSettingsPanel*)data;
    char *text;
    int done;

    done = 1;
    if (panel->okBtn == btn) {
        text = WMGetTextFieldText(panel->iconField);
        if (text[0]==0) {
            wfree(text);
            text = NULL;
        }
        if (!wIconChangeImageFile(panel->editedIcon->icon, text)) {
            char *buf;
            int len = strlen(text) + 64;

            buf = wmalloc(len);
            snprintf(buf, len, _("Could not open specified icon file: %s"), text);
            if (wMessageDialog(panel->wwin->screen_ptr, _("Error"), buf,
                               _("OK"), _("Ignore"), NULL) == WAPRDefault) {
                if (text)
                    wfree(text);
                wfree(buf);
                return;
            }
            wfree(buf);
        } else {
            WAppIcon *aicon = panel->editedIcon;

            if (aicon == aicon->icon->core->screen_ptr->clip_icon)
                wClipIconPaint(aicon);
            else
                wAppIconPaint(aicon);

            wDefaultChangeIcon(panel->wwin->screen_ptr, aicon->wm_instance,
                               aicon->wm_class, text);
        }
        if (text)
            wfree(text);

        /* cannot free text from this, because it will be not be duplicated
         * in updateCommand */
        text = WMGetTextFieldText(panel->commandField);
        if (text[0]==0) {
            wfree(text);
            text = NULL;
        }
        updateCommand(panel->editedIcon, text);
#ifdef XDND
        /* cannot free text from this, because it will be not be duplicated
         * in updateDNDCommand */
        text = WMGetTextFieldText(panel->dndCommandField);
        updateDNDCommand(panel->editedIcon, text);
#endif
        text = WMGetTextFieldText(panel->pasteCommandField);
        updatePasteCommand(panel->editedIcon, text);


        panel->editedIcon->auto_launch =
            WMGetButtonSelected(panel->autoLaunchBtn);

        panel->editedIcon->lock =
            WMGetButtonSelected(panel->lockBtn);
    }

    if (done)
        DestroyDockAppSettingsPanel(panel);
}


#define PWIDTH	295
#define PHEIGHT	430


void
ShowDockAppSettingsPanel(WAppIcon *aicon)
{
    AppSettingsPanel *panel;
    WScreen *scr = aicon->icon->core->screen_ptr;
    Window parent;
    WMFont *font;
    int x, y;
    WMBox *vbox;

    panel = wmalloc(sizeof(AppSettingsPanel));
    memset(panel, 0, sizeof(AppSettingsPanel));

    panel->editedIcon = aicon;

    aicon->panel = panel;
    aicon->editing = 1;

    panel->win = WMCreateWindow(scr->wmscreen, "applicationSettings");
    WMResizeWidget(panel->win, PWIDTH, PHEIGHT);

    panel->iconLabel = WMCreateLabel(panel->win);
    WMResizeWidget(panel->iconLabel, 64, 64);
    WMMoveWidget(panel->iconLabel, 10, 10);
    WMSetLabelImagePosition(panel->iconLabel, WIPImageOnly);

    panel->nameLabel = WMCreateLabel(panel->win);
    WMResizeWidget(panel->nameLabel, 190, 18);
    WMMoveWidget(panel->nameLabel, 80, 35);
    WMSetLabelTextAlignment(panel->nameLabel, WALeft);
    font = WMBoldSystemFontOfSize(scr->wmscreen, 14);
    WMSetLabelFont(panel->nameLabel, font);
    WMReleaseFont(font);
    if (aicon->wm_class && strcmp(aicon->wm_class, "DockApp")==0)
        WMSetLabelText(panel->nameLabel, aicon->wm_instance);
    else
        WMSetLabelText(panel->nameLabel, aicon->wm_class);


    vbox = WMCreateBox(panel->win);
    WMResizeWidget(vbox, PWIDTH-20, PHEIGHT-84-10);
    WMMoveWidget(vbox, 10, 84);

    panel->autoLaunchBtn = WMCreateSwitchButton(vbox);
    WMAddBoxSubview(vbox, WMWidgetView(panel->autoLaunchBtn), False, True,
                    20, 20, 2);
    WMSetButtonText(panel->autoLaunchBtn,
                    _("Start when Window Maker is started"));
    WMSetButtonSelected(panel->autoLaunchBtn, aicon->auto_launch);

    panel->lockBtn = WMCreateSwitchButton(vbox);
    WMAddBoxSubview(vbox, WMWidgetView(panel->lockBtn), False, True,
                    20, 20, 5);
    WMSetButtonText(panel->lockBtn,
                    _("Lock (prevent accidental removal)"));
    WMSetButtonSelected(panel->lockBtn, aicon->lock);

    panel->commandFrame = WMCreateFrame(vbox);
    WMSetFrameTitle(panel->commandFrame, _("Application path and arguments"));
    WMAddBoxSubview(vbox, WMWidgetView(panel->commandFrame), False, True,
                    50, 50, 5);

    panel->commandField = WMCreateTextField(panel->commandFrame);
    WMResizeWidget(panel->commandField, 256, 20);
    WMMoveWidget(panel->commandField, 10, 20);
    WMSetTextFieldText(panel->commandField, aicon->command);

    WMMapSubwidgets(panel->commandFrame);

    panel->pasteCommandFrame = WMCreateFrame(vbox);
    WMSetFrameTitle(panel->pasteCommandFrame,
                    _("Command for middle-click launch"));
    WMAddBoxSubview(vbox, WMWidgetView(panel->pasteCommandFrame), False, True,
                    70, 70, 5);

    panel->pasteCommandField = WMCreateTextField(panel->pasteCommandFrame);
    WMResizeWidget(panel->pasteCommandField, 256, 20);
    WMMoveWidget(panel->pasteCommandField, 10, 20);

    panel->pasteCommandLabel = WMCreateLabel(panel->pasteCommandFrame);
    WMResizeWidget(panel->pasteCommandLabel, 256, 18);
    WMMoveWidget(panel->pasteCommandLabel, 10, 45);

    WMSetTextFieldText(panel->pasteCommandField, aicon->paste_command);
    WMSetLabelText(panel->pasteCommandLabel,
                   _("%s will be replaced with current selection"));
    WMMapSubwidgets(panel->pasteCommandFrame);

    panel->dndCommandFrame = WMCreateFrame(vbox);
    WMSetFrameTitle(panel->dndCommandFrame,
                    _("Command for files dropped with DND"));
    WMAddBoxSubview(vbox, WMWidgetView(panel->dndCommandFrame), False, True,
                    70, 70, 5);

    panel->dndCommandField = WMCreateTextField(panel->dndCommandFrame);
    WMResizeWidget(panel->dndCommandField, 256, 20);
    WMMoveWidget(panel->dndCommandField, 10, 20);

    panel->dndCommandLabel = WMCreateLabel(panel->dndCommandFrame);
    WMResizeWidget(panel->dndCommandLabel, 256, 18);
    WMMoveWidget(panel->dndCommandLabel, 10, 45);
#ifdef XDND
    WMSetTextFieldText(panel->dndCommandField, aicon->dnd_command);
    WMSetLabelText(panel->dndCommandLabel,
                   _("%d will be replaced with the file name"));
#else
    WMSetTextFieldEditable(panel->dndCommandField, False);
    WMSetLabelText(panel->dndCommandLabel,
                   _("DND support was not compiled in"));
#endif
    WMMapSubwidgets(panel->dndCommandFrame);

    panel->iconFrame = WMCreateFrame(vbox);
    WMSetFrameTitle(panel->iconFrame, _("Icon Image"));
    WMAddBoxSubview(vbox, WMWidgetView(panel->iconFrame), False, True,
                    50, 50, 10);

    panel->iconField = WMCreateTextField(panel->iconFrame);
    WMResizeWidget(panel->iconField, 176, 20);
    WMMoveWidget(panel->iconField, 10, 20);
    WMSetTextFieldText(panel->iconField,
                       wDefaultGetIconFile(scr, aicon->wm_instance,
                                           aicon->wm_class, True));

    panel->browseBtn = WMCreateCommandButton(panel->iconFrame);
    WMResizeWidget(panel->browseBtn, 70, 24);
    WMMoveWidget(panel->browseBtn, 195, 18);
    WMSetButtonText(panel->browseBtn, _("Browse..."));
    WMSetButtonAction(panel->browseBtn, chooseIconCallback, panel);


    {
        WMBox *hbox;

        hbox = WMCreateBox(vbox);
        WMSetBoxHorizontal(hbox, True);
        WMAddBoxSubview(vbox, WMWidgetView(hbox), False, True, 24, 24, 0);


        panel->okBtn = WMCreateCommandButton(hbox);
        WMSetButtonText(panel->okBtn, _("OK"));
        WMSetButtonAction(panel->okBtn, panelBtnCallback, panel);
        WMAddBoxSubviewAtEnd(hbox, WMWidgetView(panel->okBtn), False, True, 80, 80, 0);

        panel->cancelBtn = WMCreateCommandButton(hbox);
        WMSetButtonText(panel->cancelBtn, _("Cancel"));
        WMSetButtonAction(panel->cancelBtn, panelBtnCallback, panel);
        WMAddBoxSubviewAtEnd(hbox, WMWidgetView(panel->cancelBtn), False, True, 80, 80, 5);

        WMMapSubwidgets(hbox);
    }

    WMRealizeWidget(panel->win);
    WMMapSubwidgets(panel->win);
    WMMapSubwidgets(vbox);
    WMMapSubwidgets(panel->iconFrame);

    updateSettingsPanelIcon(panel);

    parent = XCreateSimpleWindow(dpy, scr->root_win, 0, 0, PWIDTH, PHEIGHT,
                                 0, 0, 0);
    XSelectInput(dpy, parent, KeyPressMask|KeyReleaseMask);

    XReparentWindow(dpy, WMWidgetXID(panel->win), parent, 0, 0);

    /*
     * make things relative to head
     */
    {
        WMRect rect = wGetRectForHead(scr, wGetHeadForPointerLocation(scr));

        y = aicon->y_pos;
        if (y < 0)
            y = 0;
        else if (y + PHEIGHT > rect.pos.y + rect.size.height)
            y = rect.pos.y + rect.size.height - PHEIGHT - 30;

        if (aicon->dock && aicon->dock->type == WM_DOCK) {
            if (aicon->dock->on_right_side)
                x = rect.pos.x + rect.size.width/2;
            else
                x = rect.pos.x + rect.size.width/2 - PWIDTH - 2;
        } else {
            x = rect.pos.x + (rect.size.width - PWIDTH)/2;
        }
    }

    panel->wwin = wManageInternalWindow(scr, parent, None,
                                        _("Docked Application Settings"),
                                        x, y, PWIDTH, PHEIGHT);

    panel->wwin->client_leader = WMWidgetXID(panel->win);

    panel->parent = parent;

    WMMapWidget(panel->win);

    wWindowMap(panel->wwin);
}


void
DestroyDockAppSettingsPanel(AppSettingsPanel *panel)
{
    if (!panel->destroyed) {
        XUnmapWindow(dpy, panel->wwin->client_win);
        XReparentWindow(dpy, panel->wwin->client_win,
                        panel->wwin->screen_ptr->root_win, 0, 0);
        wUnmanageWindow(panel->wwin, False, False);
    }

    panel->destroyed = 1;

    /*
     * kluge. If we destroy the panel before the icon chooser is closed,
     * we will crash when it does close, trying to access something in the
     * destroyed panel. Could use wretain()/wrelease() in the panel,
     * but it is not working for some reason.
     */
    if (panel->choosingIcon)
        return;

    WMDestroyWidget(panel->win);

    XDestroyWindow(dpy, panel->parent);

    panel->editedIcon->panel = NULL;

    panel->editedIcon->editing = 0;

    wfree(panel);
}

