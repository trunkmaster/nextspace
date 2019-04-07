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

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>

#include <WINGs/WUtil.h>

#include "menuparser.h"

static WMenuParser menu_parser_create_new(const char *file_name, void *file,
					  const char *include_default_paths);
static char *menu_parser_isolate_token(WMenuParser parser);
static void menu_parser_get_directive(WMenuParser parser);
static Bool menu_parser_include_file(WMenuParser parser);
static void menu_parser_condition_ifmacro(WMenuParser parser, Bool check_exists);
static void menu_parser_condition_else(WMenuParser parser);
static void menu_parser_condition_end(WMenuParser parser);


/* Constructor and Destructor for the Menu Parser object */
WMenuParser WMenuParserCreate(const char *file_name, void *file,
			      const char *include_default_paths)
{
	WMenuParser parser;

	parser = menu_parser_create_new(file_name, file, include_default_paths);
	menu_parser_register_preset_macros(parser);
	return parser;
}

void WMenuParserDelete(WMenuParser parser)
{
	if (parser->include_file) {
		/* Trick: the top parser's data are not wmalloc'd, we point on the
		 * provided data so we do not wfree it; however for include files
		 * we did wmalloc them.
		 * This code should not be used as the wfree is done when we reach
		 * the end of an include file; however this may not happen when an
		 * early exit occurs (typically when 'readMenuFile' does not find
		 * its expected command). */
		fclose(parser->include_file->file_handle);
		wfree((char *) parser->include_file->file_name);
		WMenuParserDelete(parser->include_file);
	}

	if (parser->macros)
		menu_parser_free_macros(parser);

	wfree(parser);
}

static WMenuParser menu_parser_create_new(const char *file_name, void *file,
					  const char *include_default_paths)
{
	WMenuParser parser;

	parser = wmalloc(sizeof(*parser));
	parser->include_default_paths = include_default_paths;
	parser->file_name = file_name;
	parser->file_handle = file;
	parser->rd = parser->line_buffer;

	return parser;
}

/* To report helpfull messages to user */
const char *WMenuParserGetFilename(WMenuParser parser)
{
	return parser->file_name;
}

void WMenuParserError(WMenuParser parser, const char *msg, ...)
{
	char buf[MAXLINE];
	va_list args;
	WMenuParser parent;

	while (parser->include_file)
		parser = parser->include_file;

	va_start(args, msg);
	vsnprintf(buf, sizeof(buf), msg, args);
	va_end(args);
	__wmessage("WMenuParser", parser->file_name, parser->line_number,
		   WMESSAGE_TYPE_WARNING, "%s", buf);

	for (parent = parser->parent_file; parent != NULL; parent = parent->parent_file)
		__wmessage("WMenuParser", parser->file_name, parser->line_number,
			   WMESSAGE_TYPE_WARNING, _("   included from file \"%s\" at line %d"),
			   parent->file_name, parent->line_number);
}

/* Read one line from file and split content
 * The function returns False when the end of file is reached */
