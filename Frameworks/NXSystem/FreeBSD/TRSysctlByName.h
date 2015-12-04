/*
 * TRSysctl.h - simple wrappers around BSD sysctl functionality
 *
 * Copyright 2006, David Chisnall
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimer in the documentation 
 * and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <sys/sysctl.h>
#import <stdlib.h>

#import <Foundation/NSString.h>

#ifdef LONGLONGSYSCTLS
typedef long long sysctl_return_int_t;
#else
typedef long sysctl_return_int_t;
#endif

static inline NSString *
performSysctlNamed (char *name)
{
  NSString * resultString = nil;
  size_t resultSize;

  // Get the result size for this sysctl

  if (!sysctlbyname (name, NULL, &resultSize, NULL, 0))
    {
      char *result = (char *) malloc (resultSize);

      //Attempt to get the result
      if (!sysctlbyname (name, result, &resultSize, NULL, 0))
        {
          resultString = [NSString stringWithCString:result];
        }

      // Free the c string result
      free (result);
    }

  //Returns NULL if the sysctl failed
  return resultString;
}

static inline sysctl_return_int_t
performIntegerSysctlNamed (char *name)
{
  sysctl_return_int_t result = 0;
  size_t resultSize = sizeof(result);

  sysctlbyname (name, &result, &resultSize, NULL, 0);

  return result;
}
