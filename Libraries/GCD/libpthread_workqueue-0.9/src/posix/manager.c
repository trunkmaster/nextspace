/*-
 * Copyright (c) 2011, Joakim Johansson <jocke@tbricks.com>
 * Copyright (c) 2010, Mark Heily <mark@heily.com>
 * Copyright (c) 2009, Stacey Son <sson@freebsd.org>
 * Copyright (c) 2000-2008, Apple Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include "platform.h"
#include "private.h"
#include "pthread_workqueue.h"
#include "thread_info.h"
#include "thread_rt.h"

#include <sys/time.h>
#include <semaphore.h>

/* Environment setting */
unsigned int PWQ_RT_THREADS = 0;
unsigned int PWQ_SPIN_THREADS = 0; // The number of threads that should be kept spinning
unsigned volatile int current_threads_spinning = 0; // The number of threads currently spinning

/* Tunable constants */

#define WORKER_IDLE_SECONDS_THRESHOLD 15

/* Function prototypes */
static unsigned int get_runqueue_length(void);
static void * worker_main(void *arg);
static void * overcommit_worker_main(void *arg);
static unsigned int get_process_limit(void);
static void manager_start(void);

static unsigned int      cpu_count;
static unsigned int      worker_min;
static unsigned int      worker_idle_threshold; // we don't go down below this if we had to increase # workers
static unsigned int      pending_thread_create;

/* Overcommit */
static struct _pthread_workqueue *ocwq[PTHREAD_WORKQUEUE_MAX];
static int               ocwq_mask;
static pthread_mutex_t   ocwq_mtx;
static pthread_cond_t    ocwq_has_work;
static unsigned int      ocwq_idle_threads;
static unsigned int      ocwq_signal_count;     // number of times OCWQ condition was signalled

/* Non-overcommit */
static struct _pthread_workqueue *wqlist[PTHREAD_WORKQUEUE_MAX];
static volatile unsigned int     wqlist_mask; // mask of currently pending workqueues, atomics used for manipulation
static pthread_mutex_t   wqlist_mtx;

static pthread_cond_t    wqlist_has_work;
static int               wqlist_has_manager;
static pthread_attr_t    detached_attr;

static struct {
    volatile unsigned int runqueue_length,
                    count,
                    idle;
    sem_t sb_sem;
    unsigned int sb_suspend;
} scoreboard;

/* Thread limits */
#define DEFAULT_PROCESS_LIMIT 100

#if defined(__sun)
#include <rctl.h>

#define MIN_PROCESS_LIMIT 4
#define MAX_PROCESS_LIMIT 1000
#define THREADS_RESERVED  5 // arbitrary extra thread reservation
#endif

static unsigned int 
worker_idle_threshold_per_cpu(void)
{
    switch (cpu_count)
    {
        case 0:
        case 1:
        case 2:
        case 4:
          return 2;
        case 6:
          return 4;
        case 8:
        case 12:
          return 6;
        case 16:
        case 24:
          return 8;
        case 32:
        case 64:
          return 12;
        default:
            return cpu_count / 4;
    }
    
    return 2;
}

#if !defined(__ANDROID__)
static void
manager_reinit(void)
{
    if (manager_init() < 0)
        abort();
}
#endif

