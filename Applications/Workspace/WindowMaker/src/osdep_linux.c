
#include <sys/types.h>
#include <sys/stat.h>

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <WINGs/WUtil.h>

#include "wconfig.h"
#include "osdep.h"


/*
 * copy argc and argv for an existing process identified by `pid'
 * into suitable storage given in ***argv and *argc.
 *
 * subsequent calls use the same static area for argv and argc.
 *
 * returns 0 for failure, in which case argc := 0 and argv := NULL
 * returns 1 for success
 */
Bool GetCommandForPid(int pid, char ***argv, int *argc)
{
	static char buf[_POSIX_ARG_MAX];
	int fd, i, j;
	ssize_t count;

	*argv = NULL;
	*argc = 0;

	/* cmdline is a flattened series of null-terminated strings */
	snprintf(buf, sizeof(buf), "/proc/%d/cmdline", pid);
	while (1) {
		/* not switching this to stdio yet, as this does not need
		 * to be portable, and i'm lazy */
		fd = open(buf, O_RDONLY);
		if (fd != -1)
			break;
		if (errno == EINTR)
			continue;
		return False;
	}

	while (1) {
		count = read(fd, buf, sizeof(buf));
		if (count != -1)
			break;
		if (errno == EINTR)
			continue;
		close(fd);
		return False;
	}
	close(fd);

	/* count args */
	for (i = 0; i < count; i++)
		if (buf[i] == '\0')
			(*argc)++;

	if (*argc == 0)
		return False;

	*argv = (char **)wmalloc(sizeof(char *) * (*argc + 1 /* term. null ptr */));
	(*argv)[0] = buf;

	/* go through buf, set argv[$next] to the beginning of each string */
	for (i = 0, j = 1; i < count; i++) {
		if (buf[i] != '\0')
			continue;
		if (i < count - 1)
			(*argv)[j++] = &buf[i + 1];
		if (j == *argc)
			break;
	}

	/* the list of arguments must be terminated by a null pointer */
	(*argv)[j] = NULL;
	return True;
}
