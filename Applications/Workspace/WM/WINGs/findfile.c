/*
 *  Window Maker miscelaneous function library
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#include "wconfig.h"

#include "WUtil.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pwd.h>
#include <limits.h>

#ifndef PATH_MAX
#define PATH_MAX  1024
#endif


char *wgethomedir()
{
	static char *home = NULL;
	char *tmp;
	struct passwd *user;

	if (home)
		return home;

#ifdef HAVE_SECURE_GETENV
	tmp = secure_getenv("HOME");
#else
	tmp = getenv("HOME");
#endif
	if (tmp) {
		home = wstrdup(tmp);
		return home;
	}

	user = getpwuid(getuid());
	if (!user) {
		werror(_("could not get password entry for UID %i"), getuid());
		home = "/";
		return home;
	}

	if (!user->pw_dir)
		home = "/";
	else
		home = wstrdup(user->pw_dir);

	return home;
}

/*
 * Return the home directory for the specified used
 *
 * If user not found, returns NULL, otherwise always returns a path that is
 * statically stored.
 *
 * Please note you must use the path before any other call to 'getpw*' or it
 * may be erased. This is a design choice to avoid duplication considering
 * the use case for this function.
 */
static const char *getuserhomedir(const char *username)
{
	static const char default_home[] = "/";
	struct passwd *user;

	user = getpwnam(username);
	if (!user) {
		werror(_("could not get password entry for user %s"), username);
		return NULL;
	}
	if (!user->pw_dir)
		return default_home;
	else
		return user->pw_dir;

}

char *wexpandpath(const char *path)
{
	const char *origpath = path;
	char buffer2[PATH_MAX + 2];
	char buffer[PATH_MAX + 2];
	int i;

	memset(buffer, 0, PATH_MAX + 2);

	if (*path == '~') {
		const char *home;

		path++;
		if (*path == '/' || *path == 0) {
			home = wgethomedir();
			if (strlen(home) > PATH_MAX ||
			    wstrlcpy(buffer, home, sizeof(buffer)) >= sizeof(buffer))
				goto error;
		} else {
			int j;
			j = 0;
			while (*path != 0 && *path != '/') {
				if (j > PATH_MAX)
					goto error;
				buffer2[j++] = *path;
				buffer2[j] = 0;
				path++;
			}
			home = getuserhomedir(buffer2);
			if (!home || wstrlcat(buffer, home, sizeof(buffer)) >= sizeof(buffer))
				goto error;
		}
	}

	i = strlen(buffer);

	while (*path != 0 && i <= PATH_MAX) {
		char *tmp;

		if (*path == '$') {
			int j;

			path++;
			/* expand $(HOME) or $HOME style environment variables */
			if (*path == '(') {
				path++;
				j = 0;
				while (*path != 0 && *path != ')') {
					if (j > PATH_MAX)
						goto error;
					buffer2[j++] = *(path++);
				}
				buffer2[j] = 0;
				if (*path == ')') {
					path++;
					tmp = getenv(buffer2);
				} else {
					tmp = NULL;
				}
				if (!tmp) {
					if ((i += strlen(buffer2) + 2) > PATH_MAX)
						goto error;
					buffer[i] = 0;
					if (wstrlcat(buffer, "$(", sizeof(buffer)) >= sizeof(buffer) ||
					    wstrlcat(buffer, buffer2, sizeof(buffer)) >= sizeof(buffer))
						goto error;
					if (*(path-1)==')') {
						if (++i > PATH_MAX ||
						    wstrlcat(buffer, ")", sizeof(buffer)) >= sizeof(buffer))
							goto error;
					}
				} else {
					if ((i += strlen(tmp)) > PATH_MAX ||
					    wstrlcat(buffer, tmp, sizeof(buffer)) >= sizeof(buffer))
						goto error;
				}
			} else {
				j = 0;
				while (*path != 0 && *path != '/') {
					if (j > PATH_MAX)
						goto error;
					buffer2[j++] = *(path++);
				}
				buffer2[j] = 0;
				tmp = getenv(buffer2);
				if (!tmp) {
					if ((i += strlen(buffer2) + 1) > PATH_MAX ||
					    wstrlcat(buffer, "$", sizeof(buffer)) >= sizeof(buffer) ||
					    wstrlcat(buffer, buffer2, sizeof(buffer)) >= sizeof(buffer))
						goto error;
				} else {
					if ((i += strlen(tmp)) > PATH_MAX ||
					    wstrlcat(buffer, tmp, sizeof(buffer)) >= sizeof(buffer))
						goto error;
				}
			}
		} else {
			buffer[i++] = *path;
			path++;
		}
	}

	if (*path!=0)
		goto error;

	return wstrdup(buffer);

error:
	errno = ENAMETOOLONG;
	werror(_("could not expand %s"), origpath);

	return NULL;
}