int
manager_init(void)
{
    wqlist_has_manager = 0;
    pthread_cond_init(&wqlist_has_work, NULL);

    pthread_mutex_init(&wqlist_mtx, NULL);
    wqlist_mask = 0;
    pending_thread_create = 0;
    
    pthread_cond_init(&ocwq_has_work, NULL);
    pthread_mutex_init(&ocwq_mtx, NULL);
    ocwq_mask = 0;
    ocwq_idle_threads = 0;
    ocwq_signal_count = 0;

    witem_cache_init();

    cpu_count = (PWQ_ACTIVE_CPU > 0) ? (PWQ_ACTIVE_CPU) : (unsigned int) sysconf(_SC_NPROCESSORS_ONLN);

    pthread_attr_init(&detached_attr);
    pthread_attr_setdetachstate(&detached_attr, PTHREAD_CREATE_DETACHED);

    /* Initialize the scoreboard */
    
    if (sem_init(&scoreboard.sb_sem, 0, 0) != 0) {
        dbg_perror("sem_init()");
        return (-1);
    }
    
    scoreboard.count = 0;
    scoreboard.idle = 0;
    scoreboard.sb_suspend = 0;
    
    /* Determine the initial thread pool constraints */
    worker_min = 2; // we can start with a small amount, worker_idle_threshold will be used as new dynamic low watermark
    worker_idle_threshold = (PWQ_ACTIVE_CPU > 0) ? (PWQ_ACTIVE_CPU) : worker_idle_threshold_per_cpu();

/* FIXME: should test for symbol instead of for Android */
#if !defined(__ANDROID__)
    if (pthread_atfork(NULL, NULL, manager_reinit) < 0) {
        dbg_perror("pthread_atfork()");
        return (-1);
    }
#endif

    return (0);
}

/* FIXME: should test for symbol instead of for Android */
#if defined(__ANDROID__)

#include <fcntl.h>

int getloadavg(double loadavg[], int nelem)
{
   int fd;
   ssize_t len;
   char buf[80];

   /* FIXME: this restriction allows the code to be simpler */
   if (nelem != 1)
       return (-1);

   fd = open("/proc/loadavg", O_RDONLY);
   if (fd < 0) 
       return (-1); 

   len = read(fd, &buf, sizeof(buf));
   (void) close(fd);
   if (len < 0) 
       return (-1);

   if (sscanf(buf, "%lf ", &loadavg[0]) < 1)
       return (-1);

   return (0); 
}
#endif /* defined(__ANDROID__) */

void
manager_workqueue_create(struct _pthread_workqueue *workq)
{
    pthread_mutex_lock(&wqlist_mtx);
    if (!workq->overcommit && !wqlist_has_manager)
        manager_start();

    if (workq->overcommit) {
        if (ocwq[workq->queueprio] == NULL) {
            ocwq[workq->queueprio] = workq;
            workq->wqlist_index = workq->queueprio;
            dbg_printf("created workqueue (ocommit=1, prio=%d)", workq->queueprio);
        } else {
            printf("oc queue %d already exists\n", workq->queueprio);
            abort();
        }
    } else {
        if (wqlist[workq->queueprio] == NULL) {
            wqlist[workq->queueprio] = workq; //FIXME: sort by priority
            workq->wqlist_index = workq->queueprio;
            dbg_printf("created workqueue (ocommit=0, prio=%d)", workq->queueprio);
        } else {
            printf("queue %d already exists\n", workq->queueprio);
            abort();
        }
    }
    pthread_mutex_unlock(&wqlist_mtx);
}

static void *
overcommit_worker_main(void *unused __attribute__ ((unused)))
{
    struct timespec ts;
    pthread_workqueue_t workq;
    void (*func)(void *);
    void *func_arg;
    struct work *witem;
    int rv, idx;
    sigset_t sigmask;

    /* Block all signals */
    sigfillset(&sigmask);
    pthread_sigmask(SIG_BLOCK, &sigmask, NULL);
     
    pthread_mutex_lock(&ocwq_mtx);

    for (;;) {
        /* Find the highest priority workqueue that is non-empty */
        idx = ffs(ocwq_mask);
        if (idx > 0) {
            workq = ocwq[idx - 1];
            witem = STAILQ_FIRST(&workq->item_listhead);
            if (witem != NULL) {
                /* Remove the first work item */
                STAILQ_REMOVE_HEAD(&workq->item_listhead, item_entry);
                if (STAILQ_EMPTY(&workq->item_listhead))
                    ocwq_mask &= ~(0x1 << workq->wqlist_index);
                /* Execute the work item */
                pthread_mutex_unlock(&ocwq_mtx);
                func = witem->func;
                func_arg = witem->func_arg;
                witem_free(witem);
                func(func_arg);    
                pthread_mutex_lock(&ocwq_mtx);
                continue;
            }
        }

        /* Wait for more work to be available. */
        clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_sec += 15;
        ocwq_idle_threads++;
        dbg_printf("waiting for work (idle=%d)", ocwq_idle_threads);
        rv = pthread_cond_timedwait(&ocwq_has_work, &ocwq_mtx, &ts);
        if (ocwq_signal_count > 0) {
            ocwq_signal_count--;
            continue;
        }

        if ((rv == 0) || (rv == ETIMEDOUT)) {
            /* Normally, the signaler will decrement the idle counter,
               but this path is not taken in response to a signaler.
             */
            ocwq_idle_threads--;
            pthread_mutex_unlock(&ocwq_mtx);
            break;
        }

        dbg_perror("pthread_cond_timedwait");
        abort();
        break;
    }

    dbg_printf("worker exiting (idle=%d)", ocwq_idle_threads);
    pthread_exit(NULL);
    /* NOTREACHED */
    return (NULL);
}

