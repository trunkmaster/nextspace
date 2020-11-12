#ifndef _WHANDLERS_H_
#define _WHANDLERS_H_

#include <WINGs/WINGs.h>

Bool W_CheckIdleHandlers(void);

void W_CheckTimerHandlers(void);

Bool W_HandleInputEvents(Bool waitForInput, int inputfd);

#endif
