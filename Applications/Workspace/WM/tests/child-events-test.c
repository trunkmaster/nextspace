/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "../child_events.h"
#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static int count, failures, signals;
static volatile sig_atomic_t in_handler;
static void handler(int sig)
{
  (void)sig;
  in_handler = 1;
  wReapChildProcesses();
  in_handler = 0;
}
static void received(pid_t pid, int status)
{
  assert(!in_handler);
  assert(pid > 1);
  ++count;
  if (WIFEXITED(status) && WEXITSTATUS(status) == 37) ++failures;
  if (WIFSIGNALED(status) && WTERMSIG(status) == SIGTERM) ++signals;
}
int main(void)
{
  assert(wChildEventsInit() >= 0);
  struct sigaction action = {0};
  action.sa_handler = handler;
  sigfillset(&action.sa_mask);
  action.sa_flags = SA_RESTART;
  assert(sigaction(SIGCHLD, &action, NULL) == 0);
  /* An unregistered (Foundation-owned) child must remain waitable. */
  pid_t foreign = fork();
  assert(foreign >= 0);
  if (!foreign) _exit(19);
  for (int i = 0; i < 48; ++i) {
    pid_t pid = fork();
    assert(pid >= 0);
    if (!pid) {
      if (i == 47) { raise(SIGTERM); _exit(99); }
      _exit(i == 0 ? 37 : 0);
    }
    assert(wChildEventsRegister(pid));
  }
  struct timespec pause = {0, 1000000};
  for (int i = 0; count < 48 && i < 10000; ++i) {
    nanosleep(&pause, NULL);
    wReapChildProcesses();
    wChildEventsDrain(received);
  }
  assert(count == 48 && failures == 1 && signals == 1);
  int status;
  pid_t result;
  do { result = waitpid(foreign, &status, 0); } while (result < 0 && errno == EINTR);
  assert(result == foreign && WIFEXITED(status) && WEXITSTATUS(status) == 19);
  puts("PASS: 48 WM exits, raw failure/signal statuses, deferred callbacks, foreign child preserved");
  return 0;
}
