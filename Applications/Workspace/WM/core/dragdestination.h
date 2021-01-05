#ifndef __WORKSPACE_WM_WDRAGDESTINATION__
#define __WORKSPACE_WM_WDRAGDESTINATION__

/* ---[ WINGs/dragdestination.c ]----------------------------------------- */

void WMRegisterViewForDraggedTypes(WMView *view, CFMutableArrayRef acceptedTypes);

void WMUnregisterViewDraggedTypes(WMView *view);

void WMSetViewDragDestinationProcs(WMView *view, WMDragDestinationProcs *procs);

#endif
