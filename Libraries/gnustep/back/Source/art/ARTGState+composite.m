/*
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#include <math.h>

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSBitmapImageRep.h>

#include "ARTGState.h"
#include "x11/XWindowBuffer.h"
#include "blit.h"

@implementation ARTGState (composite)

/* Figure out what blit function we should use. If one or both of the
   windows are known to be totally opaque, we can optimize in many ways
   (see big table at the end of blit.m). Will set dst_need_alpha and blit_func
   if necessary. Returns new operation, or -1 it it's a noop. */
- (int)_composite_func:(BOOL)src_opaque
                      :(BOOL)src_transparent
                      :(BOOL)dst_opaque
                      :(BOOL *)dst_needs_alpha
                      :(int)op
                      :(void (**)(composite_run_t *c, int num))blit_func_r
{
  void (*blit_func)(composite_run_t * c, int num);

  *dst_needs_alpha = NO;
  *blit_func_r = blit_func = NULL;

  if (src_transparent) /* only happens with compositerect */
  {
    switch (op) {
      case NSCompositeCopy:
      case NSCompositeSourceIn:
      case NSCompositeSourceOut:
      case NSCompositeDestinationIn:
      case NSCompositeDestinationAtop:
      case NSCompositePlusDarker:
        return NSCompositeClear;

      case NSCompositeSourceOver:
      case NSCompositeSourceAtop:
      case NSCompositeDestinationOver:
      case NSCompositeDestinationOut:
      case NSCompositeXOR:
      case NSCompositeHighlight:
      case NSCompositePlusLighter:
        return -1; /* noop */
    }
  } else if (src_opaque && dst_opaque) { /* both source and destination are totally opaque */
    switch (op) {
      case NSCompositeSourceOver:
      case NSCompositeSourceIn:
      case NSCompositeSourceAtop:
      case NSCompositeHighlight:
        return NSCompositeCopy;

      case NSCompositeSourceOut:
      case NSCompositeDestinationOut:
      case NSCompositeXOR:
        return NSCompositeClear;

      case NSCompositeDestinationOver:
      case NSCompositeDestinationIn:
      case NSCompositeDestinationAtop:
        return -1; /* noop */

      case NSCompositePlusLighter:
        blit_func = DI.composite_plusl_oo;
        break;
      case NSCompositePlusDarker:
        blit_func = DI.composite_plusd_oo;
        break;
    }
  } else if (src_opaque) { /* source is opaque, destination has alpha */
    switch (op) {
      case NSCompositeSourceOver:
      case NSCompositeHighlight:
        return NSCompositeCopy;

      case NSCompositeSourceIn:
      case NSCompositeSourceAtop:
        blit_func = DI.composite_sin_oa;
        break;

      case NSCompositeSourceOut:
      case NSCompositeXOR:
        blit_func = DI.composite_sout_oa;
        break;

      case NSCompositeDestinationOver:
      case NSCompositeDestinationAtop:
        blit_func = DI.composite_dover_oa;
        break;

      case NSCompositeDestinationIn:
        return -1; /* noop */

      case NSCompositeDestinationOut:
        return NSCompositeClear;

      case NSCompositePlusLighter:
        blit_func = DI.composite_plusl_oa;
        break;
      case NSCompositePlusDarker:
        blit_func = DI.composite_plusd_oa;
        break;
    }
  } else if (dst_opaque) { /* source has alpha, destination is opaque */
    switch (op) {
      case NSCompositeCopy:
        *dst_needs_alpha = YES;
        break;

      case NSCompositeSourceOver:
      case NSCompositeSourceAtop:
      case NSCompositeHighlight:
        blit_func = DI.composite_sover_ao;
        break;

      case NSCompositeSourceIn:
        return NSCompositeCopy;

      case NSCompositeSourceOut:
        return NSCompositeClear;

      case NSCompositeDestinationOver:
        return -1; /* noop */

      case NSCompositeDestinationIn:
      case NSCompositeDestinationOut:
      case NSCompositeDestinationAtop:
      case NSCompositeXOR:
        *dst_needs_alpha = YES;
        goto both_have_alpha;

      case NSCompositePlusLighter:
        blit_func = DI.composite_plusl_ao;
        break;
      case NSCompositePlusDarker:
        blit_func = DI.composite_plusd_ao;
        break;
    }
  } else { /* both source and destination have alpha */
  both_have_alpha:
    switch (op) {
      case NSCompositeSourceOver:
      case NSCompositeHighlight:
        blit_func = DI.composite_sover_aa;
        break;
      case NSCompositeSourceIn:
        blit_func = DI.composite_sin_aa;
        break;
      case NSCompositeSourceOut:
        blit_func = DI.composite_sout_aa;
        break;
      case NSCompositeSourceAtop:
        blit_func = DI.composite_satop_aa;
        break;
      case NSCompositeDestinationOver:
        blit_func = DI.composite_dover_aa;
        break;
      case NSCompositeDestinationIn:
        blit_func = DI.composite_din_aa;
        break;
      case NSCompositeDestinationOut:
        blit_func = DI.composite_dout_aa;
        break;
      case NSCompositeDestinationAtop:
        blit_func = DI.composite_datop_aa;
        break;
      case NSCompositeXOR:
        blit_func = DI.composite_xor_aa;
        break;
      case NSCompositePlusLighter:
        blit_func = DI.composite_plusl_aa;
        break;
      case NSCompositePlusDarker:
        blit_func = DI.composite_plusd_aa;
        break;
    }
  }
  *blit_func_r = blit_func;
  return op;
}

static void copy_oo(composite_run_t *c, int num)
{
  memcpy(c->dst, c->src, num * DI.bytes_per_pixel);
}

static void copy_oa(composite_run_t *c, int num)
{
  memcpy(c->dst, c->src, num * DI.bytes_per_pixel);
  if (DI.inline_alpha) {
    unsigned char *dsta = c->dst + DI.inline_alpha_ofs;

    for (; num; num--, dsta += 4)
      *dsta = 0xff;
  } else
    memset(c->dsta, 0xff, num);
}

static void copy_aa(composite_run_t *c, int num)
{
  memcpy(c->dst, c->src, num * DI.bytes_per_pixel);
  if (!DI.inline_alpha)
    memcpy(c->dsta, c->srca, num);
}

/*
Handle compositing in transformed coordinate spaces. _rect_setup sets up
the a rect_trace_t structure, and each call to _rect_advance returns YES
and the left and right points on the next row, or NO if all rows are done.
*/
typedef struct {
  int x[4], y[4];
  int cy, ey;

  int left_delta;
  int lx, lx_frac, ldx, ldx_frac, l_de, le;
  int rx, rx_frac, rdx, rdx_frac, r_de, re;

  int cx0, cx1;
} rect_trace_t;

