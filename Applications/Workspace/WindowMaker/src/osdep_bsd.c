/*
 * Until FreeBSD gets their act together;
 * http://www.mail-archive.com/freebsd-hackers@freebsd.org/msg69469.html
 */
#if defined( FREEBSD )
#   undef _XOPEN_SOURCE
#endif

#if defined( FREEBSD ) || defined( DRAGONFLYBSD )
#   include <sys/types.h>
#else /* OPENBSD || NETBSD */
#   include <sys/param.h>
#endif
#include <sys/sysctl.h>

#include <assert.h>

#if defined( OPENBSD )
#   include <kvm.h>
#   include <limits.h>	/* _POSIX2_LINE_MAX */
#endif

#include <stdio.h>
#include <stdlib.h>

#if defined( OPENBSD )
#   include <string.h>
#endif

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
/*
 * NetBSD, FreeBSD and DragonFlyBSD supply the necessary information via
 * sysctl(3). The result is a plain simple flat octet stream and its length.
 * The octet stream represents argv, with members separated by a null character.
 * The argv array returned by GetCommandForPid() consists of pointers into this
 * stream (which is stored in a static array, `args'). Net and Free/DFly only
 * differ slightly in the MIB vector given to sysctl(3). Free and DFly are
 * identical.
 *
 * OpenBSD supplies the necessary informationvia kvm(3) in the form of a real
 * argv array. This array is flattened to be in the same way as Net/Free/DFly
 * returns the arguments in the first place. This is done in order for the
 * storage (`args') to easily be made static, which means some memory bytes
 * are sacrificed to save hoops of memory management.
 */
Bool GetCommandForPid(int pid, char ***argv, int *argc)
{
	/*
	 * it just returns failure if the sysctl calls fail; since there's
	 * apparently no harm done to the caller because of this, it seems
	 * more user-friendly than to bomb out.
	 */
	int j, mib[4];
	unsigned int i;
	size_t count;
	static char *args = NULL;
	static int argmax = 0;
#if defined( OPENBSD )
	char kvmerr[_POSIX2_LINE_MAX];	/* for kvm*() error reporting */
	int procs;			/* kvm_getprocs() */
	kvm_t *kd;
	struct kinfo_proc *kp;
	char **nargv;			/* kvm_getarg() */
#endif

	*argv = NULL;
	*argc = 0;

	/* the system-wide limit */
	if (argmax == 0) { /* it hopefully doesn't change at runtime *g* */
		mib[0] = CTL_KERN;
		mib[1] = KERN_ARGMAX;
		mib[2] = 0;
		mib[3] = 0;

		count = sizeof(argmax);
		if (sysctl(mib, 2, &argmax, &count, NULL, 0) == -1)
			return False;
	}

	/* if argmax is still 0, something went very seriously wrong */
	assert( argmax > 0);

	/* space for args; no need to free before returning even on errors */
	if (args == NULL)
		args = (char *)wmalloc(argmax);

#if defined( OPENBSD )
	/* kvm descriptor */
	kd = kvm_openfiles(NULL, NULL, NULL, KVM_NO_FILES, kvmerr);
	if (kd == NULL)
		return False;

	procs = 0;
	/* the process we are interested in */
	kp = kvm_getprocs(kd, KERN_PROC_PID, pid, sizeof(*kp), &procs);
	if (kp == NULL || procs == 0)
		/* if kvm_getprocs() bombs out or does not find the process */
		return False;

	/* get its argv */
	nargv = kvm_getargv(kd, kp, 0);
	if (nargv == NULL)
		return False;

	/* flatten nargv into args */
	count = 0;
	memset(args, 0, argmax);
	/*
	 * must have this much free space in `args' in order for the current
	 * iteration not to overflow it: we are at `count', and will append
	 * the next (*argc) arg and a nul (+1)
	 * technically, overflow (or truncation, which isn't handled) can not
	 * happen (should not, at least).
	 */
	#define ARGSPACE ( count + strlen(nargv[ (*argc) ] ) + 1 )
	while (nargv[*argc] && ARGSPACE < argmax ) {
		memcpy(args + count, nargv[*argc], strlen(nargv[*argc]));
		count += strlen(nargv[*argc]) + 1;
		(*argc)++;
	}
	#undef ARGSPACE
	/* by now *argc is correct as a byproduct */

	kvm_close(kd);
#else /* FREEBSD || NETBSD || DRAGONFLYBSD */

	mib[0] = CTL_KERN;
#if defined( NETBSD )
	mib[1] = KERN_PROC_ARGS;
	mib[2] = pid;
	mib[3] = KERN_PROC_ARGV;
#elif defined( FREEBSD ) || defined( DRAGONFLYBSD )
	mib[1] = KERN_PROC;
	mib[2] = KERN_PROC_ARGS;
	mib[3] = pid;
#endif

	count = argmax;
	/* canary */
	*args = 0;
	if (sysctl(mib, 4, args, &count, NULL, 0) == -1 || *args == 0)
		return False;

	/* args is a flattened series of null-terminated strings */
	for (i = 0; i < count; i++)
		if (args[i] == '\0')
			(*argc)++;
#endif

	*argv = (char **)wmalloc(sizeof(char *) * (*argc + 1 /* term. null ptr */));
	(*argv)[0] = args;

	/* go through args, set argv[$next] to the beginning of each string */
	for (i = 0, j = 1; i < count; i++) {
		if (args[i] != '\0')
			continue;
		if (i < count - 1)
			(*argv)[j++] = &args[i + 1];
		if (j == *argc)
			break;
	}

	/* the list of arguments must be terminated by a null pointer */
	(*argv)[j] = NULL;
	return True;
}