static inline void reset_queue_mask(unsigned int wqlist_index)
{
    unsigned int wqlist_index_bit = (0x1 << wqlist_index);
    unsigned int new_mask;
    
    // Remove this now empty wq from the mask, the only contention here is with threads performing the same
    // operation on another workqueue, so we will not be long
    // the 'bit' for this queue is protected by the spin lock, so we will only clear a bit which we have 
    // ownership for (see below for the corresponding part on the producer side)
    
    new_mask = atomic_and(&wqlist_mask, ~(wqlist_index_bit));
    
    while (slowpath(new_mask & wqlist_index_bit))
    {
        _hardware_pause();
        new_mask = atomic_and(&wqlist_mask, ~(wqlist_index_bit));
    }       
    
    return;
}

static struct work *
wqlist_scan(int *queue_priority, int skip_thread_exit_events)
{
    pthread_workqueue_t workq;
    struct work *witem = NULL;
    int idx;
    
    idx = ffs(wqlist_mask);

    if (idx == 0)
        return (NULL);
    
    workq = wqlist[idx - 1];
    
    pthread_spin_lock(&workq->mtx);

    witem = STAILQ_FIRST(&workq->item_listhead);

    if (witem)
    {
        if (!(skip_thread_exit_events && (witem->func == NULL)))
        {
            STAILQ_REMOVE_HEAD(&workq->item_listhead, item_entry);
            
            if (STAILQ_EMPTY(&workq->item_listhead))
                reset_queue_mask(workq->wqlist_index);
            
            *queue_priority = workq->queueprio;
        }
        else
            witem = NULL;
    }

    pthread_spin_unlock(&workq->mtx);
    
    return (witem); // NULL if multiple threads raced for the same queue 
}

// Optional busy loop for getting the next item for a while if so configured
// We'll only spin limited number of threads at a time (this is really mostly useful when running
// in low latency configurations using dedicated processor sets, usually a single spinner makes sense)

static struct work *
wqlist_scan_spin(int *queue_priority)
{
    struct work *witem = NULL;
    
    // Start spinning if relevant, otherwise skip and go through
    // the normal wqlist_scan_wait slowpath by returning the NULL witem.
    if (atomic_inc_nv(&current_threads_spinning) <= PWQ_SPIN_THREADS)
    {
        while ((witem = wqlist_scan(queue_priority, 1)) == NULL)
            _hardware_pause();
        
        /* Force the manager thread to wakeup if we are the last idle one */
        if (scoreboard.idle == 1)
            (void) sem_post(&scoreboard.sb_sem);        
    }
    
    atomic_dec(&current_threads_spinning);    

    return witem;
}

