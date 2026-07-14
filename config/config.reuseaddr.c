/*
  Copyright (C) 2005 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.
*/
#if defined(__MINGW32__) || defined(__MINGW64__)
#include <winsock2.h>
#include <windows.h>
#else
#include <time.h>
#include <sys/time.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#endif /* __MINGW__ */

#include <sys/file.h>
#include <sys/stat.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>

#ifndef	INADDR_NONE
#define	INADDR_NONE	-1
#endif

// Maximum data in single I/O operation
#define	NETBUF_SIZE	4096

int main()
{
  struct sockaddr_in	sin;
  int	size = sizeof(sin);
  int	status = 1;
  int	port;
  int	net;

  memset(&sin, '\0', sizeof(sin));
  sin.sin_family = AF_INET;
  sin.sin_addr.s_addr = htonl(INADDR_ANY);
  sin.sin_port = 0;

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) < 0)
    {
      fprintf(stderr, "unable to create socket 1\n");
      return 2;
    }

  if (setsockopt(net, SOL_SOCKET, SO_REUSEADDR,
    (char *)&status, sizeof(status)) < 0)
    {
      fprintf(stderr, "unable to set socket 1 option\n");
      (void) close(net);
      return 1;
    }

  if (bind(net, (struct sockaddr *)&sin, sizeof(sin)) < 0)
    {
      fprintf(stderr, "unable to bind socket 1\n");
      (void) close(net);
      return 2;
    }

  listen(net, 5);

  if (getsockname(net, (struct sockaddr*)&sin, &size) < 0)
    {
      fprintf(stderr, "unable to get socket 1 name\n");
      (void) close(net);
      return 2;
    }

  port = sin.sin_port;
  memset(&sin, '\0', sizeof(sin));
  sin.sin_family = AF_INET;
  sin.sin_addr.s_addr = htonl(INADDR_ANY);
  sin.sin_port = port;

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) < 0)
    {
      fprintf(stderr, "unable to create socket 2\n");
      return 2;
    }

  if (setsockopt(net, SOL_SOCKET, SO_REUSEADDR,
    (char *)&status, sizeof(status)) < 0)
    {
      fprintf(stderr, "unable to set socket 2 option\n");
      (void) close(net);
      return 1;
    }

  /*
   * Now ... this bind should fail unless SO_REUSEADDR is broken.
   */
  if (bind(net, (struct sockaddr *)&sin, sizeof(sin)) < 0)
    {
      return 0;
    }
  return 1;
}

