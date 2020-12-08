#ifndef __WORKSPACE_WM_WBALLOON__
#define __WORKSPACE_WM_WBALLOON__

struct W_Balloon *W_CreateBalloon(WMScreen *scr);

void W_BalloonHandleEnterView(WMView *view);

void W_BalloonHandleLeaveView(WMView *view);

/* ---[ WINGs/wballoon.c ]------------------------------------------------ */

void WMSetBalloonTextForView(const char *text, WMView *view);

void WMSetBalloonTextAlignment(WMScreen *scr, WMAlignment alignment);

void WMSetBalloonFont(WMScreen *scr, WMFont *font);

void WMSetBalloonTextColor(WMScreen *scr, WMColor *color);

void WMSetBalloonDelay(WMScreen *scr, int delay);

void WMSetBalloonEnabled(WMScreen *scr, Bool flag);

#endif
