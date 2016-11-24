/*
 *  Window Maker window manager
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
#include "wconfig.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <pwd.h>

#include <WINGs/WUtil.h>

#include "menuparser.h"

/*
 This file contains the functions related to macros:
  - parse a macro being defined
  - handle single macro expansion
  - pre-defined parser's macros

 Some design notes for macro internal storage:

 arg_count is -1 when the macro does not take arguments
   but 0 when no args but still using parenthesis. The
   difference is explained in GNU cpp's documentation:
 http://gcc.gnu.org/onlinedocs/cpp/Function_002dlike-Macros.html

 the value is stored for fast expansion; here is an
   example of the storage format used:
 #define EXAMPLE(a, b)  "text:" a and b!
   will be stored in macro->value[] as:
 0x0000: 0x00 0x07       (strlen(part 1))
 0x0002: '"', 't', 'e', 'x', 't', ':', '"'   (first part)
 0x0009: 0x00            (part 2, id=0 for replacement by 1st parameter 'a')
 0x000A: 0x00 0x03       (strlen(part 3))
 0x000C: 'a', 'n', 'd'   (part 3)
 0x000F: 0x01            (part 4, id=1 for replacement by 2nd parameter 'b')
 0x0010: 0x00 0x01       (strlen(part 5))
 0x0012: '!'             (part 5)
 0x0013: 0xFF            (end of macro)
  This structure allows to store any number and combination
   of text/parameter and still provide very fast generation
   at macro replacement time.

 Predefined macros are using a call-back function mechanism
   to generate the value on-demand. This value is generated
   in the 'value' buffer of the structure.
 Most of these call-backs will actually cache the value:
   they generate it on the first use (inside a parser,
   not globally) and reuse that value on next call(s).

 Because none of these macros take parameters, the call-back
   mechanism does not include passing of user arguments; the
   complex storage mechanism for argument replacement being
   not necessary the macro->value parameter is used as a
   plain C string to be copied, this fact being recognised
   by macro->function being non-null. It was chosen that the
   call-back function would not have the possibility to fail.
*/

static Bool menu_parser_read_macro_def(WMenuParser parser, WParserMacro *macro, char **argname);

static Bool menu_parser_read_macro_args(WMenuParser parser, WParserMacro *macro,
                                        char *array[], char *buffer, ssize_t buffer_size);

/* Free all used memory associated with parser's macros */
void menu_parser_free_macros(WMenuParser parser)
{
	WParserMacro *macro, *mnext;
#ifdef DEBUG
	unsigned char *rd;
	unsigned int size;
	unsigned int count;

	/* if we were compiled with debugging, we take the opportunity that we
		parse the list of macros, for memory release, to print all the
		definitions */
	printf(__FILE__ ": Macros defined while parsing \"%s\"\n", parser->file_name);
	count = 0;
#endif
	for (macro = parser->macros; macro != NULL; macro = mnext) {
#ifdef DEBUG
		printf("  %s", macro->name);
		if (macro->arg_count >= 0)
			printf("(args=%d)", macro->arg_count);
		printf(" = ");

		if (macro->function != NULL) {
			macro->function(macro, parser);
			printf("function:\"%s\"", macro->value);
		} else {
			rd = macro->value;
			for (;;) {
				putchar('"');
				size  = (*rd++) << 8;
				size |=  *rd++;
				while (size-- > 0) putchar(*rd++);
				putchar('"');
				if (*rd == 0xFF) break;
				printf(" #%d ", (*rd++) + 1);
			}
		}
		printf(", used %d times\n", macro->usage_count);
		count++;
#endif
		mnext = macro->next;
		wfree(macro);
	}
#ifdef DEBUG
	printf(__FILE__ ": %d macros\n", count);
#endif
	parser->macros = NULL; // Security
}

