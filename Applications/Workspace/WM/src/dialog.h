/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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


#ifndef WMDIALOG_H_
#define WMDIALOG_H_


enum {
    WMAbort=0,
    WMRestart,
    WMStartAlternate
};


int wMessageDialog(WScreen *scr, const char *title, const char *message,
                   const char *defBtn, const char *altBtn, const char *othBtn);
int wAdvancedInputDialog(WScreen *scr, const char *title, const char *message, const char *name, char **text);
int wInputDialog(WScreen *scr, const char *title, const char *message, char **text);

int wExitDialog(WScreen *scr, const char *title, const char *message, const char *defBtn,
                const char *altBtn, const char *othBtn);

Bool wIconChooserDialog(WScreen *scr, char **file, const char *instance, const char *class);

void wShowInfoPanel(WScreen *scr);
void wShowLegalPanel(WScreen *scr);
int wShowCrashingDialogPanel(int whatSig);


#endif