Bool WMenuParserGetLine(WMenuParser top_parser, char **title, char **command,
			char **parameter, char **shortcut)
{
	WMenuParser cur_parser;
	enum { GET_TITLE, GET_COMMAND, GET_PARAMETERS, GET_SHORTCUT } scanmode;
	char *token, *params = NULL;
	char lineparam[MAXLINE];

	lineparam[0] = '\0';
	*title = NULL;
	*command = NULL;
	*parameter = NULL;
	*shortcut = NULL;
	scanmode = GET_TITLE;

read_next_line_with_filechange:
	cur_parser = top_parser;
	while (cur_parser->include_file)
		cur_parser = cur_parser->include_file;

read_next_line:
	if (fgets(cur_parser->line_buffer, sizeof(cur_parser->line_buffer), cur_parser->file_handle) == NULL) {
		if (cur_parser->cond.depth > 0) {
			int i;

			for (i = 0; i < cur_parser->cond.depth; i++)
				WMenuParserError(cur_parser, _("missing #endif to match #%s at line %d"),
						 cur_parser->cond.stack[i].name, cur_parser->cond.stack[i].line);
		}

		if (cur_parser->parent_file == NULL)
			/* Not inside an included file -> we have reached the end */
			return False;

		/* We have only reached the end of an included file -> go back to calling file */
		fclose(cur_parser->file_handle);
		wfree((char *) cur_parser->file_name);
		cur_parser = cur_parser->parent_file;
		wfree(cur_parser->include_file);
		cur_parser->include_file = NULL;
		goto read_next_line_with_filechange;
	}

	cur_parser->line_number++;
	cur_parser->rd = cur_parser->line_buffer;

	for (;;) {
		if (!menu_parser_skip_spaces_and_comments(cur_parser)) {
			/* We reached the end of line */
			if (scanmode == GET_TITLE)
				goto read_next_line;	/* Empty line -> skip */
			else
				break;			/* Finished reading current line -> return it to caller */
		}

		if ((scanmode == GET_TITLE) && (*cur_parser->rd == '#')) {
			cur_parser->rd++;
			menu_parser_get_directive(cur_parser);
			goto read_next_line_with_filechange;
		}

		if (cur_parser->cond.stack[0].skip)
			goto read_next_line;

		/* Found a word */
		token = menu_parser_isolate_token(cur_parser);
		switch (scanmode) {
		case GET_TITLE:
			*title = token;
			scanmode = GET_COMMAND;
			break;

		case GET_COMMAND:
			if (strcmp(token, "SHORTCUT") == 0) {
				scanmode = GET_SHORTCUT;
				wfree(token);
			} else {
				*command = token;
				scanmode = GET_PARAMETERS;
			}
			break;

		case GET_SHORTCUT:
			if (*shortcut != NULL) {
				WMenuParserError(top_parser, _("multiple SHORTCUT definition not valid") );
				wfree(*shortcut);
			}
			*shortcut = token;
			scanmode = GET_COMMAND;
			break;

		case GET_PARAMETERS:
			{
				char *src;

				if (params == NULL) {
					params = lineparam;
				} else {
					if ((params - lineparam) < sizeof(lineparam) - 1)
						*params++ = ' ';
				}

				src = token;
				while ((params - lineparam) < sizeof(lineparam) - 1)
					if ( (*params = *src++) == '\0')
						break;
					else
						params++;
				wfree(token);
			}
			break;
		}
	}

	if (params != NULL) {
		lineparam[sizeof(lineparam) - 1] = '\0';
		*parameter = wstrdup(lineparam);
	}

	return True;
}

/* Return False when there's nothing left on the line,
   otherwise increment parser's pointer to next token */
Bool menu_parser_skip_spaces_and_comments(WMenuParser parser)
{
	for (;;) {
		while (isspace(*parser->rd))
			parser->rd++;

		if (*parser->rd == '\0') {
			return False; /* Found the end of current line */
		} else if ((parser->rd[0] == '\\') &&
			   (parser->rd[1] == '\n') &&
			   (parser->rd[2] == '\0')) {
			/* Means that the current line is expected to be continued on next line */
			if (fgets(parser->line_buffer, sizeof(parser->line_buffer), parser->file_handle) == NULL) {
				WMenuParserError(parser, _("premature end of file while expecting a new line after '\\'") );
				return False;
			}
			parser->line_number++;
			parser->rd = parser->line_buffer;

		} else if (parser->rd[0] == '/') {
			if (parser->rd[1] == '/')	/* Single line C comment */
				return False;		/* Won't find anything more on this line */

			if (parser->rd[1] == '*') {
				int start_line;

				start_line = parser->line_number;
				parser->rd += 2;
				for (;;) {
					/* Search end-of-comment marker */
					while (*parser->rd != '\0') {
						if ((parser->rd[0] == '*') && (parser->rd[1] == '/'))
							goto found_end_of_comment;

						parser->rd++;
					}

					/* Marker not found -> load next line */
					if (fgets(parser->line_buffer, sizeof(parser->line_buffer), parser->file_handle) == NULL) {
						WMenuParserError(parser, _("reached end of file while searching '*/' for comment started at line %d"), start_line);
						return False;
					}

					parser->line_number++;
					parser->rd = parser->line_buffer;
				}

found_end_of_comment:
				parser->rd += 2;	/* Skip closing mark */
				continue;		/* Because there may be spaces after the comment */
			}

			return True;			/* the '/' was not a comment, treat it as user data */
		} else {
			return True;			/* Found some data */
		}
	}
}

/* read a token (non-spaces suite of characters)
 * the result is wmalloc's, so it needs to be free'd */