/* Check wether the specified character is valid for a name (macro, parameter) or not */
int isnamechr(char ch)
{
	static const int table[256] = {
		[0] = 0, // In case we'd fall on buggy compiler, to avoid crash
		// C99: 6.7.8.21 -> non specified values are initialised to 0
		['0'] = 1, ['1'] = 1, ['2'] = 1, ['3'] = 1, ['4'] = 1,
		['5'] = 1, ['6'] = 1, ['7'] = 1, ['8'] = 1, ['9'] = 1,
		['A'] = 1, ['B'] = 1, ['C'] = 1, ['D'] = 1, ['E'] = 1, ['F'] = 1,
		['G'] = 1, ['H'] = 1, ['I'] = 1, ['J'] = 1, ['K'] = 1, ['L'] = 1,
		['M'] = 1, ['N'] = 1, ['O'] = 1, ['P'] = 1, ['Q'] = 1, ['R'] = 1,
		['S'] = 1, ['T'] = 1, ['U'] = 1, ['V'] = 1, ['W'] = 1, ['X'] = 1,
		['Y'] = 1, ['Z'] = 1,
		['a'] = 1, ['b'] = 1, ['c'] = 1, ['d'] = 1, ['e'] = 1, ['f'] = 1,
		['g'] = 1, ['h'] = 1, ['i'] = 1, ['j'] = 1, ['k'] = 1, ['l'] = 1,
		['m'] = 1, ['n'] = 1, ['o'] = 1, ['p'] = 1, ['q'] = 1, ['r'] = 1,
		['s'] = 1, ['t'] = 1, ['u'] = 1, ['v'] = 1, ['w'] = 1, ['x'] = 1,
		['y'] = 1, ['z'] = 1,
		['_'] = 1
		// We refuse any UTF-8 coded character, or accents in ISO-xxx codepages
	};
	return table[0x00FF & (unsigned)ch ];
}

/* Parse the definition of the macro and add it to the top-most parser's list */
void menu_parser_define_macro(WMenuParser parser)
{
	WParserMacro *macro;
	int idx;
	char arg_names_buf[MAXLINE];
	char *arg_name[MAX_MACRO_ARG_COUNT];

	if (!menu_parser_skip_spaces_and_comments(parser)) {
		WMenuParserError(parser, _("no macro name found for #define") );
		return;
	}
	macro = wmalloc(sizeof(*macro));

	/* Isolate name of macro */
	idx = 0;
	while (isnamechr(*parser->rd)) {
		if (idx < sizeof(macro->name) - 1)
			macro->name[idx++] = *parser->rd;
		parser->rd++;
	}
	// macro->name[idx] = '\0'; -> Already present because wmalloc filled struct with 0s

	/* Build list of expected arguments */
	if (*parser->rd == '(') {
		parser->rd++;
		idx = 0;
		for (;;) {
			if (!menu_parser_skip_spaces_and_comments(parser)) {
			arglist_error_premature_eol:
				WMenuParserError(parser, _("premature end of file while reading arg-list for macro \"%s\""), macro->name);
				wfree(macro);
				return;
			}
			if (*parser->rd == ')') break;

			if (macro->arg_count >= wlengthof(arg_name)) {
				WMenuParserError(parser, _("too many parameters for macro \"%s\" definition"), macro->name);
				wfree(macro);
				*parser->rd = '\0'; // fake end-of-line to avoid warnings from remaining line content
				return;
			}
			if (isnamechr(*parser->rd)) {
				arg_name[macro->arg_count++] = arg_names_buf + idx;
				do {
					if (idx < sizeof(arg_names_buf) - 1)
						arg_names_buf[idx++] = *parser->rd;
					parser->rd++;
				} while (isnamechr(*parser->rd));
				arg_names_buf[idx] = '\0';
				if (idx < sizeof(arg_names_buf) - 1) idx++;
			} else {
				WMenuParserError(parser, _("invalid character '%c' in arg-list for macro \"%s\" while expecting parameter name"),
									  *parser->rd, macro->name);
				wfree(macro);
				*parser->rd = '\0'; // fake end-of-line to avoid warnings from remaining line content
				return;
			}
			if (!menu_parser_skip_spaces_and_comments(parser))
				goto arglist_error_premature_eol;
			if (*parser->rd == ')') break;

			if (*parser->rd != ',') {
				WMenuParserError(parser, _("invalid character '%c' in arg-list for macro \"%s\" while expecting ',' or ')'"),
									  *parser->rd, macro->name);
				wfree(macro);
				*parser->rd = '\0'; // fake end-of-line to avoid warnings from remaining line content
				return;
			}
			parser->rd++;
		}
		parser->rd++;  // skip the closing ')'
	} else
		macro->arg_count = -1; // Means no parenthesis at all to expect

	/* If we're inside a #if sequence, we abort now, but not sooner in
		order to keep the syntax check */
	if (parser->cond.stack[0].skip) {
		wfree(macro);
		*parser->rd = '\0'; // Ignore macro content
		return;
	}

	/* Get the macro's definition */
	menu_parser_skip_spaces_and_comments(parser);
	if (!menu_parser_read_macro_def(parser, macro, arg_name)) {
		wfree(macro);
		return;
	}

	/* Create the macro in the Root parser */
	while (parser->parent_file != NULL)
		parser = parser->parent_file;

	/* Check that the macro was not already defined */
	if (menu_parser_find_macro(parser, macro->name) != NULL) {
		WMenuParserError(parser, _("macro \"%s\" already defined, ignoring redefinition"),
							  macro->name);
		wfree(macro);
		return;
	}

	/* Append at beginning of list */
	macro->next = parser->macros;
	parser->macros = macro;
}

