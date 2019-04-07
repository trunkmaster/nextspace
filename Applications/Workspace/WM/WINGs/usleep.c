
#include <errno.h>
#include <time.h>

#include "WUtil.h"
#include "wconfig.h"

void wusleep(unsigned int usec)
{
	struct timespec tm;

	/* An arbitrary limit of 10 minutes -- in WM, if
	 * somethings wants to sleep anything even close to
	 * this, it's most likely an error.
	 */
	if (usec > 600000000)
		return;

	tm.tv_sec = usec / 1000000;
	tm.tv_nsec = (usec % 1000000) * 1000;

	while (nanosleep(&tm, &tm) == -1 && errno == EINTR)
		;

}

