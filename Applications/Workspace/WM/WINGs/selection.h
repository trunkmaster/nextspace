#ifndef __WORKSPACE_WM_WSELECTION__
#define __WORKSPACE_WM_WSELECTION__

typedef void WMSelectionCallback(WMView *view, Atom selection, Atom target,
                                 Time timestamp, void *cdata, WMData *data);

/* ---[ WINGs/selection.c ]----------------------------------------------- */

Bool WMCreateSelectionHandler(WMView *view, Atom selection, Time timestamp,
                              WMSelectionProcs *procs, void *cdata);

void WMDeleteSelectionHandler(WMView *view, Atom selection, Time timestamp);

Bool WMRequestSelection(WMView *view, Atom selection, Atom target,
                        Time timestamp, WMSelectionCallback *callback,
                        void *cdata);

void W_HandleSelectionEvent(XEvent *event);

#endif
