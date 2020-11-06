#ifndef _WDRAGSOURCE_H_
#define _WDRAGSOURCE_H_

/* ---[ WINGs/dragsource.c ]---------------------------------------------- */

void WMSetViewDragImage(WMView* view, WMPixmap *dragImage);

void WMReleaseViewDragImage(WMView* view);

void WMSetViewDragSourceProcs(WMView *view, WMDragSourceProcs *procs);

Bool WMIsDraggingFromView(WMView *view);

void WMDragImageFromView(WMView *view, XEvent *event);

/* Create a drag handler, associating drag event masks with dragEventProc */
void WMCreateDragHandler(WMView *view, WMEventProc *dragEventProc, void *clientData);

void WMDeleteDragHandler(WMView *view, WMEventProc *dragEventProc, void *clientData);

/* set default drag handler for view */
void WMSetViewDraggable(WMView *view, WMDragSourceProcs *procs, WMPixmap *dragImage);

void WMUnsetViewDraggable(WMView *view);

#endif