static void _rect_setup(rect_trace_t *t, NSRect r, int cx0, int cx1, NSAffineTransform *ctm, int up,
                        int *y0, NSPoint offset)
{
  float fx[4], fy[4];
  NSPoint p;

  t->cx0 = cx0;
  t->cx1 = cx1;

  p = r.origin;
  p = [ctm transformPoint:p];
  fx[0] = p.x;
  fy[0] = p.y;
  p = r.origin;
  p.x += r.size.width;
  p = [ctm transformPoint:p];
  fx[1] = p.x;
  fy[1] = p.y;
  p = r.origin;
  p.x += r.size.width;
  p.y += r.size.height;
  p = [ctm transformPoint:p];
  fx[2] = p.x;
  fy[2] = p.y;
  p = r.origin;
  p.y += r.size.height;
  p = [ctm transformPoint:p];
  fx[3] = p.x;
  fy[3] = p.y;

  if (fabs(fx[0] - floor(fx[0] + .5)) < 0.001)
    fx[0] = floor(fx[0] + .5);
  if (fabs(fx[1] - floor(fx[1] + .5)) < 0.001)
    fx[1] = floor(fx[1] + .5);
  if (fabs(fx[2] - floor(fx[2] + .5)) < 0.001)
    fx[2] = floor(fx[2] + .5);
  if (fabs(fx[3] - floor(fx[3] + .5)) < 0.001)
    fx[3] = floor(fx[3] + .5);
  if (fabs(fy[0] - floor(fy[0] + .5)) < 0.001)
    fy[0] = floor(fy[0] + .5);
  if (fabs(fy[1] - floor(fy[1] + .5)) < 0.001)
    fy[1] = floor(fy[1] + .5);
  if (fabs(fy[2] - floor(fy[2] + .5)) < 0.001)
    fy[2] = floor(fy[2] + .5);
  if (fabs(fy[3] - floor(fy[3] + .5)) < 0.001)
    fy[3] = floor(fy[3] + .5);

  t->x[0] = floor(fx[0]) - offset.x;
  t->y[0] = offset.y - floor(fy[0]);
  t->x[1] = floor(fx[1]) - offset.x;
  t->y[1] = offset.y - floor(fy[1]);
  t->x[2] = floor(fx[2]) - offset.x;
  t->y[2] = offset.y - floor(fy[2]);
  t->x[3] = floor(fx[3]) - offset.x;
  t->y[3] = offset.y - floor(fy[3]);

  /* If we're tracing the 'other way', we just flip the y-coordinates
  and unflip when returning them */
  if (up) {
    t->y[0] = -t->y[0];
    t->y[1] = -t->y[1];
    t->y[2] = -t->y[2];
    t->y[3] = -t->y[3];
  }

  t->cy = t->y[t->le = 0];
  if (t->y[1] < t->cy)
    t->cy = t->y[t->le = 1];
  if (t->y[2] < t->cy)
    t->cy = t->y[t->le = 2];
  if (t->y[3] < t->cy)
    t->cy = t->y[t->le = 3];
  t->re = t->le;

  t->ey = t->y[0];
  if (t->y[1] > t->ey)
    t->ey = t->y[1];
  if (t->y[2] > t->ey)
    t->ey = t->y[2];
  if (t->y[3] > t->ey)
    t->ey = t->y[3];

  if (t->x[(t->le + 1) & 3] < t->x[(t->le - 1) & 3])
    t->left_delta = 1;
  else
    t->left_delta = -1;

  /* silence the compiler */
  t->lx = t->lx_frac = t->ldx = t->ldx_frac = t->l_de = 0;
  t->rx = t->rx_frac = t->rdx = t->rdx_frac = t->r_de = 0;

  if (up)
    *y0 = -t->cy;
  else
    *y0 = t->cy;
}

static BOOL _rect_advance(rect_trace_t *t, int *x0, int *x1)
{
  int next;

  if (t->cy > t->ey)
    return NO;

  if (t->cy == t->y[t->le]) {
    next = (t->le + t->left_delta) & 3;
    if (t->y[t->le] == t->y[next]) {
      t->le = next;
      next = (t->le + t->left_delta) & 3;
    }
    t->l_de = t->y[next] - t->y[t->le];
    if (!t->l_de)
      return NO;
    t->lx = t->x[t->le];
    t->lx_frac = 0;
    t->ldx = (t->x[next] - t->x[t->le]) / t->l_de;
    t->ldx_frac = (t->x[next] - t->x[t->le]) % t->l_de;

    t->le = next;
  } else {
    t->lx += t->ldx;
    t->lx_frac += t->ldx_frac;
    if (t->lx_frac < 0)
      t->lx--, t->lx_frac += t->l_de;
    if (t->lx_frac > t->l_de)
      t->lx++, t->lx_frac -= t->l_de;
  }

  if (t->cy == t->y[t->re]) {
    next = (t->re - t->left_delta) & 3;
    if (t->y[t->re] == t->y[next]) {
      t->re = next;
      next = (t->re - t->left_delta) & 3;
    }
    t->r_de = t->y[next] - t->y[t->re];
    if (!t->r_de)
      return NO;
    t->rx = t->x[t->re];
    t->rx_frac = t->r_de - 1; /* TODO? */
    t->rdx = (t->x[next] - t->x[t->re]) / t->r_de;
    t->rdx_frac = (t->x[next] - t->x[t->re]) % t->r_de;

    t->re = next;
  } else {
    t->rx += t->rdx;
    t->rx_frac += t->rdx_frac;
    if (t->rx_frac < 0)
      t->rx--, t->rx_frac += t->r_de;
    if (t->rx_frac > t->r_de)
      t->rx++, t->rx_frac -= t->r_de;
  }

  if (t->rx > t->lx && t->rx >= t->cx0 && t->lx < t->cx1) {
    *x0 = t->lx - t->cx0;
    if (*x0 < 0)
      *x0 = 0;
    *x1 = t->rx - t->cx0;
    if (*x1 > t->cx1 - t->cx0)
      *x1 = t->cx1 - t->cx0;
  } else {
    *x0 = *x1 = 0;
  }

  t->cy++;

  return YES;
}

