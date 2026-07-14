/* 
 * This file is used by configure.in.
 * Causes cpp error when running NeXT's cc.
 * No error when running gcc on a NeXT box.
 */

#if defined(NeXT)
  #if defined(_NEXT_SOURCE)
    "Not running NeXT's cc"
  #else
    "Running NeXT's cc"
    #error
  #endif
#else
  "Not running NeXT's cc"
#endif

/* This would be useful, but it isn't available in NS3.0:
   #if defined(NX_CURRENT_COMPILER_RELEASE) */
