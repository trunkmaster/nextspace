/* SPDX-License-Identifier: GPL-2.0-or-later
 * Owned-child collection with signal-safe wakeups and normal-context delivery.
 * A full wakeup pipe is harmless: completed records stay in their slots.
 */
#include "child_events.h"
#include <stdatomic.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>

_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "SIGCHLD requires lock-free integer atomics");
#define CHILD_SLOTS 128
static struct { atomic_int pid; atomic_int status; } children[CHILD_SLOTS];
/* pid: 0 free, -1 claimed, positive watched, negative completed. */
static int wakeup[2] = {-1, -1};

int wChildEventsInit(void)
{
  if (wakeup[0] >= 0) return wakeup[0];
  if (pipe(wakeup) < 0) return -1;
  for (int i = 0; i < 2; ++i) {
    if (fcntl(wakeup[i], F_SETFD, FD_CLOEXEC) < 0 ||
        fcntl(wakeup[i], F_SETFL, O_NONBLOCK) < 0) {
      int saved = errno;
      close(wakeup[0]); close(wakeup[1]);
      wakeup[0] = wakeup[1] = -1;
      errno = saved;
      return -1;
    }
  }
  return wakeup[0];
}

void wChildEventsWakeUp(void)
{
  int saved = errno;
  char byte = 1;
  ssize_t written;
  do { written = write(wakeup[1], &byte, 1); }
  while (written < 0 && errno == EINTR);
  errno = saved;
}

void wReapChildProcesses(void)
{
  int saved = errno;
  for (int i = 0; i < CHILD_SLOTS; ++i) {
    int pid = atomic_load(&children[i].pid);
    if (pid <= 1 || !atomic_compare_exchange_strong(&children[i].pid, &pid, -1))
      continue;
    int status;
    pid_t result;
    do { result = waitpid((pid_t)pid, &status, WNOHANG); }
    while (result < 0 && errno == EINTR);
    if (result == pid) {
      atomic_store(&children[i].status, status);
      atomic_store(&children[i].pid, -pid);
      wChildEventsWakeUp();
    } else {
      /* Foundation may already have collected a WM child. Its upstream
         process-existence fallback still handles that case. */
      atomic_store(&children[i].pid, result < 0 && errno == ECHILD ? 0 : pid);
    }
  }
  errno = saved;
}

int wChildEventsRegister(pid_t pid)
{
  if (pid <= 1 || wakeup[0] < 0) return 0;
  for (int i = 0; i < CHILD_SLOTS; ++i) {
    int empty = 0;
    if (atomic_compare_exchange_strong(&children[i].pid, &empty, (int)pid)) {
      /* Covers a child that exited before its parent registered it. */
      wReapChildProcesses();
      return 1;
    }
  }
  return 0;
}

void wChildEventsDrain(void (*callback)(pid_t, int))
{
  char bytes[128];
  ssize_t n;
  do { n = read(wakeup[0], bytes, sizeof bytes); }
  while (n > 0 || (n < 0 && errno == EINTR));
  for (int i = 0; i < CHILD_SLOTS; ++i) {
    int pid = atomic_load(&children[i].pid);
    if (pid >= -1 || !atomic_compare_exchange_strong(&children[i].pid, &pid, -1))
      continue;
    int status = atomic_load(&children[i].status);
    atomic_store(&children[i].pid, 0);
    callback((pid_t)-pid, status);
  }
}
