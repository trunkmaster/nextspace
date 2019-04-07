
/*
 * Handle events for non-GUI based applications
 */

#include "WINGsP.h"

void WHandleEvents()
{
	/* Check any expired timers */
	W_CheckTimerHandlers();

	/* Do idle and timer stuff while there are no input events */
	/* Do not wait for input here. just peek to see if input is available */
	while (!W_HandleInputEvents(False, -1) && W_CheckIdleHandlers()) {
		/* dispatch timer events */
		W_CheckTimerHandlers();
	}

	W_HandleInputEvents(True, -1);

	/* Check any expired timers */
	W_CheckTimerHandlers();
}