// Normal slowpath for waiting on the condition for new work
// here we also exit workers when needed
static struct work *
wqlist_scan_wait(int *queue_priority)
{
    struct work *witem = NULL;
    
    pthread_mutex_lock(&wqlist_mtx);
    
    while ((witem = wqlist_scan(queue_priority, 0)) == NULL)
        pthread_cond_wait(&wqlist_has_work, &wqlist_mtx);
    
    pthread_mutex_unlock(&wqlist_mtx);

    /* Force the manager thread to wakeup if we are the last idle one */
    if (scoreboard.idle == 1)
        (void) sem_post(&scoreboard.sb_sem);        

    // We only process worker exists from the slow path, wqlist_scan only returns them here
    if (slowpath(witem->func == NULL)) 
    {
        dbg_puts("worker exiting..");
        atomic_dec(&scoreboard.idle);
        atomic_dec(&scoreboard.count);
        witem_free(witem);
        pthread_exit(0);
    }
    
    return witem;
}

static void *
worker_main(void *unused __attribute__ ((unused)))
{
    struct work *witem;
    int current_thread_priority = WORKQ_DEFAULT_PRIOQUEUE;
    int queue_priority = WORKQ_DEFAULT_PRIOQUEUE;

    dbg_puts("worker thread started");
    atomic_dec(&pending_thread_create);
        
    for (;;) {

        witem = wqlist_scan(&queue_priority, 1); 

        if (!witem)
        {
            witem = wqlist_scan_spin(&queue_priority);
            
            if (!witem)
                witem = wqlist_scan_wait(&queue_priority);
        }
           
        if (PWQ_RT_THREADS && (current_thread_priority != queue_priority))
        {
            current_thread_priority = queue_priority;
            ptwq_set_current_thread_priority(current_thread_priority);
        }
        
        /* Invoke the callback function */

        atomic_dec(&scoreboard.idle);
        
        witem->func(witem->func_arg);    

        atomic_inc(&scoreboard.idle); 
        
        witem_free(witem);
    }

    /* NOTREACHED */
    return (NULL);
}

static int
worker_start(void) 
{
    pthread_t tid;

    dbg_puts("Spawning another worker");

    atomic_inc(&pending_thread_create);
    atomic_inc(&scoreboard.idle); // initialize in idle state to avoid unnecessary thread creation
    atomic_inc(&scoreboard.count);

    if (pthread_create(&tid, &detached_attr, worker_main, NULL) != 0) {
        dbg_perror("pthread_create(3)");
        atomic_dec(&scoreboard.idle);
        atomic_dec(&scoreboard.count);
        return (-1);
    }

    return (0);
}

static int
worker_stop(void) 
{
    struct work *witem;
    pthread_workqueue_t workq;
    int i;
    unsigned int wqlist_index_bit, new_mask;

    witem = witem_alloc(NULL, NULL);

    pthread_mutex_lock(&wqlist_mtx);
    for (i = 0; i < PTHREAD_WORKQUEUE_MAX; i++) {
        workq = wqlist[i];
        if (workq == NULL)
            continue;

        wqlist_index_bit = (0x1 << workq->wqlist_index);

        pthread_spin_lock(&workq->mtx);
        
        new_mask = atomic_or(&wqlist_mask, wqlist_index_bit);
        
        while (slowpath(!(new_mask & wqlist_index_bit)))
        {
            _hardware_pause();
            new_mask = atomic_or(&wqlist_mask, wqlist_index_bit);                
        }             

        STAILQ_INSERT_TAIL(&workq->item_listhead, witem, item_entry);

        pthread_spin_unlock(&workq->mtx);
        
        pthread_cond_signal(&wqlist_has_work);
        pthread_mutex_unlock(&wqlist_mtx);

        return (0);
    }

    /* FIXME: this means there are no workqueues.. should never happen */
    dbg_puts("Attempting to add a workitem without a workqueue");
    abort();

    return (-1);
}