/* Check if the current word in the parser matches a macro */
WParserMacro *menu_parser_find_macro(WMenuParser parser, const char *name)
{
	const char *ref, *cmp;
	WParserMacro *macro;

	while (parser->parent_file != NULL)
		parser = parser->parent_file;
	for (macro = parser->macros; macro != NULL; macro = macro->next) {
		ref = macro->name;
		cmp = name;
		while (*ref != '\0')
			if (*ref++ != *cmp++)
				goto check_next_macro;
		if (isnamechr(*cmp))
			continue;

		return macro;
	check_next_macro: ;
	}
	return NULL;
}

/* look to see if the next word matches the name of one of the parameter
	names for a macro definition
	This function is internal to the macro definition function as this is
	where the analysis is done */
static inline char *mp_is_parameter(char *parse, const char *param) {
	while (*param)
		if (*parse++ != *param++)
			return NULL;
	if (isnamechr(*parse))
		return NULL;
	return parse;
}

/* Read the content definition part of a #define construct (the part after the optional
	argument list) and store it in the prepared format for quick expansion

	There is no need to keep track of the names of the parameters, so they are stored in
	a temporary storage for the time of the macro parsing. */
static Bool menu_parser_read_macro_def(WMenuParser parser, WParserMacro *macro, char **arg)
{
	unsigned char *wr_size;
	unsigned char *wr;
	unsigned int size_data;
	unsigned int size_max;
	int i;

	wr_size = macro->value;
	size_data = 0;
	wr = wr_size + 2;
	size_max = sizeof(macro->value) - (wr - macro->value) - 3;
	while (menu_parser_skip_spaces_and_comments(parser)) {
		if (isnamechr(*parser->rd)) {
			char *next_rd;

			/* Is the current word a parameter to replace? */
			for (i = 0; i < macro->arg_count; i++) {
				next_rd = mp_is_parameter(parser->rd, arg[i]);
				if (next_rd != NULL) {
					if (wr + 4 >= macro->value + sizeof(macro->value))
						goto error_too_much_data;
					wr_size[0] = (size_data >> 8) & 0xFF;
					wr_size[1] =  size_data       & 0xFF;
					*wr++ = i;
					wr_size = wr;
					wr += 2;
					parser->rd = next_rd;
					*wr++ = ' ';
					size_data = 1;
					size_max = sizeof(macro->value) - (wr - macro->value) - 3;
					goto next_loop; // Because we can't 'break' this loop and 'continue'
					//                 the outer one in a clean and easy way
				}
			}

			/* Not parameter name -> copy as-is */
			do {
				*wr++ = *parser->rd++;
				if (++size_data >= size_max) {
				error_too_much_data:
					WMenuParserError(parser, _("more content than supported for the macro \"%s\""),
										  macro->name);
					return False;
				}
			} while (isnamechr(*parser->rd));
			if (isspace(*parser->rd)) {
				*wr++ = ' ';
				if (++size_data >= size_max)
					goto error_too_much_data;
			}
		} else {
			/* Some uninterresting characters, copy as-is */
			while (*parser->rd != '\0') {
				if (isnamechr(*parser->rd)) break; // handle in next loop
				if (parser->rd[0] == '/')
					if ((parser->rd[1] == '*') || (parser->rd[1] == '/'))
						break; // Comments are handled by std function
				if ((parser->rd[0] == '\\') &&
					 (parser->rd[1] == '\n') &&
					 (parser->rd[2] == '\0'))
					break; // Long-lines are handled by std function
				*wr++ = *parser->rd++;
				if (++size_data >= size_max)
					goto error_too_much_data;
			}
		}
	next_loop:
		;
	}
	wr_size[0] = (size_data >> 8) & 0xFF;
	wr_size[1] =  size_data       & 0xFF;
	*wr = 0xFF;
	return True;
}

