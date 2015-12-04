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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */


#ifndef WMDIALOG_H_
#define WMDIALOG_H_


enum {
    WMAbort=0,
    WMRestart,
    WMStartAlternate
};


int wMessageDialog(WScreen *scr, char *title, char *message,
                   char *defBtn, char *altBtn, char *othBtn);
int wInputDialog(WScreen *scr, char *title, char *message, char **text);

int wExitDialog(WScreen *scr, char *title, char *message, char *defBtn,
                char *altBtn, char *othBtn);

Bool wIconChooserDialog(WScreen *scr, char **file, char *instance, char *class);

void wShowInfoPanel(WScreen *scr);

void wShowLegalPanel(WScreen *scr);

void wShowGNUstepPanel(WScreen *scr);

int wShowCrashingDialogPanel(int whatSig);


#endif