static void *
manager_main(void *unused __attribute__ ((unused)))
{
    unsigned int runqueue_length_max = cpu_count; 
    unsigned int worker_max, threads_total = 0, current_thread_count = 0;
    unsigned int worker_idle_seconds_accumulated = 0;
    unsigned int max_threads_to_stop = 0;
    unsigned int i, idle_surplus_threads = 0;
    int sem_timedwait_rv = 0;
    sigset_t sigmask;
    struct timespec   ts;
    struct timeval    tp;

    worker_max = get_process_limit();
    scoreboard.runqueue_length = get_runqueue_length();

    /* Block all signals */
    sigfillset(&sigmask);
    pthread_sigmask(SIG_BLOCK, &sigmask, NULL);

    /* Create the minimum number of workers */
    for (i = 0; i < worker_min; i++)
        worker_start();

    for (;;) {

        if (scoreboard.sb_suspend == 0) {
            dbg_puts("manager is sleeping");

            if (gettimeofday(&tp, NULL) != 0) {
                dbg_perror("gettimeofday()"); // can only fail due to overflow of date > 2038 on 32-bit platforms...
            }

            /* Convert from timeval to timespec */
            ts.tv_sec  = tp.tv_sec;
            ts.tv_nsec = tp.tv_usec * 1000;
            ts.tv_sec += 1; // wake once per second and check if we have too many idle threads...

            // We should only sleep on the condition if there are no pending signal, spurious wakeup is also ok

            if ((sem_timedwait_rv = sem_timedwait(&scoreboard.sb_sem, &ts)) != 0)
            {
                sem_timedwait_rv = errno; // used for ETIMEDOUT below
                if (errno != ETIMEDOUT)
                    dbg_perror("sem_timedwait()");
            }

            dbg_puts("manager is awake");
        } else {
            dbg_puts("manager is suspending");
            if (sem_wait(&scoreboard.sb_sem) != 0)
                dbg_perror("sem_wait()");
            dbg_puts("manager is resuming");
        }
        
        dbg_printf("idle=%u workers=%u max_workers=%u worker_min = %u",
                   scoreboard.idle, scoreboard.count, worker_max, worker_min);
                
        // If no workers available, check if we should create a new one
        if ((scoreboard.idle == 0) && (scoreboard.count > 0) && (pending_thread_create == 0)) // last part required for an extremely unlikely race at startup
        {
            // allow cheap rampup up to worker_idle_threshold without going to /proc / checking run queue length
            if (scoreboard.count < worker_idle_threshold) 
            {
                worker_start();
            }                
            else 
            {
                // otherwise check if run queue length / stalled threads allows for new creation unless we hit worker_max ceiling
                
                if (scoreboard.count < worker_max)
                {
                    if (threads_runnable(&current_thread_count, &threads_total) != 0)
                        current_thread_count = 0;
                    
                    // only start thread if we have less runnable threads than cpus and run queue length allows it
                    
                    if (current_thread_count <= cpu_count) // <= discounts the manager thread
                    {
                        scoreboard.runqueue_length = get_runqueue_length(); 

                        if (scoreboard.runqueue_length <= runqueue_length_max) // <= discounts the manager thread
                        {
                            if (scoreboard.idle == 0) // someone might have become idle during getting thread count etc.
                                worker_start();
                            else
                                dbg_puts("skipped thread creation as we got an idle one racing us");

                        }
                        else
                        {
                            dbg_printf("Not spawning worker thread, scoreboard.runqueue_length = %d > runqueue_length_max = %d", 
                                       scoreboard.runqueue_length, runqueue_length_max);
                        }
                    }
                    else
                    {
                        dbg_printf("Not spawning worker thread, thread_runnable = %d > cpu_count = %d", 
                                   current_thread_count, cpu_count);
                    }
                }
                else
                {
                    dbg_printf("Not spawning worker thread, scoreboard.count = %d >= worker_max = %d", 
                               scoreboard.count, worker_max);
                }                
            }
        }
        else
        {
            if (sem_timedwait_rv == ETIMEDOUT) // Only check for ramp down on the 'timer tick'
            {
                if (scoreboard.idle > worker_idle_threshold) // only accumulate if there are 'too many' idle threads
                {
                    worker_idle_seconds_accumulated += scoreboard.idle; // keep track of many idle 'thread seconds' we have
                
                    dbg_printf("worker_idle_seconds_accumulated = %d, scoreboard.idle = %d, scoreboard.count = %d\n",
                       worker_idle_seconds_accumulated, scoreboard.idle, scoreboard.count);
                }
                else
                {
                    dbg_puts("Resetting worker_idle_seconds_accumulated");
                    worker_idle_seconds_accumulated = 0;
                }
                
                // Only consider ramp down if we have accumulated enough thread 'idle seconds'
                // this logic will ensure that a large number of idle threads will ramp down faster
                max_threads_to_stop = worker_idle_seconds_accumulated / WORKER_IDLE_SECONDS_THRESHOLD;

                if (max_threads_to_stop > 0)
                {
                    worker_idle_seconds_accumulated = 0; 
                    idle_surplus_threads = scoreboard.idle - worker_idle_threshold; 
                    
                    if (max_threads_to_stop > idle_surplus_threads)
                        max_threads_to_stop = idle_surplus_threads;

                    // Only stop threads if we actually have 'too many' idle ones in the pool
                    for (i = 0; i < max_threads_to_stop; i++)
                    {
                        if (scoreboard.idle > worker_idle_threshold)
                        {
                            dbg_puts("Removing one thread from the thread pool");
                            worker_stop();
                        }                    
                    }
                }
            }            
        }        
    }

    /*NOTREACHED*/
    return (NULL);
}

