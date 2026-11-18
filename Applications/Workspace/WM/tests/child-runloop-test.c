/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "../child_events.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFFileDescriptor.h>
#include <assert.h>
#include <signal.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

static int delivered;
static volatile sig_atomic_t in_handler;
static void handler(int sig) {
  (void)sig;
  in_handler = 1;
  wReapChildProcesses();
  in_handler = 0;
}
static void received(pid_t pid, int status) {
  assert(!in_handler && pid > 1);
  assert(WIFEXITED(status) && WEXITSTATUS(status) == 37);
  if (++delivered == 16) CFRunLoopStop(CFRunLoopGetCurrent());
}
static void readable(CFFileDescriptorRef fd, CFOptionFlags flags, void *info) {
  (void)flags; (void)info;
  wChildEventsDrain(received);
  CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorReadCallBack);
}
int main(void) {
  int fd = wChildEventsInit();
  assert(fd >= 0);
  struct sigaction action = {0};
  action.sa_handler = handler;
  sigfillset(&action.sa_mask);
  action.sa_flags = SA_RESTART;
  assert(sigaction(SIGCHLD, &action, NULL) == 0);
  for (int i = 0; i < 16; ++i) {
    pid_t pid = fork();
    assert(pid >= 0);
    if (!pid) _exit(37);
    assert(wChildEventsRegister(pid));
  }
  /* Attach with pending bytes: this exercises the real descriptor wakeup. */
  CFFileDescriptorRef descriptor = CFFileDescriptorCreate(NULL, fd, false, readable, NULL);
  assert(descriptor);
  CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(NULL, descriptor, 0);
  assert(source);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
  CFFileDescriptorEnableCallBacks(descriptor, kCFFileDescriptorReadCallBack);
  wChildEventsWakeUp();
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false);
  assert(delivered == 16);
  CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
  CFFileDescriptorInvalidate(descriptor);
  CFRelease(source);
  CFRelease(descriptor);
  puts("PASS: 16 child exits delivered through the real CF descriptor run loop");
  return 0;
}