- (void)compositeGState:(GSGState *)source
               fromRect:(NSRect)aRect
                toPoint:(NSPoint)aPoint
                     op:(NSCompositingOperation)composite_op
{
  ARTGState *ags = (ARTGState *)source;
  unsigned char *dst, *dst_alpha, *src, *src_alpha;

  int op;
  void (*blit_func)(composite_run_t * c, int num) = NULL;

  NSPoint sp, dp;

  int cx0, cy0, cx1, cy1;
  int sx0, sy0;

  int sbpl, dbpl;
  int asbpl, adbpl;

  rect_trace_t state;

  /* 0 = top->down, 1 = bottom->up */
  /*
    TODO: this does not handle the horizontal case
    either 0=top->down, left->right, 2=top->down, right->left
    or keep 0 and add 2=top->down, make temporary copy of source
    could allocate a temporary array on the stack large enough to hold
    one row and do the operations on it
  */
  /* currently 2=top->down, be careful with overlapping rows */
  /* order=1 is handled generically by flipping sbpl and dbpl and
     adjusting the pointers. order=2 is handled specially */
  int order;

  int delta;

  if (!wi || !wi->data || !ags->wi || !ags->wi->data)
    return;
  if (all_clipped)
    return;

  {
    BOOL dst_needs_alpha;
    op = [self _composite_func:!ags->wi->has_alpha
                              :NO
                              :!wi->has_alpha
                              :&dst_needs_alpha
                              :composite_op
                              :&blit_func];
    if (op == -1)
      return;

    if (dst_needs_alpha) {
      [wi needsAlpha];
      if (!wi->has_alpha)
        return;
    }
  }

  /* these ignore the source window, so we send them off to
     compositerect: op: */
  if (op == NSCompositeClear || op == GSCompositeHighlight) {
    [self compositerect:NSMakeRect(aPoint.x, aPoint.y, aRect.size.width, aRect.size.height) op:op];
    return;
  }

  /* Set up all the pointers and clip things */

  dbpl = wi->bytes_per_line;
  sbpl = ags->wi->bytes_per_line;

  cx0 = clip_x0;
  cy0 = clip_y0;
  cx1 = clip_x1;
  cy1 = clip_y1;

  sp = [ags->ctm transformPoint:aRect.origin];
  sp.x = floor(sp.x - ags->offset.x);
  sp.y = floor(ags->offset.y - sp.y);
  dp = [ctm transformPoint:aPoint];
  dp.x = floor(dp.x - offset.x);
  dp.y = floor(offset.y - dp.y);

  if (dp.x - cx0 > sp.x)
    cx0 = dp.x - sp.x;
  if (dp.y - cy0 > sp.y)
    cy0 = dp.y - sp.y;

  if (cx1 - dp.x > ags->wi->sx - sp.x)
    cx1 = dp.x + ags->wi->sx - sp.x;
  if (cy1 - dp.y > ags->wi->sy - sp.y)
    cy1 = dp.y + ags->wi->sy - sp.y;

  sx0 = sp.x - dp.x + cx0;
  sy0 = sp.y - dp.y + cy0;

  dst = wi->data + cx0 * DI.bytes_per_pixel + cy0 * dbpl;
  src = ags->wi->data + sx0 * DI.bytes_per_pixel + sy0 * sbpl;

  if (ags->wi->has_alpha && op == NSCompositeCopy) {
    [wi needsAlpha];
    if (!wi->has_alpha)
      return;
  }

  if (ags->wi->has_alpha) {
    if (DI.inline_alpha)
      src_alpha = src;
    else
      src_alpha = ags->wi->alpha + sx0 + sy0 * ags->wi->sx;
    asbpl = ags->wi->sx;
  } else {
    src_alpha = NULL;
    asbpl = 0;
  }

  if (wi->has_alpha) {
    if (DI.inline_alpha)
      dst_alpha = dst;
    else
      dst_alpha = wi->alpha + cx0 + cy0 * wi->sx;
    adbpl = wi->sx;
  } else {
    dst_alpha = NULL;
    adbpl = 0;
  }

  cy1 -= cy0;
  cx1 -= cx0;

  if (cx0 < 0 || cy0 < 0 || cx0 + cx1 > wi->sx || cy0 + cy1 > wi->sy || sx0 < 0 || sy0 < 0 ||
      sx0 + cx1 > ags->wi->sx || sy0 + cy1 > ags->wi->sy) {
    NSLog(@"Warning: invalid coordinates in composite: (%g %g)+(%g %g) -> (%g %g) got (%i %i) (%i "
          @"%i) +(%i %i)",
          aRect.origin.x, aRect.origin.x, aRect.size.width, aRect.size.height, aPoint.x, aPoint.y,
          cx0, cy0, sx0, sy0, cx1, cy1);
    return;
  }

  if (cx1 <= 0 || cy1 <= 0)
    return;

  /* To handle overlapping areas properly, we sometimes need to do
     things bottom-up instead of top-down. If so, we flip the
     coordinates here. */
  order = 0;
  if (ags->wi == self->wi && sy0 <= cy0) {
    order = 1;
    dst += dbpl * (cy1 - 1);
    src += sbpl * (cy1 - 1);
    dst_alpha += adbpl * (cy1 - 1);
    src_alpha += asbpl * (cy1 - 1);
    dbpl = -dbpl;
    sbpl = -sbpl;
    adbpl = -adbpl;
    asbpl = -asbpl;
    if (sy0 == cy0) {
      if ((sx0 >= cx0 && sx0 <= cx0 + cx1) || (cx0 >= sx0 && cx0 <= sx0 + cx1)) {
        order = 2;
      }
    }
  }

  if (op == NSCompositeCopy) {
    if (ags->wi->has_alpha)
      blit_func = copy_aa;
    else if (wi->has_alpha)
      blit_func = copy_oa;
    else
      blit_func = copy_oo;
  }

  if (!blit_func) {
    NSLog(@"unimplemented: compositeGState: %p fromRect: (%g %g)+(%g %g) toPoint: (%g %g)  op: %i",
          source, aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height, aPoint.x,
          aPoint.y, op);
    return;
  }

  {
    int ry;
    int x0, x1;
    _rect_setup(&state, aRect, sx0, sx0 + cx1, ags->ctm, order, &ry, ags->offset);
    if (order) {
      if (ry < sy0)
        return;
      delta = sy0 + cy1 - ry;
    } else {
      if (ry >= sy0 + cy1)
        return;
      delta = ry - sy0;
    }

    if (delta > 0) {
      src += sbpl * delta;
      src_alpha += asbpl * delta;
      dst += dbpl * delta;
      dst_alpha += adbpl * delta;
    } else if (delta < 0) {
      delta = -delta;
      while (delta) {
        if (!_rect_advance(&state, &x0, &x1)) {
          break;
        }
        delta--;
      }
      if (delta)
        return;
    }
  }

  /* this breaks the alpha pointer in some, but that's ok since in
     all those cases, the alpha pointer isn't used (inline alpha or
     no alpha) */
  if (order == 2) {
    unsigned char tmpbuf[cx1 * DI.bytes_per_pixel];
    unsigned char tmpbufa[cx1];
    int y;
    composite_run_t c;
    int x0, x1;

    c.dst = dst;
    c.dsta = dst_alpha;
    c.src = tmpbuf;
    c.srca = tmpbufa;
    for (y = cy1 - delta - 1; y >= 0; y--) {
      if (!_rect_advance(&state, &x0, &x1))
        break;
      x1 -= x0;

      c.dst += x0 * DI.bytes_per_pixel;
      c.dsta += x0;
      /* TODO: update c.dst and c.dsta properly when x1==0 */

      if (x1) {
        memcpy(tmpbuf, src + x0 * DI.bytes_per_pixel, x1 * DI.bytes_per_pixel);
        if (ags->wi->has_alpha && !DI.inline_alpha)
          memcpy(tmpbufa, src_alpha + x0, x1);

        if (!clip_span) {
          blit_func(&c, x1);
          c.dst += dbpl - x0 * DI.bytes_per_pixel;
          c.dsta += adbpl - x0;
        } else {
          unsigned int *span, *end;
          BOOL state = NO;

          span = &clip_span[clip_index[y + cy0 - clip_y0]];
          end = &clip_span[clip_index[y + cy0 - clip_y0 + 1]];

          x0 = x0 + cx0 - clip_x0;
          x1 += x0;
          while (span != end && *span < x0) {
            state = !state;
            span++;
            if (span == end)
              break;
          }
          if (span != end) {
            while (span != end && *span < x1) {
              if (state)
                blit_func(&c, *span - x0);
              c.dst += (*span - x0) * DI.bytes_per_pixel;
              c.dsta += (*span - x0);
              c.src += (*span - x0) * DI.bytes_per_pixel;
              c.srca += (*span - x0);
              x0 = *span;

              state = !state;
              span++;
              if (span == end)
                break;
            }
            if (state)
              blit_func(&c, x1 - x0);
          }
          x0 = x0 - cx0 + clip_x0;
          c.dst += dbpl - x0 * DI.bytes_per_pixel;
          c.dsta += adbpl - x0;
          c.src = tmpbuf;
          c.srca = tmpbufa;
        }
      }

      src += sbpl;
      src_alpha += asbpl;
    }
  } else {
    int y;
    composite_run_t c;
    int x0, x1;

    c.dst = dst;
    c.dsta = dst_alpha;
    c.src = src;
    c.srca = src_alpha;
    if (order)
      y = cy1 - delta - 1;
    else
      y = delta;
    for (; y < cy1 && y >= 0; order ? y-- : y++) {
      if (!_rect_advance(&state, &x0, &x1))
        break;
      x1 -= x0;
      if (x1 <= 0) {
        c.dst += dbpl;
        c.dsta += adbpl;
        c.src += sbpl;
        c.srca += asbpl;
        continue;
      }
      c.dst += x0 * DI.bytes_per_pixel;
      c.dsta += x0;
      c.src += x0 * DI.bytes_per_pixel;
      c.srca += x0;
      if (!clip_span) {
        blit_func(&c, x1);
        c.dst += dbpl - x0 * DI.bytes_per_pixel;
        c.dsta += adbpl - x0;
        c.src += sbpl - x0 * DI.bytes_per_pixel;
        c.srca += asbpl - x0;
      } else {
        unsigned int *span, *end;
        BOOL state = NO;

        span = &clip_span[clip_index[y + cy0 - clip_y0]];
        end = &clip_span[clip_index[y + cy0 - clip_y0 + 1]];

        x0 = x0 + cx0 - clip_x0;
        x1 += x0;
        while (span != end && *span < x0) {
          state = !state;
          span++;
          if (span == end)
            break;
        }
        if (span != end) {
          while (span != end && *span < x1) {
            if (state)
              blit_func(&c, *span - x0);
            c.dst += (*span - x0) * DI.bytes_per_pixel;
            c.dsta += (*span - x0);
            c.src += (*span - x0) * DI.bytes_per_pixel;
            c.srca += (*span - x0);
            x0 = *span;

            state = !state;
            span++;
            if (span == end)
              break;
          }
          if (state)
            blit_func(&c, x1 - x0);
        }
        x0 = x0 - cx0 + clip_x0;
        c.dst += dbpl - x0 * DI.bytes_per_pixel;
        c.dsta += adbpl - x0;
        c.src += sbpl - x0 * DI.bytes_per_pixel;
        c.srca += asbpl - x0;
      }
    }
  }
  UPDATE_UNBUFFERED
}

