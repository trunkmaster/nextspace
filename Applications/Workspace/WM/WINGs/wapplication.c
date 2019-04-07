
#include <unistd.h>
#include <X11/Xlocale.h>

#include "WINGsP.h"
#include "wconfig.h"
#include "userdefaults.h"


struct W_Application WMApplication;

char *_WINGS_progname = NULL;

Bool W_ApplicationInitialized(void)
{
	return _WINGS_progname != NULL;
}

void WMInitializeApplication(const char *applicationName, int *argc, char **argv)
{
	int i;

	assert(argc != NULL);
	assert(argv != NULL);
	assert(applicationName != NULL);

	setlocale(LC_ALL, "");

#ifdef I18N
	if (getenv("NLSPATH"))
		bindtextdomain("WINGs", getenv("NLSPATH"));
	else
		bindtextdomain("WINGs", LOCALEDIR);
	bind_textdomain_codeset("WINGs", "UTF-8");
#endif

	_WINGS_progname = argv[0];

	WMApplication.applicationName = wstrdup(applicationName);
	WMApplication.argc = *argc;

	WMApplication.argv = wmalloc((*argc + 1) * sizeof(char *));
	for (i = 0; i < *argc; i++) {
		WMApplication.argv[i] = wstrdup(argv[i]);
	}
	WMApplication.argv[i] = NULL;

	/* initialize notification center */
	W_InitNotificationCenter();
}

void WMReleaseApplication(void) {
	int i;

	/*
	 * We save the configuration on exit, this used to be handled
	 * through an 'atexit' registered function but if application
	 * properly calls WMReleaseApplication then the info to that
	 * will have been freed by us.
	 */
	w_save_defaults_changes();

	W_ReleaseNotificationCenter();

	if (WMApplication.applicationName) {
		wfree(WMApplication.applicationName);
		WMApplication.applicationName = NULL;
	}

	if (WMApplication.argv) {
		for (i = 0; i < WMApplication.argc; i++)
			wfree(WMApplication.argv[i]);

		wfree(WMApplication.argv);
		WMApplication.argv = NULL;
	}
}

void WMSetResourcePath(const char *path)
{
	if (WMApplication.resourcePath)
		wfree(WMApplication.resourcePath);
	WMApplication.resourcePath = wstrdup(path);
}

char *WMGetApplicationName()
{
	return WMApplication.applicationName;
}

static char *checkFile(const char *path, const char *folder, const char *ext, const char *resource)
{
	char *ret;
	int extralen;
	size_t slen;

	if (!path || !resource)
		return NULL;

	extralen = (ext ? strlen(ext) + 1 : 0) + (folder ? strlen(folder) + 1 : 0) + 1;
	slen = strlen(path) + strlen(resource) + 1 + extralen;
	ret = wmalloc(slen);

	if (wstrlcpy(ret, path, slen) >= slen)
		goto error;

	if (folder &&
		(wstrlcat(ret, "/", slen) >= slen ||
		 wstrlcat(ret, folder, slen) >= slen))
			goto error;

	if (ext &&
		(wstrlcat(ret, "/", slen) >= slen ||
		 wstrlcat(ret, ext, slen) >= slen))
			goto error;

	if (wstrlcat(ret, "/", slen) >= slen ||
	    wstrlcat(ret, resource, slen) >= slen)
		goto error;

	if (access(ret, F_OK) != 0)
		goto error;

	return ret;

error:
	if (ret)
		wfree(ret);
	return NULL;
}

char *WMPathForResourceOfType(const char *resource, const char *ext)
{
	char *path, *appdir;
	size_t slen;

	path = appdir = NULL;

	/*
	 * Paths are searched in this order:
	 * - resourcePath/ext
	 * - dirname(argv[0])/ext
	 * - GNUSTEP_USER_ROOT/Applications/ApplicationName.app/ext
	 * - ~/GNUstep/Applications/ApplicationName.app/ext
	 * - GNUSTEP_LOCAL_ROOT/Applications/ApplicationName.app/ext
	 * - /usr/local/GNUstep/Applications/ApplicationName.app/ext
	 * - GNUSTEP_SYSTEM_ROOT/Applications/ApplicationName.app/ext
	 * - /usr/GNUstep/Applications/ApplicationName.app/ext
	 */

	if (WMApplication.resourcePath) {
		path = checkFile(WMApplication.resourcePath, NULL, ext, resource);
		if (path)
			goto out;
	}

	if (WMApplication.argv[0]) {
		char *ptr_slash;

		ptr_slash = strrchr(WMApplication.argv[0], '/');
		if (ptr_slash != NULL) {
			char tmp[ptr_slash - WMApplication.argv[0] + 1];

			strncpy(tmp, WMApplication.argv[0], sizeof(tmp)-1);
			tmp[sizeof(tmp) - 1] = '\0';

			path = checkFile(tmp, NULL, ext, resource);
			if (path)
				goto out;
		}
	}

	slen = strlen(WMApplication.applicationName) + sizeof("Applications/.app");
	appdir = wmalloc(slen);
	if (snprintf(appdir, slen, "Applications/%s.app", WMApplication.applicationName) >= slen)
		goto out;

	path = checkFile(getenv("GNUSTEP_USER_ROOT"), appdir, ext, resource);
	if (path)
		goto out;

	path = checkFile(wusergnusteppath(), appdir, ext, resource);
	if (path)
		goto out;

	path = checkFile(getenv("GNUSTEP_LOCAL_ROOT"), appdir, ext, resource);
	if (path)
		goto out;

	path = checkFile("/usr/local/GNUstep", appdir, ext, resource);
	if (path)
		goto out;

	path = checkFile(getenv("GNUSTEP_SYSTEM_ROOT"), appdir, ext, resource);
	if (path)
		goto out;

	path = checkFile("/usr/GNUstep", appdir, ext, resource); /* falls through */

out:
	if (appdir)
		wfree(appdir);

	return path;

}
