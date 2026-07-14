/*
 * Check to see if we can read the psinfo struct
 */
/*
  Copyright (C) 2005 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.
*/
#include <stdio.h>
#include <procfs.h>
int main()
{
  char *proc_file_name = NULL;
  FILE *ifp;
  psinfo_t pinfo;
  char **vectors;
  int i, count;

  // Read commandline
  proc_file_name = (char*)malloc(sizeof(char) * 2048);
  sprintf(proc_file_name, "/proc/%d/psinfo", (int) getpid());

  ifp = fopen(proc_file_name, "r");
  if (ifp == NULL)
    {
      return 1;
    }

  fread(&pinfo, sizeof(pinfo), 1, ifp);
  fclose(ifp);
  return 0;
}