/* When a macro is being used in the file, this function will generate the
	expanded value for the macro in the parser's work line.
	It blindly supposes that the data generated in macro->value is valid */
void menu_parser_expand_macro(WMenuParser parser, WParserMacro *macro)
{
	char save_buf[sizeof(parser->line_buffer)];
	char arg_values_buf[MAXLINE];
	char *arg_value[MAX_MACRO_ARG_COUNT];
	char *src, *dst;
	unsigned char *rd;
	unsigned int size;
	int i, space_left;

	/* Skip the name of the macro, this was not done by caller */
	for (i = 0; macro->name[i] != '\0'; i++)
		parser->rd++;

	if (macro->arg_count >= 0) {
		menu_parser_skip_spaces_and_comments(parser);
		if (!menu_parser_read_macro_args(parser, macro, arg_value, arg_values_buf, sizeof(arg_values_buf)))
			return;
	}

#ifdef DEBUG
	macro->usage_count++;
#endif

	/* Save the remaining data from current line as we will overwrite the
		current line's workspace with the expanded macro, so we can re-append
		it afterwards */
	dst = save_buf;
	while ((*dst++ = *parser->rd++) != '\0') ;

	/* Generate expanded macro */
	dst = parser->line_buffer;
	parser->rd = dst;
	space_left = sizeof(parser->line_buffer) - 1;
	if (macro->function != NULL) {
        /* Parser's pre-defined macros actually proposes a function call to
			  generate dynamic value for the expansion of the macro. In this case
			  it is generated as a C string in the macro->value and used directly */
		macro->function(macro, parser);
		rd = macro->value;
		while (--space_left > 0)
			if ((*dst = *rd++) == '\0')
				break;
			else
				dst++;
	} else {
		rd = macro->value;
		for (;;) {
			size  = (*rd++) << 8;
			size |=  *rd++;
			while (size-- > 0) {
				*dst = *rd++;
				if (--space_left > 0) dst++;
			}
			if (*rd == 0xFF) break;
			src = arg_value[*rd++];
			while (*src) {
				*dst = *src++;
				if (--space_left > 0) dst++;
			}
		}
	}

	/* Copy finished -> Re-append the text that was following the macro */
	src = save_buf;
	while (--space_left > 0)
		if ((*dst++ = *src++) == '\0')
			break;
	*dst = '\0';

	if (space_left <= 0)
		WMenuParserError(parser, _("expansion for macro \"%s\" too big, line truncated"),
							  macro->name);
}

/* When reading a macro to be expanded (not being defined), that takes arguments,
	this function parses the arguments being provided */
