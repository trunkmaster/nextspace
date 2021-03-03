#include "window.h"
#include "icon.h"
#include "appicon.h"
#include "xrandr.h"
#include "defaults.h"
#include "dock.h"
#include "framewin.h"
#include "misc.h"
#include "iconyard.h"

void wIconYardShowIcons(WScreen *screen)
{
  WAppIcon *appicon = screen->app_icon_list;
  WWindow  *wwin;

  // Miniwindows
  wwin = screen->focused_window;
  while (wwin) {
    if (wwin && wwin->flags.miniaturized &&
        wwin->icon && !wwin->icon->mapped ) {
      XMapWindow(dpy, wwin->icon->core->window);
      wwin->icon->mapped = 1;
    }
    wwin = wwin->prev;
  }
  
  // Appicons
  appicon = screen->app_icon_list;
  while (appicon) {
    if (!appicon->docked) {
      XMapWindow(dpy, appicon->icon->core->window);
    }
    appicon = appicon->next;
  }
  
  XSync(dpy, False);
  screen->flags.icon_yard_mapped = 1;
  // wArrangeIcons(screen, True);
}

void wIconYardHideIcons(WScreen *screen)
{
  WAppIcon *appicon = screen->app_icon_list;
  WWindow  *wwin;

  // Miniwindows
  wwin = screen->focused_window;
  while (wwin) {
    if (wwin && wwin->flags.miniaturized &&
        wwin->icon && wwin->icon->mapped ) {
      XUnmapWindow(dpy, wwin->icon->core->window);
      wwin->icon->mapped = 0;
    }
    wwin = wwin->prev;
  }

  // Appicons
  appicon = screen->app_icon_list;
  while (appicon) {
    if (!appicon->docked) {
      XUnmapWindow(dpy, appicon->icon->core->window);
    }
    appicon = appicon->next;
  }
  
  XSync(dpy, False);
  screen->flags.icon_yard_mapped = 0;
}

void wArrangeIcons(WScreen *scr, Bool arrangeAll)
{
  WWindow *wwin;
  WAppIcon *aicon;

  int head;
  const int heads = wScreenHeads(scr);

  struct HeadVars {
    int pf;		/* primary axis */
    int sf;		/* secondary axis */
    int fullW;
    int fullH;
    int pi, si;
    int sx1, sx2, sy1, sy2;	/* screen boundary */
    int sw, sh;
    int xo, yo;
    int xs, ys;
  } *vars;

  int isize = wPreferences.icon_size;

  vars = (struct HeadVars *)wmalloc(sizeof(struct HeadVars) * heads);

  for (head = 0; head < heads; ++head) {
    WArea area = wGetUsableAreaForHead(scr, head, NULL, False);
    WMRect rect;

    if (scr->dock) {
      int offset = wPreferences.icon_size + DOCK_EXTRA_SPACE;

      if (scr->dock->on_right_side)
        area.x2 -= offset;
      else
        area.x1 += offset;
    }

    rect = WMMakeRect(area.x1, area.y1, area.x2 - area.x1, area.y2 - area.y1);

    vars[head].pi = vars[head].si = 0;
    vars[head].sx1 = rect.pos.x;
    vars[head].sy1 = rect.pos.y;
    vars[head].sw = rect.size.width;
    vars[head].sh = rect.size.height;
    vars[head].sx2 = vars[head].sx1 + vars[head].sw;
    vars[head].sy2 = vars[head].sy1 + vars[head].sh;
    vars[head].sw = isize * (vars[head].sw / isize);
    vars[head].sh = isize * (vars[head].sh / isize);
    vars[head].fullW = (vars[head].sx2 - vars[head].sx1) / isize;
    vars[head].fullH = (vars[head].sy2 - vars[head].sy1) / isize;

    /* icon yard boundaries */
    if (wPreferences.icon_yard & IY_VERT) {
      vars[head].pf = vars[head].fullH;
      vars[head].sf = vars[head].fullW;
    } else {
      vars[head].pf = vars[head].fullW;
      vars[head].sf = vars[head].fullH;
    }
    if (wPreferences.icon_yard & IY_RIGHT) {
      vars[head].xo = vars[head].sx2 - isize;
      vars[head].xs = -1;
    } else {
      vars[head].xo = vars[head].sx1;
      vars[head].xs = 1;
    }
    if (wPreferences.icon_yard & IY_TOP) {
      vars[head].yo = vars[head].sy1;
      vars[head].ys = 1;
    } else {
      vars[head].yo = vars[head].sy2 - isize;
      vars[head].ys = -1;
    }
  }

#define X ((wPreferences.icon_yard & IY_VERT)                           \
           ? vars[head].xo + vars[head].xs*(vars[head].si*isize)        \
           : vars[head].xo + vars[head].xs*(vars[head].pi*isize))

#define Y ((wPreferences.icon_yard & IY_VERT)                           \
           ? vars[head].yo + vars[head].ys*(vars[head].pi*isize)        \
           : vars[head].yo + vars[head].ys*(vars[head].si*isize))

  /* arrange application icons */
  aicon = scr->app_icon_list;
  /* reverse them to avoid unnecessarily sliding of icons */
  while (aicon && aicon->next)
    aicon = aicon->next;

  while (aicon) {
    if (!aicon->docked) {
      /* CHECK: can icon be NULL here ? */
      /* The intention here is to place the AppIcon on the head that
       * contains most of the applications _main_ window. */
      head = wGetHeadForWindow(aicon->icon->owner);

      if (aicon->x_pos != X || aicon->y_pos != Y) {
#ifdef USE_ANIMATIONS
        if (!wPreferences.no_animations)
          wSlideWindow(aicon->icon->core->window, aicon->x_pos, aicon->y_pos, X, Y);
#endif /* USE_ANIMATIONS */
      }
      wAppIconMove(aicon, X, Y);
      vars[head].pi++;
      if (vars[head].pi >= vars[head].pf) {
        vars[head].pi = 0;
        vars[head].si++;
      }
    }
    aicon = aicon->prev;
  }

  /* arrange miniwindows */
  wwin = scr->focused_window;
  /* reverse them to avoid unnecessarily shuffling */
  while (wwin && wwin->prev)
    wwin = wwin->prev;

  while (wwin) {
    if (wwin->icon && wwin->flags.miniaturized && !wwin->flags.hidden &&
        (wwin->frame->workspace == scr->current_workspace ||
         IS_OMNIPRESENT(wwin) || wPreferences.sticky_icons)) {

      head = wGetHeadForWindow(wwin);

      if (arrangeAll || !wwin->flags.icon_moved) {
        if (wwin->icon_x != X || wwin->icon_y != Y)
          wMoveWindow(wwin->icon->core->window, wwin->icon_x, wwin->icon_y, X, Y);

        wwin->icon_x = X;
        wwin->icon_y = Y;

        vars[head].pi++;
        if (vars[head].pi >= vars[head].pf) {
          vars[head].pi = 0;
          vars[head].si++;
        }
      }
    }
    if (arrangeAll)
      wwin->flags.icon_moved = 0;
    /* we reversed the order, so we use next */
    wwin = wwin->next;
  }

  wfree(vars);
}
