/* menuparser.h
 *
 *  Copyright (c) 2012 Christophe Curis
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef _MENUPARSER_H_INCLUDED
#define _MENUPARSER_H_INCLUDED

/*
 * This file is not part of WINGs public API
 *
 * It defines internal things for the Menu Parser, the public API is
 * located in WINGs/WUtil.h as usual
 */

#define MAXLINE              1024
#define MAX_NESTED_INCLUDES  16  // To avoid infinite includes case
#define MAX_NESTED_MACROS    24  // To avoid infinite loop inside macro expansions
#define MAX_MACRO_ARG_COUNT  32  // Limited by design

typedef struct w_parser_macro WParserMacro;

typedef void WParserMacroFunction(WParserMacro *this, WMenuParser parser);

struct w_menu_parser {
	WMenuParser include_file;
	WMenuParser parent_file;
	const char *include_default_paths;
	const char *file_name;
	FILE *file_handle;
	int line_number;
	WParserMacro *macros;
	struct {
		/* Conditional text parsing is implemented using a stack of the
			skip states for each nested #if */
		int depth;
		struct {
			Bool skip;
			char name[8];
			int line;
		} stack[32];
	} cond;
	char *rd;
	char line_buffer[MAXLINE];
};

struct w_parser_macro {
	WParserMacro *next;
	char name[64];
	WParserMacroFunction *function;
	int arg_count;
#ifdef DEBUG
	int usage_count;
#endif
	unsigned char value[MAXLINE * 4];
};

Bool menu_parser_skip_spaces_and_comments(WMenuParser parser);

void menu_parser_register_preset_macros(WMenuParser parser);

void menu_parser_define_macro(WMenuParser parser);

void menu_parser_free_macros(WMenuParser parser);

WParserMacro *menu_parser_find_macro(WMenuParser parser, const char *name);

void menu_parser_expand_macro(WMenuParser parser, WParserMacro *macro);

int isnamechr(char ch); // Check if char is valid character for a macro name

#endif /* _MENUPARSER_H_INCLUDED */