- (void)dissolveGState:(GSGState *)source
              fromRect:(NSRect)aRect
               toPoint:(NSPoint)aPoint
                 delta:(CGFloat)fraction
{
  /* much setup code shared with compositeGState:... */
  ARTGState *ags = (ARTGState *)source;
  unsigned char *dst, *dst_alpha, *src, *src_alpha;

  void (*blit_func)(composite_run_t * c, int num) = NULL;

  NSPoint sp, dp;

  int cx0, cy0, cx1, cy1;
  int sx0, sy0;

  int sbpl, dbpl;
  int asbpl, adbpl;

  rect_trace_t state;

  /* 0 = top->down, 1 = bottom->up */
  /*
    TODO: this does not handle the horizontal case
    either 0=top->down, left->right, 2=top->down, right->left
    or keep 0 and add 2=top->down, make temporary copy of source
    could allocate a temporary array on the stack large enough to hold
    one row and do the operations on it
  */
  /* currently 2=top->down, be careful with overlapping rows */
  /* order=1 is handled generically by flipping sbpl and dbpl and
     adjusting the pointers. order=2 is handled specially */
  int order;

  int delta;

  if (!wi || !wi->data || !ags->wi || !ags->wi->data)
    return;
  if (all_clipped)
    return;

  /* Set up all the pointers and clip things */

  dbpl = wi->bytes_per_line;
  sbpl = ags->wi->bytes_per_line;

  cx0 = clip_x0;
  cy0 = clip_y0;
  cx1 = clip_x1;
  cy1 = clip_y1;

  sp = [ags->ctm transformPoint:aRect.origin];
  sp.x = floor(sp.x - ags->offset.x);
  sp.y = floor(ags->offset.y - sp.y);
  dp = [ctm transformPoint:aPoint];
  dp.x = floor(dp.x - offset.x);
  dp.y = floor(offset.y - dp.y);

  if (dp.x - cx0 > sp.x)
    cx0 = dp.x - sp.x;
  if (dp.y - cy0 > sp.y)
    cy0 = dp.y - sp.y;

  if (cx1 - dp.x > ags->wi->sx - sp.x)
    cx1 = dp.x + ags->wi->sx - sp.x;
  if (cy1 - dp.y > ags->wi->sy - sp.y)
    cy1 = dp.y + ags->wi->sy - sp.y;

  sx0 = sp.x - dp.x + cx0;
  sy0 = sp.y - dp.y + cy0;

  dst = wi->data + cx0 * DI.bytes_per_pixel + cy0 * dbpl;
  src = ags->wi->data + sx0 * DI.bytes_per_pixel + sy0 * sbpl;

  if (ags->wi->has_alpha) {
    if (DI.inline_alpha)
      src_alpha = src;
    else
      src_alpha = ags->wi->alpha + sx0 + sy0 * ags->wi->sx;
    asbpl = ags->wi->sx;
  } else {
    src_alpha = NULL;
    asbpl = 0;
  }

  if (wi->has_alpha) {
    if (DI.inline_alpha)
      dst_alpha = dst;
    else
      dst_alpha = wi->alpha + cx0 + cy0 * wi->sx;
    adbpl = wi->sx;
  } else {
    dst_alpha = NULL;
    adbpl = 0;
  }

  cy1 -= cy0;
  cx1 -= cx0;

  if (cx0 < 0 || cy0 < 0 || cx0 + cx1 > wi->sx || cy0 + cy1 > wi->sy || sx0 < 0 || sy0 < 0 ||
      sx0 + cx1 > ags->wi->sx || sy0 + cy1 > ags->wi->sy) {
    NSLog(@"Warning: invalid coordinates in dissolve: (%g %g)+(%g %g) -> (%g %g) got (%i %i) (%i "
          @"%i) +(%i %i)",
          aRect.origin.x, aRect.origin.x, aRect.size.width, aRect.size.height, aPoint.x, aPoint.y,
          cx0, cy0, sx0, sy0, cx1, cy1);
    return;
  }

  if (cx1 <= 0 || cy1 <= 0)
    return;

  /* To handle overlapping areas properly, we sometimes need to do
     things bottom-up instead of top-down. If so, we flip the
     coordinates here. */
  order = 0;
  if (ags->wi == self->wi && sy0 <= cy0) {
    order = 1;
    dst += dbpl * (cy1 - 1);
    src += sbpl * (cy1 - 1);
    dst_alpha += adbpl * (cy1 - 1);
    src_alpha += asbpl * (cy1 - 1);
    dbpl = -dbpl;
    sbpl = -sbpl;
    adbpl = -adbpl;
    asbpl = -asbpl;
    if (sy0 == cy0) {
      if ((sx0 >= cx0 && sx0 <= cx0 + cx1) || (cx0 >= sx0 && cx0 <= sx0 + cx1)) {
        order = 2;
      }
    }
  }

  if (ags->wi->has_alpha && wi->has_alpha)
    blit_func = DI.dissolve_aa;
  else if (wi->has_alpha)
    blit_func = DI.dissolve_oa;
  else if (ags->wi->has_alpha)
    blit_func = DI.dissolve_ao;
  else
    blit_func = DI.dissolve_oo;

  if (!blit_func) {
    NSLog(
        @"unimplemented: dissolveGState: %p fromRect: (%g %g)+(%g %g) toPoint: (%g %g)  delta: %g",
        source, aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height, aPoint.x,
        aPoint.y, fraction);
    return;
  }

  {
    int ry;
    int x0, x1;
    _rect_setup(&state, aRect, sx0, sx0 + cx1, ags->ctm, order, &ry, ags->offset);
    if (order) {
      if (ry < sy0)
        return;
      delta = sy0 + cy1 - ry;
    } else {
      if (ry >= sy0 + cy1)
        return;
      delta = ry - sy0;
    }

    if (delta > 0) {
      src += sbpl * delta;
      src_alpha += asbpl * delta;
      dst += dbpl * delta;
      dst_alpha += adbpl * delta;
    } else if (delta < 0) {
      delta = -delta;
      while (delta) {
        if (!_rect_advance(&state, &x0, &x1)) {
          break;
        }
        delta--;
      }
      if (delta)
        return;
    }
  }

  /* this breaks the alpha pointer in some cases, but that's ok since in
     all those cases, the alpha pointer isn't used (inline alpha or
     no alpha) */
  if (order == 2) {
    unsigned char tmpbuf[cx1 * DI.bytes_per_pixel];
    unsigned char tmpbufa[cx1];
    int y;
    composite_run_t c;
    int x0, x1;

    c.dst = dst;
    c.dsta = dst_alpha;
    c.src = tmpbuf;
    c.srca = tmpbufa;
    c.fraction = fraction * 255;
    for (y = cy1 - delta - 1; y >= 0; y--) {
      if (!_rect_advance(&state, &x0, &x1))
        break;
      x1 -= x0;

      c.dst += x0 * DI.bytes_per_pixel;
      c.dsta += x0;

      if (x1) {
        memcpy(tmpbuf, src + x0 * DI.bytes_per_pixel, x1 * DI.bytes_per_pixel);
        if (ags->wi->has_alpha && !DI.inline_alpha)
          memcpy(tmpbufa, src_alpha + x0, x1);

        if (!clip_span) {
          blit_func(&c, x1);
          c.dst += dbpl - x0 * DI.bytes_per_pixel;
          c.dsta += adbpl - x0;
        } else {
          unsigned int *span, *end;
          BOOL state = NO;

          span = &clip_span[clip_index[y + cy0 - clip_y0]];
          end = &clip_span[clip_index[y + cy0 - clip_y0 + 1]];

          x0 = x0 + cx0 - clip_x0;
          x1 += x0;
          while (span != end && *span < x0) {
            state = !state;
            span++;
            if (span == end)
              break;
          }
          if (span != end) {
            while (span != end && *span < x1) {
              if (state)
                blit_func(&c, *span - x0);
              c.dst += (*span - x0) * DI.bytes_per_pixel;
              c.dsta += (*span - x0);
              c.src += (*span - x0) * DI.bytes_per_pixel;
              c.srca += (*span - x0);
              x0 = *span;

              state = !state;
              span++;
              if (span == end)
                break;
            }
            if (state)
              blit_func(&c, x1 - x0);
          }
          x0 = x0 - cx0 + clip_x0;
          c.dst += dbpl - x0 * DI.bytes_per_pixel;
          c.dsta += adbpl - x0;
          c.src = tmpbuf;
          c.srca = tmpbufa;
        }
      }

      src += sbpl;
      src_alpha += asbpl;
    }
  } else {
    int y;
    composite_run_t c;
    int x0, x1;

    c.dst = dst;
    c.dsta = dst_alpha;
    c.src = src;
    c.srca = src_alpha;
    c.fraction = fraction * 255;
    if (order)
      y = cy1 - delta - 1;
    else
      y = delta;
    for (; y < cy1 && y >= 0; order ? y-- : y++) {
      if (!_rect_advance(&state, &x0, &x1))
        break;
      x1 -= x0;
      if (x1 <= 0) {
        c.dst += dbpl;
        c.dsta += adbpl;
        c.src += sbpl;
        c.srca += asbpl;
        continue;
      }
      c.dst += x0 * DI.bytes_per_pixel;
      c.dsta += x0;
      c.src += x0 * DI.bytes_per_pixel;
      c.srca += x0;
      if (!clip_span) {
        blit_func(&c, x1);
        c.dst += dbpl - x0 * DI.bytes_per_pixel;
        c.dsta += adbpl - x0;
        c.src += sbpl - x0 * DI.bytes_per_pixel;
        c.srca += asbpl - x0;
      } else {
        unsigned int *span, *end;
        BOOL state = NO;

        span = &clip_span[clip_index[y + cy0 - clip_y0]];
        end = &clip_span[clip_index[y + cy0 - clip_y0 + 1]];

        x0 = x0 + cx0 - clip_x0;
        x1 += x0;
        while (span != end && *span < x0) {
          state = !state;
          span++;
          if (span == end)
            break;
        }
        if (span != end) {
          while (span != end && *span < x1) {
            if (state)
              blit_func(&c, *span - x0);
            c.dst += (*span - x0) * DI.bytes_per_pixel;
            c.dsta += (*span - x0);
            c.src += (*span - x0) * DI.bytes_per_pixel;
            c.srca += (*span - x0);
            x0 = *span;

            state = !state;
            span++;
            if (span == end)
              break;
          }
          if (state)
            blit_func(&c, x1 - x0);
        }
        x0 = x0 - cx0 + clip_x0;
        c.dst += dbpl - x0 * DI.bytes_per_pixel;
        c.dsta += adbpl - x0;
        c.src += sbpl - x0 * DI.bytes_per_pixel;
        c.srca += asbpl - x0;
      }
    }
  }
  UPDATE_UNBUFFERED
}

