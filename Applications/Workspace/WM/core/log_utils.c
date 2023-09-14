
#include <string.h>

#include <WM.h>
#include "log_utils.h"

/* ---[ logging ]-------------------------------------------------------------*/
#ifdef HAVE_SYSLOG_H
static Bool syslog_initialized = False;

static void _syslogOpen(const char *prog_name)
{
  int options;

  if (!prog_name)
    prog_name = "Workspace";

  options = LOG_PID;
  openlog(prog_name, options, LOG_DAEMON);
  syslog_initialized = True;
}

static void _syslogSendMessage(int type, const char *prog_name, const char *msg)
{
  int syslog_priority;

  if (!syslog_initialized) {
    _syslogOpen(prog_name);
  }

  switch (type) {
    case kCFLogLevelCritical:
      syslog_priority = LOG_CRIT;
      break;
    case kCFLogLevelError:
      syslog_priority = LOG_ERR;
      break;
    case kCFLogLevelWarning:
      syslog_priority = LOG_WARNING;
      break;
    case kCFLogLevelInfo:
    default:
      syslog_priority = LOG_INFO;
      break;
  }

  // jump over the program name cause syslog is already displaying it
  syslog(syslog_priority, "%s", msg);
}

void WMSyslogClose(void)
{
  if (syslog_initialized) {
    closelog();
    syslog_initialized = False;
  }
}
#endif

void WMLog(const char *func, const char *file, int line, int type, CFStringRef fmt, ...)
{
  (void)func;  // temporary unused var - silence compiler warning
  va_list args;
  CFStringRef user_msg, message;

  va_start(args, fmt);
  user_msg = CFStringCreateWithFormatAndArguments(kCFAllocatorDefault, 0, fmt, args);
  va_end(args);

  message = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("[%s:%i] %@"), file ? file : "",
                                     line, user_msg);

#ifdef HAVE_SYSLOG
  _syslogSendMessage(type, "Workspace", CFStringGetCStringPtr(message, kCFStringEncodingUTF8));
#else
  CFLog(kCFLogLevelError, message);
#endif

  CFRelease(user_msg);
  CFRelease(message);
}