static void
manager_start(void)
{
    pthread_t tid;
    int rv;

    dbg_puts("starting the manager thread");

    do {
        rv = pthread_create(&tid, &detached_attr, manager_main, NULL);
        if (rv == EAGAIN) {
            sleep(1);
        } else if (rv != 0) {
            /* FIXME: not nice */
            dbg_printf("thread creation failed, rv=%d", rv);
            abort();
        }
    } while (rv != 0);

    wqlist_has_manager = 1;
}

void 
manager_suspend(void)
{
    /* Wait for the manager thread to be initialized */
    while (wqlist_has_manager == 0) {
        sleep(1);
    }
    if (scoreboard.sb_suspend == 0) { 
        scoreboard.sb_suspend = 1;
    }
}

void
manager_resume(void)
{
    if (scoreboard.sb_suspend) { 
        scoreboard.sb_suspend = 0;
        __sync_synchronize();
        (void) sem_post(&scoreboard.sb_sem);        
    }
}

void
manager_workqueue_additem(struct _pthread_workqueue *workq, struct work *witem)
{
    unsigned int wqlist_index_bit = (0x1 << workq->wqlist_index);
    
    if (slowpath(workq->overcommit)) {
        pthread_t tid;

        pthread_mutex_lock(&ocwq_mtx);
        pthread_spin_lock(&workq->mtx);
        STAILQ_INSERT_TAIL(&workq->item_listhead, witem, item_entry);
        pthread_spin_unlock(&workq->mtx);
        ocwq_mask |= wqlist_index_bit;
        if (ocwq_idle_threads > 0) {
            dbg_puts("signaling an idle worker");
            pthread_cond_signal(&ocwq_has_work);
            ocwq_idle_threads--;
            ocwq_signal_count++;
        } else {
            (void)pthread_create(&tid, &detached_attr, overcommit_worker_main, NULL);
        }
        pthread_mutex_unlock(&ocwq_mtx);
    } else {
        pthread_spin_lock(&workq->mtx);

        // Only set the mask for the first item added to the workqueue. 
        if (STAILQ_EMPTY(&workq->item_listhead))
        {
            unsigned int new_mask;
            
            // The only possible contention here are with threads performing the same
            // operation on another workqueue, so we will not be blocked long... 
            // Threads operating on the same workqueue will be serialized by the spinlock so it is very unlikely.

            new_mask = atomic_or(&wqlist_mask, wqlist_index_bit);

            while (slowpath(!(new_mask & wqlist_index_bit)))
            {
                _hardware_pause();
                new_mask = atomic_or(&wqlist_mask, wqlist_index_bit);                
            }             
        }
        
        STAILQ_INSERT_TAIL(&workq->item_listhead, witem, item_entry);

        pthread_spin_unlock(&workq->mtx);

        // Only signal thread wakeup if there are idle threads available
        // and no other thread have managed to race us and empty the wqlist on our behalf already
        if (scoreboard.idle > 0) // && ((wqlist_mask & wqlist_index_bit) != 0)) // disabling this fringe optimization for now
        {
            pthread_cond_signal(&wqlist_has_work); // don't need to hold the mutex to signal
        }
    }
}