- (void)compositeGState:(GSGState *)source
               fromRect:(NSRect)aRect
                toPoint:(NSPoint)aPoint
                     op:(NSCompositingOperation)op
               fraction:(CGFloat)delta
{
  if (op == NSCompositeSourceOver) {
    [self dissolveGState:source fromRect:aRect toPoint:aPoint delta:delta];
  } else {
    [self compositeGState:source fromRect:aRect toPoint:aPoint op:op];
  }
}


- (unsigned char *)artScale
{
  // art_u8 *dest_buffer = art_new(art_u8, dest_buffer_width * dest_buffer_height *
  // sizeof(ags->wi->data)); double affine[6] = {0, 0, 0, 0, 0, 0}; affine[0] = source_ts.m11;
  // affine[1] = source_ts.m12;
  // affine[2] = source_ts.m21;
  // affine[3] = source_ts.m22;
  // affine[4] = source_ts.tX;
  // affine[5] = source_ts.tY;
  // art_rgb_rgba_affine(dest_buffer, 0, 0, dest_buffer_width, dest_buffer_height,
  //                     dest_buffer_width * ags->wi->bytes_per_pixel, ags->wi->data, ags->wi->sx,
  //                     ags->wi->sy, ags->wi->bytes_per_line, affine, ART_FILTER_NEAREST, NULL);
  // art_rgb_bitmap_affine(dest_buffer, 0, 0, dest_buffer_width, dest_buffer_height,
  //                       dest_buffer_width * 4, ags->wi->data, ags->wi->sx, ags->wi->sy,
  //                       ags->wi->bytes_per_line, 0x00000001, affine, ART_FILTER_NEAREST, NULL);
  // art_rgb_rgba_affine(dest_buffer, 0, 0, dest_buffer_width, dest_buffer_height,
  //                     ags->wi->bytes_per_line, ags->wi->data,
  //                     aRect.size.width, aRect.size.height,
  //                     ags->wi->bytes_per_line, affine, ART_FILTER_NEAREST,
  //                     NULL);
  return NULL;
}

