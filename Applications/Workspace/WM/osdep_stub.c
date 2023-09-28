
#include <sys/utsname.h>

#include <core/WMcore.h>
#include <core/log_utils.h>

#include "WM.h"
#include "osdep.h"

Bool GetCommandForPid(int pid, char ***argv, int *argc)
{
  static int notified = 0;

  if (!notified) {
    struct utsname un;

    /* The comment below is placed in the PO file by xgettext to help translator */
    if (uname(&un) != -1) {
      /*
       *  1st %s is a function name
       *  2nd %s is an email address
       *  3rd %s is the name of the operating system
       */
      WMLogWarning(_("%s is not implemented on this platform; "), __FUNCTION__);
      notified = 1;
    }
  }

  *argv = NULL;
  *argc = 0;

  return False;
}
