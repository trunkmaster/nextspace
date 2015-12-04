/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2004 Alfredo K. Kojima
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

#ifndef _SWITCHPANEL_H_
#define _SWITCHPANEL_H_

typedef struct SwitchPanel WSwitchPanel;

WSwitchPanel *wInitSwitchPanel(WScreen *scr, WWindow *curwin, int workspace);

void wSwitchPanelDestroy(WSwitchPanel *panel);

WWindow *wSwitchPanelSelectNext(WSwitchPanel *panel, int back);
WWindow *wSwitchPanelSelectFirst(WSwitchPanel *panel, int back);

WWindow *wSwitchPanelHandleEvent(WSwitchPanel *panel, XEvent *event);

Window wSwitchPanelGetWindow(WSwitchPanel *swpanel);

#endif /* _SWITCHPANEL_H_ */