unsigned char *_scaleImage(unsigned char *data, unsigned new_width, unsigned new_height,
                           unsigned old_width, unsigned old_height)
{
  int ox;
  int px, py;
  register int x, y, t;
  int dx, dy;
  unsigned char *src;
  unsigned char *dest;

  if (data == NULL)
    return NULL;

  NSLog(@"_scaleImage from: %ix%i to: %ix%i", old_width, old_height, new_width, new_height);

  unsigned char *new_data = malloc(sizeof(unsigned char) * new_height * new_width * 4);
  memset(new_data, 0, sizeof(unsigned char) * new_height * new_width * 4);
  // RImage *img = RCreateImage(new_width, new_height, False);
  // d = img->data;
  dest = new_data;

  /* fixed point math idea taken from Imlib by
   * Carsten Haitzler (Rasterman) */
  dx = (old_width << 16) / new_width;
  dy = (old_height << 16) / new_height;
  NSLog(@"dx: %i, dy: %i", dx, dy);

  py = 0;

  // if (img->format == RRGBAFormat) {
    for (y = 0; y < new_height; y++) {
      t = old_width * (py >> 16);
      NSLog(@"py: %i, py >> 16: %i, t: %i", py, py >> 16, t);

      src = data + (t << 2); /* data+t*4 */

      ox = 0;
      px = 0;
      for (x = 0; x < new_width; x++) {
        px += dx;

        *(dest++) = *(src);
        *(dest++) = *(src + 1);
        *(dest++) = *(src + 2);
        *(dest++) = *(src + 3);

        t = (px - ox) >> 16;
        ox += t << 16;

        src += t << 2; /* t*4 */
      }
      py += dy;
    }
  // } else {
  //   for (y = 0; y < new_height; y++) {
  //     t = old_width * (py >> 16);

  //     s = data + (t << 1) + t; /* image->data+t*3 */

  //     ox = 0;
  //     px = 0;
  //     for (x = 0; x < new_width; x++) {
  //       px += dx;

  //       *(d++) = *(s);
  //       *(d++) = *(s + 1);
  //       *(d++) = *(s + 2);

  //       t = (px - ox) >> 16;
  //       ox += t << 16;

  //       s += (t << 1) + t; /* t*3 */
  //     }
  //     py += dy;
  //   }
  // }

    // return img->data;
    return new_data;
}

// Convert RGBA unpacked to ARGB packed.
// Packed ARGB values are layed out as ARGB on big endian systems
// and as BGRA on little endian systems
static void _swapColors(unsigned char *image_data, NSBitmapImageRep *rep) {
  unsigned char *target = image_data;
  unsigned char *source = [rep bitmapData];
  NSInteger width = [rep pixelsWide];
  NSInteger height = [rep pixelsHigh];
  NSInteger samples_per_pixel = [rep samplesPerPixel];
  NSInteger bytes_per_row = [rep bytesPerRow];
  unsigned char *r, *g, *b, *a;
  NSInteger x, y;

#if GS_WORDS_BIGENDIAN
  // RGBA -> ARGB
  r = target + 1;
  g = target + 2;
  b = target + 3;
  a = target;
#else
  // RGBA -> BGRA
  r = target + 2;
  g = target + 1;
  b = target;
  a = target + 3;
#endif

  if (samples_per_pixel == 4) {
    for (y = 0; y < height; y++) {
      unsigned char *d = source;
      for (x = 0; x < width; x++) {
        *r = d[0];
        *g = d[1];
        *b = d[2];
        *a = d[3];
        r += 4;
        g += 4;
        b += 4;
        a += 4;
        d += samples_per_pixel;
      }
      source += bytes_per_row;
    }
  } else if (samples_per_pixel == 3) {
    for (y = 0; y < height; y++) {
      unsigned char *d = source;
      for (x = 0; x < width; x++) {
        *r = d[0];
        *g = d[1];
        *b = d[2];
        *a = 255;
        r += 4;
        g += 4;
        b += 4;
        a += 4;
        d += samples_per_pixel;
      }
      source += bytes_per_row;
    }
  }
}