static unsigned int
get_process_limit(void)
{
#if __linux__
    struct rlimit rlim;

    if (getrlimit(RLIMIT_NPROC, &rlim) < 0) {
        dbg_perror("getrlimit(2)");
        return (DEFAULT_PROCESS_LIMIT);
    } else {
        return (rlim.rlim_max);
    }
#elif defined(__sun)

    /* For Solaris we use resource controls as outlined at: */
    /* http://docs.oracle.com/cd/E19082-01/819-2450/rmctrls.task-3/index.html */
    /* To enable per-task limits, a project needs to be created and tasks run under this project*/
    /* The default is essentially unlimited (2147483647), so we clamp it to MIN/MAX for sanity */
    /* In practice we only support a more strict limit than MAX_PROCESS_LIMIT */

    rctlblk_t *rblk;
    int num = DEFAULT_PROCESS_LIMIT; // we only use the default if we fail to get it from OS
    unsigned int threads_total = 0, current_thread_count = 0;

    if ((rblk = (rctlblk_t *)malloc(rctlblk_size())) == NULL) 
    {
        dbg_perror("malloc()");
        return num;
    }
    
    if (getrctl("task.max-lwps", NULL, rblk, RCTL_FIRST) == -1)
    {
        dbg_perror("getrctl()");
    }
    else
    {
        num = rctlblk_get_value(rblk);
        dbg_printf("task.max-lwps = %u", num);
    }

    free(rblk);  

    if (threads_runnable(&current_thread_count, &threads_total) == 0)
        num -= threads_total;  // Discount current number of running threads also

    num -= THREADS_RESERVED;  // when task limits enabled, we will fail to create new threads, so leave some room here
    
    if (num < MIN_PROCESS_LIMIT)
        num = MIN_PROCESS_LIMIT;
    
    if (num > MAX_PROCESS_LIMIT)
        num = MAX_PROCESS_LIMIT;
            
    return (unsigned int) (num);
#else
    return (DEFAULT_PROCESS_LIMIT);
#endif
}

static unsigned int
get_runqueue_length(void)
{
    double loadavg;

    /* Prefer to use the most recent measurement of the number of running KSEs
    for Linux and the kstat unix:0:sysinfo: runque/updates ratio for Solaris . */

#if __linux__
    return linux_get_runqueue_length();
#elif defined(__sun)
    return solaris_get_runqueue_length();
#endif

    /* Fallback to using the 1-minute load average if proper run queue length can't be determined. */

    /* TODO: proper error handling */
    if (getloadavg(&loadavg, 1) != 1) {
        dbg_perror("getloadavg(3)");
        return (1);
    }
    if (loadavg > INT_MAX || loadavg < 0)
        loadavg = 1;

    return ((int) loadavg);
}

unsigned long 
manager_peek(const char *key)
{
    uint64_t rv;

    if (strcmp(key, "combined_idle") == 0) {
        rv = scoreboard.idle;
        if (scoreboard.idle > worker_min)
            rv -= worker_min;
        rv += ocwq_idle_threads;
    } else if (strcmp(key, "idle") == 0) {
        rv = scoreboard.idle;
        if (scoreboard.idle > worker_min)
            rv -= worker_min;
    } else if (strcmp(key, "ocomm_idle") == 0) {
        rv = ocwq_idle_threads;
    } else {
        dbg_printf("invalid key: %s", key);
        abort();
    }

    return rv;
}