static char *menu_parser_isolate_token(WMenuParser parser)
{
	char buffer_token[sizeof(parser->line_buffer)];
	char *token;
	int limit = MAX_NESTED_MACROS;

	token = buffer_token;

restart_token_split:

	while (*parser->rd != '\0')
		if (isspace(*parser->rd)) {
			break;

		} else if ((parser->rd[0] == '/') &&
			 ((parser->rd[1] == '*') || (parser->rd[1] == '/'))) {
			break;

		} else if (parser->rd[0] == '\\') {
			if ((parser->rd[1] == '\n') || (parser->rd[1] == '\0'))
				break;

			parser->rd++;
			*token++ = *parser->rd++;

		} else if (*parser->rd == '"' ) {
			char ch;

			/* Double-quoted string deserve special processing because macros are not expanded
				inside. We also remove the double quotes. */
			parser->rd++;
			while ((*parser->rd != '\0') && (*parser->rd != '\n')) {
				ch = *parser->rd++;
				if (ch == '\\') {
					if ((*parser->rd == '\0') || (*parser->rd == '\n'))
						break;
					*token++ = *parser->rd++;
				} else if (ch == '"')
					goto found_end_dquote;
				else
					*token++ = ch;
			}

			WMenuParserError(parser, _("missing closing double-quote before end-of-line") );

found_end_dquote:
			;

		} else if (*parser->rd == '\'') {
			char ch;

			/* Simple-quoted string deserve special processing because we keep their content
				as-is, including the quotes and the \-escaped text */
			*token++ = *parser->rd++;
			while ((*parser->rd != '\0') && (*parser->rd != '\n')) {
				ch = *parser->rd++;
				*token++ = ch;
				if (ch == '\'')
					goto found_end_squote;
			}

			WMenuParserError(parser, _("missing closing simple-quote before end-of-line") );

found_end_squote:
			;

		} else if (isnamechr(*parser->rd)) {
			WParserMacro *macro;

			macro = menu_parser_find_macro(parser, parser->rd);
			if (macro != NULL) {
				/* The expansion is done inside the parser's buffer
					this is needed to allow sub macro calls */
				menu_parser_expand_macro(parser, macro);

				/* Restart parsing to allow expansion of sub macro calls */
				if (limit-- > 0)
					goto restart_token_split;

				WMenuParserError(parser, _("too many nested macro expansions, breaking loop"));

				while (isnamechr(*parser->rd))
					parser->rd++;

				break;
			} else {
				while (isnamechr(*parser->rd))
					*token++ = *parser->rd++;
			}
		} else {
			*token++ = *parser->rd++;
		}

	*token++ = '\0';
	token = wmalloc(token - buffer_token);
	strcpy(token, buffer_token);

	return token;
}

/* Processing of special # directives */
static void menu_parser_get_directive(WMenuParser parser)
{
	char *command;

	/* Isolate the command */
	while (isspace(*parser->rd))
		parser->rd++;

	command = parser->rd;
	while (*parser->rd)
		if (isspace(*parser->rd)) {
			*parser->rd++ = '\0';
			break;
		} else {
			parser->rd++;
		}

	if (strcmp(command, "include") == 0) {
		if (!menu_parser_include_file(parser))
			return;

	} else if (strcmp(command, "define") == 0) {
		menu_parser_define_macro(parser);

	} else if (strcmp(command, "ifdef") == 0) {
		menu_parser_condition_ifmacro(parser, 1);

	} else if (strcmp(command, "ifndef") == 0) {
		menu_parser_condition_ifmacro(parser, 0);

	} else if (strcmp(command, "else") == 0) {
		menu_parser_condition_else(parser);

	} else if (strcmp(command, "endif") == 0) {
		menu_parser_condition_end(parser);

	} else {
		WMenuParserError(parser, _("unknown directive '#%s'"), command);
		return;
	}

	if (menu_parser_skip_spaces_and_comments(parser))
		WMenuParserError(parser, _("extra text after '#' command is ignored: \"%.16s...\""),
				 parser->rd);
}

/* Extract the file name, search for it in known directories
 * and create a sub-parser to handle it.
 * Returns False if the file could not be found */