- (void)drawGState:(GSGState *)source
          fromRect:(NSRect)aRect
           toPoint:(NSPoint)aPoint
                op:(NSCompositingOperation)op
          fraction:(CGFloat)delta
{
  ARTGState *ags = (ARTGState *)source;

  aRect.origin.x = round(aRect.origin.x);
  aRect.origin.y = round(aRect.origin.y);
  aRect.size.width = round(aRect.size.width);
  aRect.size.height = round(aRect.size.height);

  NSAffineTransformStruct local_ts = [ctm transformStruct];
  NSAffineTransformStruct source_ts = [source->ctm transformStruct];
  // NSAffineTransform *backup_ctm = [[NSAffineTransform alloc] initWithTransform:source->ctm];

  // NSLog(@"drawGState: rect %@ point: %@", NSStringFromRect(aRect), NSStringFromPoint(aPoint));
  // NSLog(@"drawGState: source CTM: %@", source->ctm);
  // NSLog(@"drawGState:        CTM: %@", ctm);
  // NSLog(@"drawGState: NEW    CTM: %@", source->ctm);
  if ((1 - local_ts.m11) > 0.01 /*&& source_ts.m11 != local_ts.m11*/) {
    // source_ts.m11 = local_ts.m11;
    // source_ts.m12 = local_ts.m12;
    // source_ts.m21 = local_ts.m21;
    // source_ts.m22 = local_ts.m22;
    // [source->ctm setTransformStruct:source_ts];
    [source DPSscale:local_ts.m11:local_ts.m22];

    // int dest_buffer_width = aRect.size.width;
    // int dest_buffer_height = aRect.size.height;
    // int dest_buffer_width = ceil(aRect.size.width * local_ts.m11);
    // int dest_buffer_height = ceil(aRect.size.height * local_ts.m22);
    // wi - window buffer
    // ags->wi - image buffer
    // NSLog(@"drawGState:AGS->WI: width: %i, height: %i -- WI: width: %i, height: %i", ags->wi->sx,
    //       ags->wi->sy, wi->sx, wi->sy);

    NSLog(@"Buffer size: %lu, bytes: _per_pixel: %i, _per_line: %i, unsigned char size: %lu",
          sizeof(ags->wi->data), ags->wi->bytes_per_pixel, ags->wi->bytes_per_line,
          sizeof(unsigned char));

    NSBitmapImageRep *imageRep =
        [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                pixelsWide:ags->wi->sx
                                                pixelsHigh:ags->wi->sy
                                             bitsPerSample:8
                                           samplesPerPixel:4
                                                  hasAlpha:ags->wi->has_alpha ? YES : NO
                                                  isPlanar:NO
                                            colorSpaceName:NSDeviceRGBColorSpace
                                               bytesPerRow:ags->wi->bytes_per_line
                                              bitsPerPixel:ags->wi->bits_per_pixel];
    int buffer_size = ags->wi->sy * ags->wi->bytes_per_line;
    // unsigned char *dest_buffer = malloc(buffer_size);
    memcpy([imageRep bitmapData], ags->wi->data, buffer_size);
    // _swapColors(dest_buffer, imageRep);
    // memcpy([imageRep bitmapData], dest_buffer, buffer_size);
    // free(dest_buffer);
    [drawcontext GSDrawImage:aRect:imageRep];

    // unsigned char *dest_buffer =
    //     _scaleImage(ags->wi->data, dest_buffer_width, dest_buffer_height,
    //                 (unsigned)aRect.size.width, (unsigned)aRect.size.height);
    // unsigned char *dest_buffer =
    //     _scaleImage(ags->wi->data, dest_buffer_width, dest_buffer_height, ags->wi->sx,
    //     ags->wi->sy);
    // free(ags->wi->data);
    // ags->wi->data = dest_buffer;
    // ags->wi->sx = dest_buffer_width;
    // ags->wi->sy = dest_buffer_height;
    // ags->wi->bytes_per_line = (unsigned)aRect.size.width * ags->wi->bytes_per_pixel;

    // unsigned char *dest_buffer =
    //     malloc(sizeof(unsigned char) * dest_buffer_height * dest_buffer_width * 4);
    // memset(
    //     dest_buffer, 0,
    //     sizeof(unsigned char) * dest_buffer_width * dest_buffer_height * ags->wi->bytes_per_pixel);
    // // int y;
    // for (y = 0; y < dest_buffer_height; y += ags->wi->bytes_per_line) {

    // }
    // memcpy(dest_buffer, ags->wi->data,
    //        sizeof(unsigned char) * dest_buffer_height * dest_buffer_width * 4);

    // free(ags->wi->data);
    // ags->wi->data = dest_buffer;
    // ags->wi->sx = dest_buffer_width;
    // ags->wi->sy = dest_buffer_height;
    // ags->wi->bytes_per_line = dest_buffer_width * ags->wi->bytes_per_pixel;
  } else {
    // NSDictionary *rr = [self GSReadRect:aRect];
    // NSLog(@"ReadRect Size: %@", [rr objectForKey:@"Size"]);
    // NSLog(@"ReadRect Matrix: %@", [rr objectForKey:@"Matrix"]);

    [self compositeGState:source fromRect:aRect toPoint:aPoint op:op fraction:delta];
  }

  // [source->ctm initWithTransform:backup_ctm];
  // [backup_ctm release];
}

