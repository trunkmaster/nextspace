/* FreeBSD: an absolute kqueue timer must be consumed once, not stay readable. */
#include <sys/types.h>
#include <sys/event.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

static int deliveries(unsigned short flags)
{
  int fd = kqueue();
  assert(fd >= 0);
  struct timespec now;
  assert(clock_gettime(CLOCK_MONOTONIC, &now) == 0);
  int64_t deadline = (int64_t)now.tv_sec * 1000000000 + now.tv_nsec + 20000000;
  struct kevent change, event;
  EV_SET(&change, 0, EVFILT_TIMER, EV_ADD | flags,
         NOTE_NSECONDS | NOTE_ABSTIME, deadline, NULL);
  assert(kevent(fd, &change, 1, NULL, 0, NULL) == 0);
  struct timespec wait = {1, 0}, poll = {0, 0};
  int count = kevent(fd, NULL, 0, &event, 1, &wait);
  assert(count == 1);
  for (int i = 0; i < 63; ++i) {
    int result = kevent(fd, NULL, 0, &event, 1, &poll);
    assert(result >= 0);
    count += result;
  }
  close(fd);
  return count;
}

int main(void)
{
  int original = deliveries(0);
  int fixed = deliveries(EV_ONESHOT);
  printf("absolute timer deliveries: EV_ADD=%d EV_ADD|EV_ONESHOT=%d\n", original, fixed);
  return fixed == 1 ? 0 : 1;
}
