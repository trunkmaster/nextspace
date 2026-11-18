/* A completed CF one-shot timer must not keep a nonempty run loop spinning. */
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <time.h>

static int fired, repeating_fired, wakeups;
static void timer_fired(CFRunLoopTimerRef timer, void *info)
{ (void)timer; (void)info; ++fired; }
static void repeating_timer(CFRunLoopTimerRef timer, void *info)
{
  (void)info;
  if (++repeating_fired == 3) CFRunLoopTimerInvalidate(timer);
}
static void keep_alive(void *info) { (void)info; }
static void after_wait(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{ (void)observer; (void)activity; (void)info; ++wakeups; }

static double cpu_time(void)
{
  struct timespec now;
  clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &now);
  return now.tv_sec + now.tv_nsec / 1e9;
}

int main(void)
{
  CFRunLoopRef loop = CFRunLoopGetCurrent();
  CFRunLoopSourceContext context = {0};
  context.perform = keep_alive;
  CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &context);
  CFRunLoopAddSource(loop, source, kCFRunLoopDefaultMode);
  CFRunLoopObserverRef observer = CFRunLoopObserverCreate(NULL, kCFRunLoopAfterWaiting,
      true, 0, after_wait, NULL);
  CFRunLoopAddObserver(loop, observer, kCFRunLoopDefaultMode);
  CFRunLoopTimerRef timer = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent() + 0.03,
      0, 0, 0, timer_fired, NULL);
  CFRunLoopAddTimer(loop, timer, kCFRunLoopDefaultMode);
  CFRunLoopTimerRef repeating = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent() + 0.01,
      0.025, 0, 0, repeating_timer, NULL);
  CFRunLoopAddTimer(loop, repeating, kCFRunLoopDefaultMode);
  double before = cpu_time();
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
  double used = cpu_time() - before;
  printf("CF timers: one_shot=%d repeating=%d wakeups=%d cpu_seconds=%.6f\n",
         fired, repeating_fired, wakeups, used);
  CFRunLoopRemoveObserver(loop, observer, kCFRunLoopDefaultMode);
  CFRunLoopRemoveSource(loop, source, kCFRunLoopDefaultMode);
  CFRelease(timer); CFRelease(repeating); CFRelease(observer); CFRelease(source);
  return fired == 1 && repeating_fired == 3 && wakeups < 50 ? 0 : 1;
}
