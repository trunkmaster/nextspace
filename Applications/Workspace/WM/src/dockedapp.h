/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef WMDOCKEDAPP_H_
#define WMDOCKEDAPP_H_


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
void ShowDockAppSettingsPanel(WAppIcon *aicon);

#endif
