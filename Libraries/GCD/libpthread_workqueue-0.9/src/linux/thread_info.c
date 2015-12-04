/*
 * Copyright (c) 2011, Joakim Johansson <jocke@tbricks.com>
 *
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

/* 
 
 /proc for Linux
 
 /proc/self
 This directory refers to the process accessing the /proc filesystem, and is identical to the /proc directory named by the process ID of the same process.
 
 ----------
 
 /proc/[number]/stat
 Status information about the process. This is used by ps(1). It is defined in /usr/src/linux/fs/proc/array.c.
 The fields, in order, with their proper scanf(3) format specifiers, are:
 
 pid %d
 The process ID.
 
 comm %s
 The filename of the executable, in parentheses. This is visible whether or not the executable is swapped out.
 
 state %c
 One character from the string "RSDZTW" where R is running, S is sleeping in an interruptible wait, D is waiting in uninterruptible disk sleep, Z is zombie, T is traced or stopped (on a signal), and W is paging.
 
 ---------------
 
 /proc/[number]/task (since kernel 2.6.0-test6)
 This is a directory that contains one subdirectory for each thread in the process. The name of each subdirectory is the numerical thread ID of the thread (see gettid(2)). Within each of these subdirectories, there is a set of files with the same names and contents as under the /proc/[number] directories. For attributes that are shared by all threads, the contents for each of the files under the task/[thread-ID] subdirectories will be the same as in the corresponding file in the parent /proc/[number] directory (e.g., in a multithreaded process, all of the task/[thread-ID]/cwd files will have the same value as the /proc/[number]/cwd file in the parent directory, since all of the threads in a process share a working directory). For attributes that are distinct for each thread, the corresponding files under task/[thread-ID] may have different values (e.g., various fields in each of the task/[thread-ID]/status files may be different for each thread).
 In a multithreaded process, the contents of the /proc/[number]/task directory are not available if the main thread has already terminated (typically by calling pthread_exit(3)).
 
 ---------------

 Example:
 read data from /proc/self/task/11019/stat: [11019 (lt-dispatch_sta) D 20832 10978 20832 34819 10978 4202560 251 3489 0 0 0 2 2 5 20 0 37 0 138715543 2538807296 13818 18446744073709551615 4194304 4203988 140736876632592 139770298610200 139771956665732 0 0 0 0 0 0 0 -1 2 0 0 0 0 0

*/

#include <stdio.h>
#include <sys/types.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>

#define MAX_RESULT_SIZE 4096

static int _read_file(const char *path, char *result)
{
	int read_fd, retval = -1;
    ssize_t actual_read;
    
    read_fd = open(path, O_RDONLY);
	if (read_fd == -1) 
    {
        dbg_perror("open()");
        return retval;
	}
    
	if (fcntl(read_fd, F_SETFL, O_NONBLOCK) != 0) 
    {
        dbg_perror("fcntl()");
        goto errout;
	}
        

    actual_read = read(read_fd, result, MAX_RESULT_SIZE);
	
# ifdef __ia64__
    dbg_printf("read %ld from %s", actual_read, path);
# else
    dbg_printf("read %zu from %s", (size_t) actual_read, path);
#endif

    if (actual_read == 0)
    {
        goto errout;
    }
    
    retval = 0;
    
errout:
    if (close(read_fd) != 0)
    {
        dbg_perror("close()");
    }
    
    return retval;
}


int threads_runnable(unsigned int *threads_running, unsigned int *threads_total)
{
    DIR             *dip;
    struct dirent   *dit;
    const char *task_path = "/proc/self/task";
    char thread_path[1024];
    char thread_data[MAX_RESULT_SIZE+1];
    char dummy[MAX_RESULT_SIZE+1];
    char state;
    int pid;
    unsigned int running_count = 0, total_count = 0;

    dbg_puts("Checking threads_runnable()");

    if ((dip = opendir(task_path)) == NULL)
    {
        dbg_perror("opendir");
        return -1;
    }
        
    while ((dit = readdir(dip)) != NULL)
    {
        memset(thread_data, 0, sizeof(thread_data));
        
        sprintf(thread_path, "%s/%s/stat",task_path, dit->d_name);

        if (_read_file(thread_path, thread_data) == 0)
        {
            if (sscanf(thread_data, "%d %s %c", &pid, dummy, &state) == 3)
            {
                total_count++;
                dbg_printf("The state for thread %s is %c", dit->d_name, state);
                switch (state)
                {
                    case 'R':
                        running_count++;
                        break;
                    default:
                        break;
                }
            }
            else
            {
                dbg_printf("Failed to scan state for thread %s (%s)", dit->d_name, thread_data);
            }
        }
    }

    if (closedir(dip) == -1)
    {
        perror("closedir");
    }

    dbg_printf("Running count is %d", running_count);
    *threads_running = running_count;
    *threads_total = total_count;
    
    return 0;
}

