#include "loadave.h"

#include <stdio.h>
#include <stdlib.h>

int la_init(unsigned long long *times)
{
  return la_read(times);
}

#if defined( linux )

int la_read(unsigned long long *times)
{
  int i;
  unsigned long long c_idle,c_sys,c_nice,c_iow,c_user,c_xxx,c_yyy;
  FILE *f=fopen("/proc/stat","rt");
  if (!f)
    return LA_ERROR;
  i=fscanf(f,"cpu %Lu %Lu %Lu %Lu %Lu %Lu %Lu\n",
    &c_user,&c_nice,&c_sys,&c_idle,&c_iow,&c_xxx,&c_yyy);
  if (i<4)
    return LA_ERROR;
  if (i<5)
    c_iow=0;
  fclose(f);
  times[CP_IDLE] = c_idle;
  times[CP_SYS] = c_sys;
  times[CP_NICE] = c_nice;
  times[CP_USER] = c_user;
  times[CP_IOWAIT] = c_iow;
  return LA_NOERR;
}

#elif defined( __FreeBSD__ ) 

#include <sys/types.h>
#include <sys/errno.h>
#include <sys/resource.h>	// CPUSTATES
#include <sys/sysctl.h>		// sysctlbyname()
          
int la_read(unsigned long long *times)
{
  const char
    *name = "kern.cp_time";
  int
    cpu_states[CPUSTATES];
  size_t
    nlen = sizeof cpu_states,
    len = nlen;
  int
    err;
  
  err= sysctlbyname(name, &cpu_states, &nlen, NULL, 0);
  if( -1 == err )
  {
    fprintf(stderr, "sysctl(%s...) failed: %s\n", name, strerror(errno));
    exit(errno);
  }
  if( nlen != len )
  {
    fprintf(stderr, "sysctl(%s...) expected %lu, got %lu\n",
                    name, (unsigned long) len, (unsigned long) nlen);
    exit(errno);
  }
  times[CP_IDLE] = cpu_states[4];
  times[CP_SYS] = cpu_states[2];
  times[CP_NICE] = cpu_states[1];
  times[CP_USER] = cpu_states[0];
  times[CP_IOWAIT] = cpu_states[3];
  
  return LA_NOERR;
}

#elif  defined( __NetBSD__ ) || defined ( __OpenBSD__)

#include <sys/types.h>
#include <errno.h>
#include <sys/resource.h>	// CPUSTATES
#include <sys/param.h>
#include <sys/sysctl.h>		// sysctlbyname()
#include <string.h>             // strerror()
#include <machine/cpu.h>        // second level machdep identifiers
          
int la_read(unsigned long long *times)
{
  int mib[2];

#ifdef __NetBSD__
  uint64_t
    cpu_states[CPUSTATES];
#else
  long
    cpu_states[CPUSTATES];
#endif

  size_t
    nlen = sizeof cpu_states,
    len = nlen;
  int
    err;
  
#ifdef __NetBSD__
  mib[0] = CTL_KERN;
  mib[1] = KERN_CP_TIME;
#else
  mib[0] = CTL_KERN;
  mib[1] = KERN_CPTIME;
#endif

  err= sysctl(mib, 2, &cpu_states, &nlen, NULL, 0);
  if( -1 == err )
  {
    fprintf(stderr, "sysctl(...) failed: %s\n", strerror(errno));
    exit(errno);
  }
  if( nlen != len )
  {
    fprintf(stderr, "sysctl(...) expected %lu, got %lu\n",
                    (unsigned long) len, (unsigned long) nlen);
    exit(errno);
  }
  times[CP_IDLE] = cpu_states[4];
  times[CP_SYS] = cpu_states[2];
  times[CP_NICE] = cpu_states[1];
  times[CP_USER] = cpu_states[0];
  times[CP_IOWAIT] = cpu_states[3];
  
  return LA_NOERR;
}

#else 
// Darwin should always be the always the last option...

#include <sys/sysctl.h>

#include <mach/mach_init.h>
#include <mach/mach_host.h>
#include <mach/mach_error.h>
#include <mach/mach_port.h>
#include <mach/mach_types.h>

int la_read(unsigned long long *times)
{
  kern_return_t ret;
  host_cpu_load_info_data_t cpuStats;
  mach_msg_type_number_t count;
  static mach_port_t timemon_port = 0L;
  long long totalticks;

  if(timemon_port == 0L)
    {
      timemon_port = mach_host_self();
    }

  count = HOST_CPU_LOAD_INFO_COUNT;
  ret = host_statistics(timemon_port,HOST_CPU_LOAD_INFO,(host_info_t)&cpuStats,&count);

  totalticks = cpuStats.cpu_ticks[CPU_STATE_IDLE] + cpuStats.cpu_ticks[CPU_STATE_USER] +
    cpuStats.cpu_ticks[CPU_STATE_NICE] + cpuStats.cpu_ticks[CPU_STATE_SYSTEM];

  times[CP_IDLE] = cpuStats.cpu_ticks[CPU_STATE_IDLE];
  times[CP_SYS] =  cpuStats.cpu_ticks[CPU_STATE_SYSTEM];
  times[CP_NICE] = cpuStats.cpu_ticks[CPU_STATE_NICE];
  times[CP_USER] = cpuStats.cpu_ticks[CPU_STATE_USER];
  times[CP_IOWAIT] = 0; 
  return LA_NOERR;
}

#endif

void la_finish(void)
{
}