/* return address of next char != tok or end of string whichever comes first */
static const char *skipchar(const char *string, char tok)
{
	while (*string != 0 && *string == tok)
		string++;

	return string;
}

/* return address of next char == tok or end of string whichever comes first */
static const char *nextchar(const char *string, char tok)
{
	while (*string != 0 && *string != tok)
		string++;

	return string;
}

/*
 *----------------------------------------------------------------------
 * findfile--
 * 	Finds a file in a : separated list of paths. ~ expansion is also
 * done.
 *
 * Returns:
 * 	The complete path for the file (in a newly allocated string) or
 * NULL if the file was not found.
 *
 * Side effects:
 * 	A new string is allocated. It must be freed later.
 *
 *----------------------------------------------------------------------
 */
char *wfindfile(const char *paths, const char *file)
{
	char *path;
	const char *tmp, *tmp2;
	int len, flen;
	char *fullpath;

	if (!file)
		return NULL;

	if (*file == '/' || *file == '~' || *file == '$' || !paths || *paths == 0) {
		if (access(file, F_OK) < 0) {
			fullpath = wexpandpath(file);
			if (!fullpath)
				return NULL;

			if (access(fullpath, F_OK) < 0) {
				wfree(fullpath);
				return NULL;
			} else {
				return fullpath;
			}
		} else {
			return wstrdup(file);
		}
	}

	flen = strlen(file);
	tmp = paths;
	while (*tmp) {
		tmp = skipchar(tmp, ':');
		if (*tmp == 0)
			break;
		tmp2 = nextchar(tmp, ':');
		len = tmp2 - tmp;
		path = wmalloc(len + flen + 2);
		path = memcpy(path, tmp, len);
		path[len] = 0;
		if (path[len - 1] != '/' &&
		    wstrlcat(path, "/", len + flen + 2) >= len + flen + 2) {
			wfree(path);
			return NULL;
		}

		if (wstrlcat(path, file, len + flen + 2) >= len + flen + 2) {
			wfree(path);
			return NULL;
		}

		fullpath = wexpandpath(path);
		wfree(path);

		if (fullpath) {
			if (access(fullpath, F_OK) == 0) {
				return fullpath;
			}
			wfree(fullpath);
		}
		tmp = tmp2;
	}

	return NULL;
}

char *wfindfileinlist(char *const *path_list, const char *file)
{
	int i;
	char *path;
	int len, flen;
	char *fullpath;

	if (!file)
		return NULL;

	if (*file == '/' || *file == '~' || !path_list) {
		if (access(file, F_OK) < 0) {
			fullpath = wexpandpath(file);
			if (!fullpath)
				return NULL;

			if (access(fullpath, F_OK) < 0) {
				wfree(fullpath);
				return NULL;
			} else {
				return fullpath;
			}
		} else {
			return wstrdup(file);
		}
	}

	flen = strlen(file);
	for (i = 0; path_list[i] != NULL; i++) {
		len = strlen(path_list[i]);
		path = wmalloc(len + flen + 2);
		path = memcpy(path, path_list[i], len);
		path[len] = 0;
		if (wstrlcat(path, "/", len + flen + 2) >= len + flen + 2 ||
		    wstrlcat(path, file, len + flen + 2) >= len + flen + 2) {
			wfree(path);
			return NULL;
		}
		/* expand tilde */
		fullpath = wexpandpath(path);
		wfree(path);
		if (fullpath) {
			/* check if file exists */
			if (access(fullpath, F_OK) == 0) {
				return fullpath;
			}
			wfree(fullpath);
		}
	}

	return NULL;
}