static Bool menu_parser_read_macro_args(WMenuParser parser, WParserMacro *macro,
													 char *array[], char *buffer, ssize_t buffer_size)
{
	int arg;

	if (*parser->rd != '(') {
		WMenuParserError(parser, _("macro \"%s\" needs parenthesis for arguments"),
							  macro->name);
		return False;
	}
	parser->rd++;

	buffer_size--; // Room for final '\0'
	menu_parser_skip_spaces_and_comments(parser);
	arg = 0;
	for (;;) {
		int paren_count;

		array[arg] = buffer;
		paren_count = 0;
		while (*parser->rd != '\0') {

			if (*parser->rd == '(')
				paren_count++;

			if (paren_count <= 0)
				if ((*parser->rd == ',') ||
					 (*parser->rd == ')') ) break;

			if ((*parser->rd == '"') || (*parser->rd == '\'')) {
				char eot = *parser->rd++;
				if (buffer_size-- > 0) *buffer++ = eot;
				while (*parser->rd) {
					if ((*buffer = *parser->rd++) == eot)
						goto found_end_of_string;
					if (buffer_size-- > 0) buffer++;
				}
				WMenuParserError(parser, _("missing closing quote or double-quote before end-of-line") );
				return False;
			found_end_of_string:
				continue;
			}

			if (isspace(*parser->rd)) {
				if (buffer_size-- > 0) *buffer++ = ' ';
				menu_parser_skip_spaces_and_comments(parser);
				continue;
			}

			*buffer = *parser->rd++;
			if (buffer_size-- > 0) buffer++;
		}
		*buffer = '\0';
		if (buffer_size-- > 0) buffer++;

		arg++;

		if (*parser->rd == ',') {
			parser->rd++;
			if (arg >= macro->arg_count) {
				WMenuParserError(parser, _("too many arguments for macro \"%s\", expected only %d"),
									  macro->name, macro->arg_count);
				return False;
			}
			continue;
		}
		break;
	}
	if (*parser->rd != ')') {
		WMenuParserError(parser, _("premature end of line while searching for arguments to macro \"%s\""),
							  macro->name);
		return False;
	}
	parser->rd++;
	if (arg < macro->arg_count) {
		WMenuParserError(parser, _("not enough arguments for macro \"%s\", expected %d but got only %d"),
							  macro->name, macro->arg_count, arg);
		return False;
	}
	if (buffer_size < 0)
		WMenuParserError(parser, _("too much data in parameter list of macro \"%s\", truncated"),
							  macro->name);
	return True;
}

/******************************************************************************/
/* Definition of pre-defined macros */
/******************************************************************************/

void WMenuParserRegisterSimpleMacro(WMenuParser parser, const char *name, const char *value)
{
	WParserMacro *macro;
	size_t len;
	unsigned char *wr;

	macro = wmalloc(sizeof(*macro));
	strncpy(macro->name, name, sizeof(macro->name)-1);
	macro->arg_count = -1;
	len = strlen(value);
	if (len > sizeof(macro->value) - 3) {
		wwarning(_("size of value for macro '%s' is too big, truncated"), name);
		len = sizeof(macro->value) - 3;
	}
	macro->value[0] = (len >> 8) & 0xFF;
	macro->value[1] =  len       & 0xFF;
	wr = &macro->value[2];
	while (len-- > 0)
		*wr++ = *value++;
	*wr = 0xFF;
	macro->next = parser->macros;
	parser->macros = macro;
}

/* Name of the originally loaded file (before #includes) */
static void mpm_base_file(WParserMacro *this, WMenuParser parser)
{
	unsigned char *src, *dst;

	if (this->value[0] != '\0') return; // Value already evaluated, re-use previous

	while (parser->parent_file != NULL)
		parser = parser->parent_file;

	dst = this->value;
	src = (unsigned char *) parser->file_name;
	*dst++ = '\"';
	while (*src != '\0')
		if (dst < this->value + sizeof(this->value) - 2)
			*dst++ = *src++;
		else
			break;
	*dst++ = '\"';
	*dst   = '\0';
}

