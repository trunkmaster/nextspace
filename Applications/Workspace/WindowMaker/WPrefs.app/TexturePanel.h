/* TexturePanel.h- texture editting panel
 *
 *  WPrefs - WindowMaker Preferences Program
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef TEXTUREPANEL_H_
#define TEXTUREPANEL_H_



typedef struct _TexturePanel TexturePanel;


TexturePanel *CreateTexturePanel(WMWindow *keyWindow);

void ShowTexturePanel(TexturePanel *panel);

void HideTexturePanel(TexturePanel *panel);

void SetTexturePanelTexture(TexturePanel *panel, const char *name,
                            WMPropList *texture);


char *GetTexturePanelTextureName(TexturePanel *panel);

WMPropList *GetTexturePanelTexture(TexturePanel *panel);

RImage *RenderTexturePanelTexture(TexturePanel *panel, unsigned width,
                                  unsigned height);

void SetTexturePanelOkAction(TexturePanel *panel, WMCallback *action,
                             void *clientData);

void SetTexturePanelCancelAction(TexturePanel *panel, WMCallback *action,
                                 void *clientData);

void SetTexturePanelPixmapPath(TexturePanel *panel, WMPropList *array);

#endif

