#ifndef _WDRAGDESTINATION_H_
#define _WDRAGDESTINATION_H_

#include <WINGs/notification.h>

/* ---[ WINGs/dragdestination.c ]----------------------------------------- */

void WMRegisterViewForDraggedTypes(WMView *view, WMArray *acceptedTypes);

void WMUnregisterViewDraggedTypes(WMView *view);

void WMSetViewDragDestinationProcs(WMView *view, WMDragDestinationProcs *procs);

#endif
