/* Exit with status 0 if vsprintf returns the length of the string printed.
   Some systems return a pointer to the string instead. */ 
/*
  Copyright (C) 2005 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.
*/
#include <stdio.h>
#include <stdarg.h>

static int func(const char *fmt, ...)
{
  va_list ap;
  char buf[128];
  int result;

  va_start(ap, fmt);
  result = vsprintf(buf, fmt, ap);
  va_end(ap);
  return result;
}

int main()
{
  if (func("1234", 0) == 4)
    return 0;
  return -1;
}
