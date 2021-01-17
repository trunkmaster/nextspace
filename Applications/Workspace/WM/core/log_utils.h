#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFLogUtilities.h>

#include "config.h"

#ifdef HAVE_SYSLOG_H
#include <syslog.h>
void wSyslogClose(void);
#endif

void wShowMessage(const char *func, const char *file, int line, int type, CFStringRef fmt, ...) __attribute__((format(CFString,5,6)));

#define wmessage(fmt, args...) wShowMessage( __func__, __FILE__, __LINE__, kCFLogLevelInfo, CFSTR(fmt), ## args)
#define wwarning(fmt, args...) wShowMessage( __func__, __FILE__, __LINE__, kCFLogLevelWarning, CFSTR(fmt), ## args)
#define werror(fmt, args...) wShowMessage( __func__, __FILE__, __LINE__, kCFLogLevelError, CFSTR(fmt), ## args)
#define wfatal(fmt, args...) wShowMessage( __func__, __FILE__, __LINE__, kCFLogLevelCritical, CFSTR(fmt), ## args)
