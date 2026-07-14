/*
 * Check to see if the final cmdline arg recorded in the /proc filesystem
 * is terminated by a nul.
 */
/*
  Copyright (C) 2005 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.
*/
#include <stdio.h>
#include <unistd.h>

int main()
{
  char	buf[32];
  FILE	*fptr;
  int	result = 1;
  int	c;

  sprintf(buf, "/proc/%d/cmdline", getpid());
  fptr = fopen(buf, "r");
  if (fptr != 0)
    {
      while ((c = fgetc(fptr)) != EOF)
	{
	  result = c;
	}
      fclose(fptr);
    }
  if (result != 0)
    {
      result = 1;
    }
  return result;
}
