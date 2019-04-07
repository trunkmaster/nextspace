/*
 * Until FreeBSD gets their act together;
 * http://www.mail-archive.com/freebsd-hackers@freebsd.org/msg69469.html
 */
#if defined( FREEBSD )
#   undef _XOPEN_SOURCE
#endif

#include "wconfig.h"

#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>
#ifdef HAVE_BSD_STRING_H
#include <bsd/string.h>
#endif

#include "WUtil.h"

#define PRC_ALPHA	0
#define PRC_BLANK	1
#define PRC_ESCAPE	2
#define PRC_DQUOTE	3
#define PRC_EOS		4
#define PRC_SQUOTE	5

typedef struct {
	short nstate;
	short output;
} DFA;

static DFA mtable[9][6] = {
	{{3, 1}, {0, 0}, {4, 0}, {1, 0}, {8, 0}, {6, 0}},
	{{1, 1}, {1, 1}, {2, 0}, {3, 0}, {5, 0}, {1, 1}},
	{{1, 1}, {1, 1}, {1, 1}, {1, 1}, {5, 0}, {1, 1}},
	{{3, 1}, {5, 0}, {4, 0}, {1, 0}, {5, 0}, {6, 0}},
	{{3, 1}, {3, 1}, {3, 1}, {3, 1}, {5, 0}, {3, 1}},
	{{-1, -1}, {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}},	/* final state */
	{{6, 1}, {6, 1}, {7, 0}, {6, 1}, {5, 0}, {3, 0}},
	{{6, 1}, {6, 1}, {6, 1}, {6, 1}, {5, 0}, {6, 1}},
	{{-1, -1}, {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}},	/* final state */
};

char *wtokennext(char *word, char **next)
{
	char *ptr;
	char *ret, *t;
	int state, ctype;

	t = ret = wmalloc(strlen(word) + 1);
	ptr = word;

	state = 0;
	while (1) {
		if (*ptr == 0)
			ctype = PRC_EOS;
		else if (*ptr == '\\')
			ctype = PRC_ESCAPE;
		else if (*ptr == '"')
			ctype = PRC_DQUOTE;
		else if (*ptr == '\'')
			ctype = PRC_SQUOTE;
		else if (*ptr == ' ' || *ptr == '\t')
			ctype = PRC_BLANK;
		else
			ctype = PRC_ALPHA;

		if (mtable[state][ctype].output) {
			*t = *ptr;
			t++;
			*t = 0;
		}
		state = mtable[state][ctype].nstate;
		ptr++;
		if (mtable[state][0].output < 0) {
			break;
		}
	}

	if (*ret == 0) {
		wfree(ret);
		ret = NULL;
	}

	if (ctype == PRC_EOS)
		*next = NULL;
	else
		*next = ptr;

	return ret;
}

/* separate a string in tokens, taking " and ' into account */
void wtokensplit(char *command, char ***argv, int *argc)
{
	char *token, *line;
	int count;

	count = 0;
	line = command;
	do {
		token = wtokennext(line, &line);
		if (token) {
			if (count == 0)
				*argv = wmalloc(sizeof(**argv));
			else
				*argv = wrealloc(*argv, (count + 1) * sizeof(**argv));
			(*argv)[count++] = token;
		}
	} while (token != NULL && line != NULL);

	*argc = count;
}

char *wtokenjoin(char **list, int count)
{
	int i, j;
	char *flat_string, *wspace;

	j = 0;
	for (i = 0; i < count; i++) {
		if (list[i] != NULL && list[i][0] != 0) {
			j += strlen(list[i]);
			if (strpbrk(list[i], " \t"))
				j += 2;
		}
	}

	flat_string = wmalloc(j + count + 1);

	for (i = 0; i < count; i++) {
		if (list[i] != NULL && list[i][0] != 0) {
			if (i > 0 &&
			    wstrlcat(flat_string, " ", j + count + 1) >= j + count + 1)
					goto error;

			wspace = strpbrk(list[i], " \t");

			if (wspace &&
			    wstrlcat(flat_string, "\"", j + count + 1) >= j + count + 1)
					goto error;

			if (wstrlcat(flat_string, list[i], j + count + 1) >= j + count + 1)
				goto error;

			if (wspace &&
			    wstrlcat(flat_string, "\"", j + count + 1) >= j + count + 1)
					goto error;
		}
	}

	return flat_string;

error:
	wfree(flat_string);

	return NULL;
}

void wtokenfree(char **tokens, int count)
{
	while (count--)
		wfree(tokens[count]);
	wfree(tokens);
}

char *wtrimspace(const char *s)
{
	const char *t;

	if (s == NULL)
		return NULL;

	while (isspace(*s) && *s)
		s++;
	t = s + strlen(s) - 1;
	while (t > s && isspace(*t))
		t--;

	return wstrndup(s, t - s + 1);
}

char *wstrdup(const char *str)
{
	assert(str != NULL);

	return strcpy(wmalloc(strlen(str) + 1), str);
}

char *wstrndup(const char *str, size_t len)
{
	char *copy;

	assert(str != NULL);

	len = WMIN(len, strlen(str));
	copy = strncpy(wmalloc(len + 1), str, len);
	copy[len] = 0;

	return copy;
}

