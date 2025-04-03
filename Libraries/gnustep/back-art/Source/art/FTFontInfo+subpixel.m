#import "FTFontInfo+subpixel.h"

/* TODO: this whole thing needs cleaning up */
@implementation FTFontInfo_subpixel

#if 0
- (void) drawGlyphs: (const NSGlyph *)glyphs : (int)length
        at: (int)x : (int)y
        to: (int)x0 : (int)y0 : (int)x1 : (int)y1
        : (unsigned char *)buf : (int)bpl
        color: (unsigned char)r : (unsigned char)g : (unsigned char)b
        : (unsigned char)alpha
        transform: (NSAffineTransform *)transform
        drawinfo: (struct draw_info_s *)di
{
  FTC_CMapDescRec cmap;
  unsigned int glyph;

  int use_sbit;

  FTC_SBit sbit;
  FTC_ImageTypeRec cur;

  FT_Matrix ftmatrix;
  FT_Vector ftdelta;
  NSAffineTransformStruct ts;

  BOOL subpixel = NO;

  if (!alpha)
    return;

  /* TODO: if we had guaranteed upper bounds on glyph image size we
     could do some basic clipping here */

  x1 -= x0;
  y1 -= y0;
  x -= x0;
  y -= y0;

  ts = [transform transformStruct];

/*        NSLog(@"[%@ draw using matrix: (%g %g %g %g %g %g)]",
                self,
                matrix[0], matrix[1], matrix[2],
                matrix[3], matrix[4], matrix[5]
                );*/

  cur = imgd;
  {
    float xx, xy, yx, yy;

    xx = matrix[0] * ts.m11 + matrix[1] * ts.m21;
    yx = matrix[0] * ts.m12 + matrix[1] * ts.m22;
    xy = matrix[2] * ts.m11 + matrix[3] * ts.m21;
    yy = matrix[2] * ts.m12 + matrix[3] * ts.m22;

    /* if we're drawing 'normal' text (unscaled, unrotated, reasonable
       size), we can and should use the sbit cache */
    if (fabs(xx - ((int)xx)) < 0.01 && fabs(yy - ((int)yy)) < 0.01
      && fabs(xy) < 0.01 && fabs(yx) < 0.01
      && xx < 72 && yy < 72 && xx > 0.5 && yy > 0.5)
      {
        use_sbit = 1;
        cur.font.pix_width = xx;
        cur.font.pix_height = yy;

/*        if (cur.font.pix_width < 16 && cur.font.pix_height < 16 &&
            cur.font.pix_width > 6 && cur.font.pix_height > 6)
          cur.type = ftc_image_mono;
        else*/
          cur.flags = FT_LOAD_TARGET_LCD, subpixel = YES;
//                        imgd.type|=|ftc_image_flag_unhinted; /* TODO? when? */
      }
    else
      {
        float f;
        use_sbit = 0;

        f = fabs(xx * yy - xy * yx);
        if (f > 1)
          f = sqrt(f);
        else
          f = 1.0;

        f = (int)f;

        cur.font.pix_width = cur.font.pix_height = f;
        ftmatrix.xx = xx / f * 65536.0;
        ftmatrix.xy = xy / f * 65536.0;
        ftmatrix.yx = yx / f * 65536.0;
        ftmatrix.yy = yy / f * 65536.0;
        ftdelta.x = ftdelta.y = 0;
      }
  }


/*        NSLog(@"drawString: '%s' at: %i:%i  to: %i:%i:%i:%i:%p",
                s, x, y, x0, y0, x1, y1, buf);*/

  cmap.face_id = imgd.font.face_id;
  cmap.u.encoding = ft_encoding_unicode;
  cmap.type = FTC_CMAP_BY_ENCODING;

  for (; length; length--, glyphs++)
    {
      glyph = *glyphs - 1;

      if (use_sbit)
        {
          if (FTC_SBitCache_Lookup(ftc_sbitcache, &cur, glyph, &sbit, NULL))
            continue;

          if (!sbit->buffer)
            {
              x += sbit->xadvance;
              continue;
            }

          if (sbit->format == FT_PIXEL_MODE_LCD)
            {
              int gx = 3 * x + sbit->left, gy = y - sbit->top;
              int px0 = (gx - 2 < 0? gx - 4 : gx - 2) / 3;
              int px1 = (gx + sbit->width + 2 < 0? gx + sbit->width + 2: gx + sbit->width + 4) / 3;
              int llip = gx - px0 * 3;
              int sbpl = sbit->pitch;
              int sx = sbit->width, sy = sbit->height;
              int psx = px1 - px0;
              const unsigned char *src = sbit->buffer;
              unsigned char *dst = buf;
              unsigned char scratch[psx * 3];
              int mode = subpixel_text == 2? 2 : 0;

              if (gy < 0)
                {
                  sy += gy;
                  src -= sbpl * gy;
                  gy = 0;
                }
              else if (gy > 0)
                {
                  dst += bpl * gy;
                }

              sy += gy;
              if (sy > y1)
                sy = y1;

              if (px1 > x1)
                px1 = x1;
              if (px0 < 0)
                {
                  px0 = -px0;
                }
              else
                {
                  px1 -= px0;
                  dst += px0 * DI.bytes_per_pixel;
                  px0 = 0;
                }

              if (px1 <= 0)
                {
                  x += sbit->xadvance;
                  continue;
                }

              for (; gy < sy; gy++, src += sbpl, dst += bpl)
                {
                  int i, j;
                  int v0, v1, v2;
                  for (i = 0, j = -llip; i < psx * 3; i+=3)
                    {
                      v0 = (0 +
                       + (j >  2 && j<sx + 3? src[j - 3] * filters[0][0] : 0)
                       + (j >  1 && j<sx + 2? src[j - 2] * filters[0][1] : 0)
                       + (j >  0 && j<sx + 1? src[j - 1] * filters[0][2] : 0)
                       + (j > -1 && j<sx    ? src[j    ] * filters[0][3] : 0)
                       + (j > -2 && j<sx - 1? src[j + 1] * filters[0][4] : 0)
                       + (j > -3 && j<sx - 2? src[j + 2] * filters[0][5] : 0)
                       + (j > -4 && j<sx - 3? src[j + 3] * filters[0][6] : 0)
                ) / 65536;
                      j++;
                      v1 = (0 +
                       + (j >  2 && j<sx + 3? src[j - 3] * filters[1][0] : 0)
                       + (j >  1 && j<sx + 2? src[j - 2] * filters[1][1] : 0)
                       + (j >  0 && j<sx + 1? src[j - 1] * filters[1][2] : 0)
                       + (j > -1 && j<sx    ? src[j    ] * filters[1][3] : 0)
                       + (j > -2 && j<sx - 1? src[j + 1] * filters[1][4] : 0)
                       + (j > -3 && j<sx - 2? src[j + 2] * filters[1][5] : 0)
                       + (j > -4 && j<sx - 3? src[j + 3] * filters[1][6] : 0)
                ) / 65536;
                      j++;
                      v2 = (0 +
                       + (j >  2 && j<sx + 3? src[j - 3] * filters[2][0] : 0)
                       + (j >  1 && j<sx + 2? src[j - 2] * filters[2][1] : 0)
                       + (j >  0 && j<sx + 1? src[j - 1] * filters[2][2] : 0)
                       + (j > -1 && j<sx    ? src[j    ] * filters[2][3] : 0)
                       + (j > -2 && j<sx - 1? src[j + 1] * filters[2][4] : 0)
                       + (j > -3 && j<sx - 2? src[j + 2] * filters[2][5] : 0)
                       + (j > -4 && j<sx - 3? src[j + 3] * filters[2][6] : 0)
                ) / 65536;
                      j++;

                      scratch[i + mode] = v0>0?v0:0;
                      scratch[i + 1] = v1>0?v1:0;
                      scratch[i + (mode ^ 2)] = v2>0?v2:0;
                    }
                  DI.render_blit_subpixel(dst,
                                          scratch + px0 * 3, r, g, b, alpha,
                                          px1);
                }
            }
          else if (sbit->format == ft_pixel_mode_mono)
            {
              int gx = x + sbit->left, gy = y - sbit->top;
              int sbpl = sbit->pitch;
              int sx = sbit->width, sy = sbit->height;
              const unsigned char *src = sbit->buffer;
              unsigned char *dst = buf;
              int src_ofs = 0;

              if (gy < 0)
                {
                  sy += gy;
                  src -= sbpl * gy;
                  gy = 0;
                }
              else if (gy > 0)
                {
                  dst += bpl * gy;
                }

              sy += gy;
              if (sy > y1)
                sy = y1;

              if (gx < 0)
                {
                  sx += gx;
                  src -= gx / 8;
                  src_ofs = (-gx) & 7;
                  gx = 0;
                }
              else if (gx > 0)
                {
                  dst += DI.bytes_per_pixel * gx;
                }

              sx += gx;
              if (sx > x1)
                sx = x1;
              sx -= gx;

              if (sx > 0)
                {
                  if (alpha >= 255)
                    for (; gy < sy; gy++, src += sbpl, dst += bpl)
                      RENDER_BLIT_MONO_OPAQUE(dst, src, src_ofs, r, g, b, sx);
                  else
                    for (; gy < sy; gy++, src += sbpl, dst += bpl)
                      RENDER_BLIT_MONO(dst, src, src_ofs, r, g, b, alpha, sx);
                }
            }
          else
            {
              NSLog(@"unhandled font bitmap format %i", sbit->format);
            }

          x += sbit->xadvance;
        }
      else
        {
          FT_Face face;
          FT_Glyph gl;
          FT_BitmapGlyph gb;

          if (FTC_Manager_Lookup_Size(ftc_manager, &cur.font, &face, 0))
            continue;

          /* TODO: for rotations of 90, 180, 270, and integer
             scales hinting might still be a good idea. */
          if (FT_Load_Glyph(face, glyph, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP))
            continue;

          if (FT_Get_Glyph(face->glyph, &gl))
            continue;

          if (FT_Glyph_Transform(gl, &ftmatrix, &ftdelta))
            {
              NSLog(@"glyph transformation failed!");
              continue;
            }
          if (FT_Glyph_To_Bitmap(&gl, ft_render_mode_normal, 0, 1))
            {
              FT_Done_Glyph(gl);
              continue;
            }
          gb = (FT_BitmapGlyph)gl;


          if (gb->bitmap.pixel_mode == ft_pixel_mode_grays)
            {
              int gx = x + gb->left, gy = y - gb->top;
              int sbpl = gb->bitmap.pitch;
              int sx = gb->bitmap.width, sy = gb->bitmap.rows;
              const unsigned char *src = gb->bitmap.buffer;
              unsigned char *dst = buf;

              if (gy < 0)
                {
                  sy += gy;
                  src -= sbpl * gy;
                  gy = 0;
                }
              else if (gy > 0)
                {
                  dst += bpl * gy;
                }

              sy += gy;
              if (sy > y1)
                sy = y1;

              if (gx < 0)
                {
                  sx += gx;
                  src -= gx;
                  gx = 0;
                }
              else if (gx > 0)
                {
                  dst += DI.bytes_per_pixel * gx;
                }

              sx += gx;
              if (sx > x1)
                sx = x1;
              sx -= gx;

              if (sx > 0)
                {
                  if (alpha >= 255)
                    for (; gy < sy; gy++, src += sbpl, dst += bpl)
                      RENDER_BLIT_ALPHA_OPAQUE(dst, src, r, g, b, sx);
                  else
                    for (; gy < sy; gy++, src += sbpl, dst += bpl)
                      RENDER_BLIT_ALPHA(dst, src, r, g, b, alpha, sx);
                }
            }
/* TODO: will this case ever appear? */
/*                        else if (gb->bitmap.pixel_mode==ft_pixel_mode_mono)*/
          else
            {
              NSLog(@"unhandled font bitmap format %i", gb->bitmap.pixel_mode);
            }

          ftdelta.x += gl->advance.x >> 10;
          ftdelta.y += gl->advance.y >> 10;

          FT_Done_Glyph(gl);
        }
    }
}
#endif

@end
