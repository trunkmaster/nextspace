#ifndef __WORKSPACE_WM_WSTRING__
#define __WORKSPACE_WM_WSTRING__

#include <sys/types.h>

char *wstrdup(const char *str);
char *wstrndup(const char *str, size_t len);

/* Concatenate str1 with str2 and return that in a newly malloc'ed string.
 * str1 and str2 can be any strings including static and constant strings.
 * str1 and str2 will not be modified.
 * Free the returned string when you're done with it. */
char *wstrconcat(const char *str1, const char *str2);

/* Join string seperated by "." symbol. */
char *wstrconcatdot(const char *a, const char *b);

/* This will append src to dst, and return dst. dst MUST be either NULL
 * or a string that was a result of a dynamic allocation (malloc, realloc
 * wmalloc, wrealloc, ...). dst CANNOT be a static or a constant string!
 * Modifies dst (no new string is created except if dst==NULL in which case
 * it is equivalent to calling wstrdup(src) ).
 * The returned address may be different from the original address of dst,
 * so always assign the returned address to avoid dangling pointers. */
char *wstrappend(char *dst, const char *src);

size_t wstrlcpy(char *, const char *, size_t);
size_t wstrlcat(char *, const char *, size_t);

void wtokensplit(char *command, char ***argv, int *argc);

char *wtokennext(char *word, char **next);

char *wtokenjoin(char **list, int count);

void wtokenfree(char **tokens, int count);

char *wtrimspace(const char *s);

/* transform `s' so that the result is safe to pass to the shell as an argument.
 * returns a newly allocated string.
 * with very heavy inspirations from NetBSD's shquote(3).
 */
char *wshellquote(const char *s);

#endif
