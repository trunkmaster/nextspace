#ifndef _WDRAGDESTINATION_H_
#define _WDRAGDESTINATION_H_

/* ---[ WINGs/dragdestination.c ]----------------------------------------- */

void WMRegisterViewForDraggedTypes(WMView *view, CFMutableArrayRef acceptedTypes);

void WMUnregisterViewDraggedTypes(WMView *view);

void WMSetViewDragDestinationProcs(WMView *view, WMDragDestinationProcs *procs);

#endif
