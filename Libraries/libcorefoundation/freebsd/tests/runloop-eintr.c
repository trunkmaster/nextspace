/* FreeBSD: interrupt a real CFRunLoop wait, then verify source delivery. */
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <signal.h>
#include <semaphore.h>
#include <stdio.h>
#include <time.h>
#include <errno.h>

static sem_t ready;
static CFRunLoopRef loop;
static CFRunLoopSourceRef source;
static volatile sig_atomic_t signals;
static int delivered;
static SInt32 result;

static void interrupt_wait(int signal_number) {
    (void)signal_number;
    signals++;
}

static void deliver(void *context) {
    (void)context;
    delivered++;
}

static void *run_loop(void *context) {
    (void)context;
    CFRunLoopSourceContext source_context = {0};
    source_context.perform = deliver;
    loop = CFRunLoopGetCurrent();
    source = CFRunLoopSourceCreate(NULL, 0, &source_context);
    CFRunLoopAddSource(loop, source, kCFRunLoopDefaultMode);
    sem_post(&ready);
    result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5.0, true);
    CFRunLoopRemoveSource(loop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    return NULL;
}

int main(void) {
    struct sigaction action = {0};
    action.sa_handler = interrupt_wait;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGUSR1, &action, NULL) || sem_init(&ready, 0, 0)) return 2;
    pthread_t worker;
    if (pthread_create(&worker, NULL, run_loop, NULL)) return 2;
    while (sem_wait(&ready)) if (errno != EINTR) return 2;
    struct timespec pause = {.tv_sec = 0, .tv_nsec = 10000000};
    /* Repeated targeted signals exercise the blocking wait, not just startup. */
    for (int i = 0; i < 25; i++) {
        nanosleep(&pause, NULL);
        if (pthread_kill(worker, SIGUSR1)) return 2;
    }
    CFRunLoopSourceSignal(source);
    CFRunLoopWakeUp(loop);
    if (pthread_join(worker, NULL)) return 2;
    sem_destroy(&ready);
    printf("CFRunLoop: signals=%d callbacks=%d result=%d\n",
           (int)signals, delivered, (int)result);
    return signals > 0 && delivered == 1 &&
           result == kCFRunLoopRunHandledSource ? 0 : 1;
}