char *wstrconcat(const char *str1, const char *str2)
{
	char *str;
	size_t slen;

	if (!str1 && str2)
		return wstrdup(str2);
	else if (str1 && !str2)
		return wstrdup(str1);
	else if (!str1 && !str2)
		return NULL;

	slen = strlen(str1) + strlen(str2) + 1;
	str = wmalloc(slen);
	if (wstrlcpy(str, str1, slen) >= slen ||
	    wstrlcat(str, str2, slen) >= slen) {
		wfree(str);
		return NULL;
	}

	return str;
}

char *wstrappend(char *dst, const char *src)
{
	size_t slen;

	if (!src || *src == 0)
		return dst;
	else if (!dst)
		return wstrdup(src);

	slen = strlen(dst) + strlen(src) + 1;
	dst = wrealloc(dst, slen);
	strcat(dst, src);

	return dst;
}


#ifdef HAVE_STRLCAT
size_t
wstrlcat(char *dst, const char *src, size_t siz)
{
	return strlcat(dst, src, siz);
}
#else
/*	$OpenBSD: strlcat.c,v 1.13 2005/08/08 08:05:37 espie Exp $	*/

/*
 * Copyright (c) 1998 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * Appends src to string dst of size siz (unlike strncat, siz is the
 * full size of dst, not space left).  At most siz-1 characters
 * will be copied.  Always NUL terminates (unless siz <= strlen(dst)).
 * Returns strlen(src) + MIN(siz, strlen(initial dst)).
 * If retval >= siz, truncation occurred.
 */
size_t
wstrlcat(char *dst, const char *src, size_t siz)
{
	char *d = dst;
	const char *s = src;
	size_t n = siz;
	size_t dlen;

	/* Find the end of dst and adjust bytes left but don't go past end */
	while (n-- != 0 && *d != '\0')
		d++;
	dlen = d - dst;
	n = siz - dlen;

	if (n == 0)
		return(dlen + strlen(s));
	while (*s != '\0') {
		if (n != 1) {
			*d++ = *s;
			n--;
		}
		s++;
	}
	*d = '\0';

	return(dlen + (s - src));	/* count does not include NUL */
}
#endif /* HAVE_STRLCAT */

#ifdef HAVE_STRLCPY
size_t
wstrlcpy(char *dst, const char *src, size_t siz)
{
	return strlcpy(dst, src, siz);
}
#else

/*	$OpenBSD: strlcpy.c,v 1.11 2006/05/05 15:27:38 millert Exp $	*/

/*
 * Copyright (c) 1998 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * Copy src to string dst of size siz.  At most siz-1 characters
 * will be copied.  Always NUL terminates (unless siz == 0).
 * Returns strlen(src); if retval >= siz, truncation occurred.
 */
size_t
wstrlcpy(char *dst, const char *src, size_t siz)
{
	char *d = dst;
	const char *s = src;
	size_t n = siz;

	/* Copy as many bytes as will fit */
	if (n != 0) {
		while (--n != 0) {
			if ((*d++ = *s++) == '\0')
				break;
		}
	}

	/* Not enough room in dst, add NUL and traverse rest of src */
	if (n == 0) {
		if (siz != 0)
			*d = '\0';		/* NUL-terminate dst */
		while (*s++)
			;
	}

	return(s - src - 1);	/* count does not include NUL */
}
#endif /* HAVE_STRLCPY */

/* transform `s' so that the result is safe to pass to the shell as an argument.
 * returns a newly allocated string.
 * with very heavy inspirations from NetBSD's shquote(3).
 */
char *wshellquote(const char *s)
{
	char *p, *r, *last, *ret;
	size_t slen;
	int needs_quoting;

	if (!s)
		return NULL;

	needs_quoting = !*s;			/* the empty string does need quoting */

	/* do not quote if consists only of the following characters */
	for (p = (char *)s; *p && !needs_quoting; p++) {
		needs_quoting = !(isalnum(*p) || (*p == '+') || (*p == '/') ||
				 (*p == '.') || (*p == ',') || (*p == '-'));
	}

	if (!needs_quoting)
		return wstrdup(s);

	for (slen = 0, p = (char *)s; *p; p++)		/* count space needed (worst case) */
		slen += *p == '\'' ? 4 : 1;		/* every single ' becomes ''\' */

	slen += 2 /* leading + trailing "'" */ + 1 /* NULL */;

	ret = r = wmalloc(slen);
	p = (char *)s;
	last = p;

	if (*p != '\'')					/* if string doesn't already begin with "'" */
		*r++ ='\'';				/* start putting it in quotes */

	while (*p) {
		last = p;
		if (*p == '\'') {			/* turn each ' into ''\' */
			if (p != s)			/* except if it's the first ', in which case */
				*r++ = '\'';		/* only escape it */
			*r++ = '\\';
			*r++ = '\'';
			while (*++p && *p == '\'') {	/* keep turning each consecutive 's into \' */
				*r++ = '\\';
				*r++ = '\'';
			}
			if (*p)				/* if more input follows, terminate */
				*r++ = '\'';		/* what we have so far */
		} else {
			*r++ = *p++;
		}
	}

	if (*last != '\'')				/* if the last one isn't already a ' */
		*r++ = '\'';				/* terminate the whole shebang */

	*r = '\0';

	return ret;					/* technically, we lose (but not leak) a couple of */
							/* bytes (twice the number of consecutive 's in the */
							/* input or so), but since these are relatively rare */
							/* and short-lived strings, not sure if a trip to */
							/* wstrdup+wfree worths the gain. */
}
