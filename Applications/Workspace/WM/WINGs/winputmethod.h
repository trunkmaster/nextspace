#ifndef __WORKSPACE_WM_WINPUTMETHOD__
#define __WORKSPACE_WM_WINPUTMETHOD__

void W_InitIM(WMScreen *scr);

void W_CreateIC(WMView *view);

void W_DestroyIC(WMView *view);

void W_FocusIC(WMView *view);

void W_UnFocusIC(WMView *view);

void W_SetPreeditPositon(W_View *view, int x, int y);

int W_LookupString(W_View *view, XKeyPressedEvent *event, char *buffer,
                   int buflen, KeySym *keysym, Status *status);

#endif
