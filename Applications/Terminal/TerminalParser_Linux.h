/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

/* parses escape sequences for 'TERM=linux' */

#ifndef LinuxParser_h
#define LinuxParser_h

#include <iconv.h>

#include "Terminal.h"

@interface TerminalParser_Linux : NSObject <TerminalParser>
{
  id<TerminalScreen> ts;
  int width, height;

  unsigned int tab_stop[8];

  int x, y;

  int top, bottom;

  unsigned int unich;
  int utf_count;

  unsigned char input_buf[16];
  int input_buf_len;

#define TITLE_BUF_SIZE 255
  char title_buf[TITLE_BUF_SIZE + 1];
  unsigned int title_len, title_type;

  enum {
    ESnormal,
    ESesc,
    ESsquare,
    ESgetpars,
    ESgotpars,
    ESfunckey,
    EShash,
    ESsetG0,
    ESsetG1,
    ESpercent,
    ESignore,
    ESnonstd,
    ESpalette,
    EStitle_semi,
    EStitle_buf
  } ESstate;
  int vc_state;

  unsigned char decscnm, decom, decawm, deccm, decim;
  unsigned char ques;
  unsigned char charset, utf, disp_ctrl, toggle_meta;
  int G0_charset, G1_charset;

  const unichar *translate;

  unsigned int intensity, underline, reverse, blink;
  unsigned int color, def_color;
#define foreground (color & 0x0f)
#define background (color & 0xf0)

  screen_char_t video_erase_char;

#define NPAR 16
  int npar;
  int par[NPAR];

  int saved_x, saved_y;
  unsigned int s_intensity, s_underline, s_blink, s_reverse, s_charset, s_color;
  int saved_G0, saved_G1;

  iconv_t iconv_state;
  iconv_t iconv_input_state;

  BOOL alternateAsMeta;
  BOOL sendDoubleEscape;
}
@end

#endif
