/* Mac OS X has a native poll implementation since Mac OS X 10.4, but
 * this implementation is broken in (at least) OS X 10.4 and 10.5 in
 * that it does not support devices.
 */

#include <stdio.h>
#include <fcntl.h>
#include <poll.h>
#include <unistd.h>

int
main()
{
  int fd, n;
  struct pollfd pollfds[1];

  fd = open("/dev/null", O_RDONLY | O_NONBLOCK, 0);

  pollfds[0].fd = fd;
  pollfds[0].events = POLLIN;
  n = poll(pollfds, 1, 0);
  close(fd);

  return (n == 1 && !(pollfds[0].revents & POLLNVAL)) ? 0 : 1;
}