static Bool menu_parser_include_file(WMenuParser parser)
{
	char buffer[MAXLINE];
	char *req_filename, *fullfilename, *p;
	char eot;
	FILE *fh;

	if (!menu_parser_skip_spaces_and_comments(parser)) {
		WMenuParserError(parser, _("no file name found for #include") );
		return False;
	}

	switch (*parser->rd++) {
	case '<':
		eot = '>';
		break;
	case '"':
		eot = '"';
		break;
	default:
		WMenuParserError(parser, _("file name must be enclosed in brackets or double-quotes for #define") );
		return False;
	}

	req_filename = parser->rd;
	while (*parser->rd) {
		if (*parser->rd == eot) {
			*parser->rd++ = '\0';
			goto found_end_define_fname;
		} else {
			parser->rd++;
		}
	}

	WMenuParserError(parser, _("missing closing '%c' in filename specification"), eot);
	return False;

found_end_define_fname:
	/* If we're inside a #if sequence, we abort now, but not sooner in
	 * order to keep the syntax check */
	if (parser->cond.stack[0].skip)
		return False;

	{ /* Check we are not nesting too many includes */
		WMenuParser p;
		int count;

		count = 0;
		for (p = parser; p->parent_file; p = p->parent_file)
			count++;

		if (count > MAX_NESTED_INCLUDES) {
			WMenuParserError(parser, _("too many nested #include's"));
			return False;
		}
	}

	/* Absolute paths */
	fullfilename = req_filename;
	if (req_filename[0] != '/') {
		/* Search first in the same directory as the current file */
		p = strrchr(parser->file_name, '/');
		if (p != NULL) {
			int len;

			len = p - parser->file_name + 1;
			if (len > sizeof(buffer) - 1)
				len = sizeof(buffer) - 1;

			strncpy(buffer, parser->file_name, len);
			strncpy(buffer+len, req_filename, sizeof(buffer) - len - 1);
			buffer[sizeof(buffer) - 1] = '\0';
			fullfilename = buffer;
		}
	}
	fh = fopen(fullfilename, "rb");

	/* Not found? Search in wmaker's known places */
	if (fh == NULL) {
		if (req_filename[0] != '/') {
			const char *src;
			int idx;

			fullfilename = buffer;
			src = parser->include_default_paths;
			while (*src != '\0') {
				idx = 0;
				if (*src == '~') {
					char *home = wgethomedir();
					while (*home != '\0') {
						if (idx < sizeof(buffer) - 2)
							buffer[idx++] = *home;
						home++;
					}
					src++;
				}

				while ((*src != '\0') && (*src != ':')) {
					if (idx < sizeof(buffer) - 2)
						buffer[idx++] = *src;
					src++;
				}

				buffer[idx++] = '/';
				for (p = req_filename; *p != '\0'; p++)
					if (idx < sizeof(buffer) - 1)
						buffer[idx++] = *p;
				buffer[idx] = '\0';

				fh = fopen(fullfilename, "rb");
				if (fh != NULL)
					goto found_valid_file;

				if (*src == ':')
					src++;
			}
		}
		WMenuParserError(parser, _("could not find file \"%s\" for #include"), req_filename);
		return False;
	}

	/* Found the file, make it our new source */
found_valid_file:
	parser->include_file = menu_parser_create_new(wstrdup(req_filename), fh, parser->include_default_paths);
	parser->include_file->parent_file = parser;
	return True;
}

/* Check wether a macro exists or not, and marks the parser to ignore the
 * following data accordingly */
static void menu_parser_condition_ifmacro(WMenuParser parser, Bool check_exists)
{
	WParserMacro *macro;
	int idx;
	const char *cmd_name, *macro_name;

	cmd_name = check_exists?"ifdef":"ifndef";
	if (!menu_parser_skip_spaces_and_comments(parser)) {
		WMenuParserError(parser, _("missing macro name argument to #%s"), cmd_name);
		return;
	}

	/* jump to end of provided name for later checks that no extra stuff is following */
	macro_name = parser->rd;
	while (isnamechr(*parser->rd))
		parser->rd++;

	/* Add this condition to the stack of conditions */
	if (parser->cond.depth >= wlengthof(parser->cond.stack)) {
		WMenuParserError(parser, _("too many nested #if sequences") );
		return;
	}

	for (idx = parser->cond.depth - 1; idx >= 0; idx--)
		parser->cond.stack[idx + 1] = parser->cond.stack[idx];

	parser->cond.depth++;

	if (parser->cond.stack[1].skip) {
		parser->cond.stack[0].skip = True;
	} else {
		macro = menu_parser_find_macro(parser, macro_name);
		parser->cond.stack[0].skip =
			((check_exists)  && (macro == NULL)) ||
			((!check_exists) && (macro != NULL)) ;
	}

	strcpy(parser->cond.stack[0].name, cmd_name);
	parser->cond.stack[0].line = parser->line_number;
}

/* Swap the 'data ignore' flag because a #else condition was found */
static void menu_parser_condition_else(WMenuParser parser)
{
	if (parser->cond.depth <= 0) {
		WMenuParserError(parser, _("found #%s but has no matching #if"), "else");
		return;
	}

	if ((parser->cond.depth > 1) && (parser->cond.stack[1].skip))
		/* The containing #if is false, so we continue skipping anyway */
		parser->cond.stack[0].skip = True;
	else
		parser->cond.stack[0].skip = !parser->cond.stack[0].skip;
}

/* Closes the current conditional, removing it from the stack */
static void menu_parser_condition_end(WMenuParser parser)
{
	int idx;

	if (parser->cond.depth <= 0) {
		WMenuParserError(parser, _("found #%s but has no matching #if"), "endif");
		return;
	}

	if (--parser->cond.depth > 0)
		for (idx = 0; idx < parser->cond.depth; idx++)
			parser->cond.stack[idx] = parser->cond.stack[idx + 1];
	else
		parser->cond.stack[0].skip = False;
}