- (void)compositerect:(NSRect)aRect op:(NSCompositingOperation)op
{
  /* much setup code shared with compositeGState:... */
  unsigned char *dst, *dst_alpha;
  int dbpl, adbpl;

  int cx0, cy0, cx1, cy1;

  void (*blit_func)(composite_run_t * c, int num);

  rect_trace_t state;

  int delta;

  if (!wi || !wi->data)
    return;
  if (all_clipped)
    return;

  {
    BOOL dest_needs_alpha;

    /* TODO: which color? using fill_color for now */
    op = [self _composite_func:fill_color[3] ==
                           255:fill_color[3] == 0:!wi->has_alpha:&dest_needs_alpha:op:&blit_func];

    if (op == -1)
      return;

    if (dest_needs_alpha || op == NSCompositeClear) {
      [wi needsAlpha];
      if (!wi->has_alpha)
        return;
    }
  }

  dbpl = wi->bytes_per_line;
  adbpl = wi->sx;

  cx0 = clip_x0;
  cy0 = clip_y0;
  cx1 = clip_x1;
  cy1 = clip_y1;

  dst = wi->data + cx0 * DI.bytes_per_pixel + cy0 * dbpl;
  dst_alpha = wi->alpha + cx0 + cy0 * wi->sx;

  cx1 -= cx0;
  cy1 -= cy0;

  {
    int ry;
    int x0, x1;
    _rect_setup(&state, aRect, cx0, cx0 + cx1, ctm, 0, &ry, offset);
    if (ry >= cy0 + cy1)
      return;
    delta = ry - cy0;

    if (delta > 0) {
      dst += dbpl * delta;
      dst_alpha += adbpl * delta;
    } else if (delta < 0) {
      delta = -delta;
      while (delta) {
        if (!_rect_advance(&state, &x0, &x1))
          break;
        delta--;
      }
      if (delta)
        return;
    }
  }

#define DO_STUFF(HANDLE_SPAN)                                \
  {                                                          \
    int y;                                                   \
    int x0, x1;                                              \
    int n;                                                   \
                                                             \
    if (clip_span) {                                         \
      for (y = delta; y < cy1; y++) {                        \
        unsigned int *span, *end;                            \
        BOOL clip_state = NO;                                \
                                                             \
        if (!_rect_advance(&state, &x0, &x1))                \
          break;                                             \
                                                             \
        x1 -= x0;                                            \
        if (!x1) {                                           \
          dst += dbpl;                                       \
          dst_alpha += adbpl;                                \
          continue;                                          \
        }                                                    \
                                                             \
        dst += x0 * DI.bytes_per_pixel;                      \
        dst_alpha += x0;                                     \
                                                             \
        span = &clip_span[clip_index[y + cy0 - clip_y0]];    \
        end = &clip_span[clip_index[y + cy0 - clip_y0 + 1]]; \
                                                             \
        x0 = x0 + cx0 - clip_x0;                             \
        x1 += x0;                                            \
        while (span != end && *span < x0) {                  \
          clip_state = !clip_state;                          \
          span++;                                            \
          if (span == end)                                   \
            break;                                           \
        }                                                    \
        if (span != end) {                                   \
          while (span != end && *span < x1) {                \
            if (clip_state) {                                \
              n = (*span - x0);                              \
              HANDLE_SPAN                                    \
            }                                                \
            dst += (*span - x0) * DI.bytes_per_pixel;        \
            dst_alpha += (*span - x0);                       \
            x0 = *span;                                      \
                                                             \
            clip_state = !clip_state;                        \
            span++;                                          \
            if (span == end)                                 \
              break;                                         \
          }                                                  \
          if (clip_state) {                                  \
            n = x1 - x0;                                     \
            HANDLE_SPAN                                      \
          }                                                  \
        }                                                    \
        x0 = x0 - cx0 + clip_x0;                             \
                                                             \
        dst += dbpl - x0 * DI.bytes_per_pixel;               \
        dst_alpha += adbpl - x0;                             \
      }                                                      \
    } else {                                                 \
      for (y = delta; y < cy1; y++) {                        \
        if (!_rect_advance(&state, &x0, &x1))                \
          break;                                             \
                                                             \
        x1 -= x0;                                            \
        if (!x1) {                                           \
          dst += dbpl;                                       \
          dst_alpha += adbpl;                                \
          continue;                                          \
        }                                                    \
                                                             \
        dst += x0 * DI.bytes_per_pixel;                      \
        dst_alpha += x0;                                     \
                                                             \
        n = x1;                                              \
        HANDLE_SPAN                                          \
                                                             \
        dst += dbpl - x0 * DI.bytes_per_pixel;               \
        dst_alpha += adbpl - x0;                             \
      }                                                      \
    }                                                        \
  }

  if (op == NSCompositeClear) {
    DO_STUFF(memset(dst, 0, n * DI.bytes_per_pixel); if (!DI.inline_alpha) memset(dst_alpha, 0, n);)
  } else if (op == GSCompositeHighlight) {
    DO_STUFF({
      unsigned char *d = dst;
      n *= DI.bytes_per_pixel;
      for (; n; n--, d++)
        (*d) ^= 0xff;
    })
  } else if (op == NSCompositeCopy) {
    render_run_t ri;
    ri.dst = dst;
    /* We don't want to blend, so we premultiply and fill the
       alpha channel manually. */
    ri.a = fill_color[3];
    ri.r = (fill_color[0] * ri.a + 0xff) >> 8;
    ri.g = (fill_color[1] * ri.a + 0xff) >> 8;
    ri.b = (fill_color[2] * ri.a + 0xff) >> 8;
    if (ri.a != 255 && !wi->has_alpha)
      return;

    DO_STUFF(ri.dst = dst; DI.render_run_opaque(&ri, n); if (ri.a != 255) {
      if (DI.inline_alpha) {
        /* TODO: needs to change to support inline
           alpha for non-32-bit modes */
        unsigned char *p;
        for (p = dst; n; n--, p += 4)
          p[DI.inline_alpha_ofs] = ri.a;
      } else {
        memset(dst_alpha, ri.a, n);
      }
    })
  } else if (blit_func) {
    /* this is slightly ugly, but efficient */
    unsigned char buf[DI.bytes_per_pixel * cx1];
    unsigned char abuf[fill_color[3] == 255 ? 1 : cx1];
    composite_run_t c;

    c.src = buf;
    if (fill_color[3] != 255)
      c.srca = abuf;
    else
      c.srca = NULL;

    {
      render_run_t ri;
      ri.dst = buf;
      ri.dsta = NULL;
      /* Note that we premultiply _here_ and set the alpha
         channel manually (for speed; no reason to do slow
         blending when we just want a straight blit of all
         channels). */
      ri.a = fill_color[3];
      ri.r = (fill_color[0] * ri.a + 0xff) >> 8;
      ri.g = (fill_color[1] * ri.a + 0xff) >> 8;
      ri.b = (fill_color[2] * ri.a + 0xff) >> 8;
      DI.render_run_opaque(&ri, cx1);
      if (fill_color[3] != 255) {
        if (DI.inline_alpha) {
          int i;
          unsigned char *s;
          /* TODO: needs to change to support inline
             alpha for non-32-bit modes */
          for (i = 0, s = buf + DI.inline_alpha_ofs; i < cx1; i++, s += 4)
            *s = ri.a;
        } else
          memset(abuf, ri.a, cx1);
      }
    }

    DO_STUFF(c.dst = dst; c.dsta = dst_alpha; blit_func(&c, n);)
  } else {
    NSLog(@"unimplemented compositerect: (%g %g)+(%g %g)  op: %lu", aRect.origin.x, aRect.origin.y,
          aRect.size.width, aRect.size.height, op);
  }
  UPDATE_UNBUFFERED
}

@end