/* Number of #include currently nested */
static void mpm_include_level(WParserMacro *this, WMenuParser parser)
{
	int level = 0;
	while (parser->parent_file != NULL) {
		parser = parser->parent_file;
		level++;
	}
	snprintf((char *) this->value, sizeof(this->value), "%d", level);
}

/* Name of current file */
static void mpm_current_file(WParserMacro *this, WMenuParser parser)
{
	unsigned char *src, *dst;

	dst = this->value;
	src = (unsigned char *) parser->file_name;
	*dst++ = '\"';
	while (*src != '\0')
		if (dst < this->value + sizeof(this->value) - 2)
			*dst++ = *src++;
		else
			break;
	*dst++ = '\"';
	*dst   = '\0';
}

/* Number of current line */
static void mpm_current_line(WParserMacro *this, WMenuParser parser)
{
	snprintf((char *) this->value, sizeof(this->value), "%d", parser->line_number);
}

/* Name of host on which we are running, not necessarily displaying */
static void mpm_get_hostname(WParserMacro *this, WMenuParser parser)
{
	char *h;

	if (this->value[0] != '\0') return; // Value already evaluated, re-use previous

	h = getenv("HOSTNAME");
	if (h == NULL) {
		h = getenv("HOST");
		if (h == NULL) {
			if (gethostname((char *) this->value, sizeof(this->value) ) != 0) {
				WMenuParserError(parser, _("could not determine %s"), "HOSTNAME");
				this->value[0] = '?';
				this->value[1] = '?';
				this->value[2] = '?';
				this->value[3] = '\0';
			}
			return;
		}
	}
	wstrlcpy((char *) this->value, h, sizeof(this->value) );
}

/* Name of the current user */
static void mpm_get_user_name(WParserMacro *this, WMenuParser parser)
{
	char *user;

	if (this->value[0] != '\0') return; // Value already evaluated, re-use previous

	user = getlogin();
	if (user == NULL) {
		struct passwd *pw_user;

		pw_user = getpwuid(getuid());
		if (pw_user == NULL) {
		error_no_username:
			WMenuParserError(parser, _("could not determine %s"), "USER" );
			/* Fall back on numeric id - better than nothing */
			snprintf((char *) this->value, sizeof(this->value), "%d", getuid() );
			return;
		}
		user = pw_user->pw_name;
		if (user == NULL) goto error_no_username;
	}
	wstrlcpy((char *) this->value, user, sizeof(this->value) );
}

/* Number id of the user under which we are running */
static void mpm_get_user_id(WParserMacro *this, WMenuParser parser)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) parser;

	if (this->value[0] != '\0') return; // Already evaluated, re-use previous
	snprintf((char *) this->value, sizeof(this->value), "%d", getuid() );
}

/* Small helper to automate creation of one pre-defined macro in the parser */
static void w_create_macro(WMenuParser parser, const char *name, WParserMacroFunction *handler)
{
	WParserMacro *macro;

	macro = wmalloc(sizeof(*macro));
	strcpy(macro->name, name);
	macro->function = handler;
	macro->arg_count = -1;
	macro->next = parser->macros;
	parser->macros = macro;
}

/***** Register all the pre-defined macros in the parser *****/
void menu_parser_register_preset_macros(WMenuParser parser)
{
	/* Defined by CPP: common predefined macros (GNU C extension) */
	w_create_macro(parser, "__BASE_FILE__", mpm_base_file);
	w_create_macro(parser, "__INCLUDE_LEVEL__", mpm_include_level);

	/* Defined by CPP: standard predefined macros */
	w_create_macro(parser, "__FILE__", mpm_current_file);
	w_create_macro(parser, "__LINE__", mpm_current_line);
	// w_create_macro(parser, "__DATE__", NULL);  [will be implemented only per user request]
	// w_create_macro(parser, "__TIME__", NULL);  [will be implemented only per user request]

	/* Historically defined by WindowMaker */
	w_create_macro(parser, "HOST", mpm_get_hostname);
	w_create_macro(parser, "UID", mpm_get_user_id);
	w_create_macro(parser, "USER", mpm_get_user_name);
}