char *wfindfileinarray(WMPropList *array, const char *file)
{
	int i;
	char *path;
	int len, flen;
	char *fullpath;

	if (!file)
		return NULL;

	if (*file == '/' || *file == '~' || !array) {
		if (access(file, F_OK) < 0) {
			fullpath = wexpandpath(file);
			if (!fullpath)
				return NULL;

			if (access(fullpath, F_OK) < 0) {
				wfree(fullpath);
				return NULL;
			} else {
				return fullpath;
			}
		} else {
			return wstrdup(file);
		}
	}

	flen = strlen(file);
	for (i = 0; i < WMGetPropListItemCount(array); i++) {
		WMPropList *prop;
		char *p;

		prop = WMGetFromPLArray(array, i);
		if (!prop)
			continue;
		p = WMGetFromPLString(prop);

		len = strlen(p);
		path = wmalloc(len + flen + 2);
		path = memcpy(path, p, len);
		path[len] = 0;
		if (wstrlcat(path, "/", len + flen + 2) >= len + flen + 2 ||
		    wstrlcat(path, file, len + flen + 2) >= len + flen + 2) {
			wfree(path);
			return NULL;
		}
		/* expand tilde */
		fullpath = wexpandpath(path);
		wfree(path);
		if (fullpath) {
			/* check if file exists */
			if (access(fullpath, F_OK) == 0) {
				return fullpath;
			}
			wfree(fullpath);
		}
	}
	return NULL;
}

int wcopy_file(const char *dest_dir, const char *src_file, const char *dest_file)
{
	char *path_dst;
	int fd_src, fd_dst;
	struct stat stat_src;
	mode_t permission_dst;
	const size_t buffer_size = 2 * 1024 * 1024;	/* 4MB is a decent start choice to allow the OS to take advantage of modern disk's performance */
	char *buffer;	/* The buffer is not created on the stack to avoid possible stack overflow as our buffer is big */

 try_again_src:
	fd_src = open(src_file, O_RDONLY | O_NOFOLLOW);
	if (fd_src == -1) {
		if (errno == EINTR)
			goto try_again_src;
		werror(_("Could not open input file \"%s\": %s"), src_file, strerror(errno));
		return -1;
	}

	/* Only accept to copy regular files */
	if (fstat(fd_src, &stat_src) != 0 || !S_ISREG(stat_src.st_mode)) {
		close(fd_src);
		return -1;
	}

	path_dst = wstrconcat(dest_dir, dest_file);
 try_again_dst:
	fd_dst = open(path_dst, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
	if (fd_dst == -1) {
		if (errno == EINTR)
			goto try_again_dst;
		werror(_("Could not create target file \"%s\": %s"), path_dst, strerror(errno));
		wfree(path_dst);
		close(fd_src);
		return -1;
	}

	buffer = malloc(buffer_size);	/* Don't use wmalloc to avoid the memset(0) we don't need */
	if (buffer == NULL) {
		werror(_("could not allocate memory for the copy buffer"));
		close(fd_dst);
		goto cleanup_and_return_failure;
	}

	for (;;) {
		ssize_t size_data;
		const char *write_ptr;
		size_t write_remain;

	try_again_read:
		size_data = read(fd_src, buffer, buffer_size);
		if (size_data == 0)
			break; /* End of File have been reached */
		if (size_data < 0) {
			if (errno == EINTR)
				goto try_again_read;
			werror(_("could not read from file \"%s\": %s"), src_file, strerror(errno));
			close(fd_dst);
			goto cleanup_and_return_failure;
		}

		write_ptr = buffer;
		write_remain = size_data;
		while (write_remain > 0) {
			ssize_t write_done;

		try_again_write:
			write_done = write(fd_dst, write_ptr, write_remain);
			if (write_done < 0) {
				if (errno == EINTR)
					goto try_again_write;
				werror(_("could not write data to file \"%s\": %s"), path_dst, strerror(errno));
				close(fd_dst);
				goto cleanup_and_return_failure;
			}
			write_ptr    += write_done;
			write_remain -= write_done;
		}
	}

	/* Keep only the permission-related part of the field: */
	permission_dst = stat_src.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO | S_ISUID | S_ISGID | S_ISVTX);
	if (fchmod(fd_dst, permission_dst) != 0)
		wwarning(_("could not set permission 0%03o on file \"%s\": %s"),
		         permission_dst, path_dst, strerror(errno));

	if (close(fd_dst) != 0) {
		werror(_("could not close the file \"%s\": %s"), path_dst, strerror(errno));
	cleanup_and_return_failure:
		free(buffer);
		close(fd_src);
		unlink(path_dst);
		wfree(path_dst);
		return -1;
	}

	free(buffer);
	wfree(path_dst);
	close(fd_src);

	return 0;
}
