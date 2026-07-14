// detect_arch.c
#if defined(__aarch64__)
#error aarch64
#elif defined(__arm__)
#error arm
#elif defined(__i386__)
#error i386
#elif defined(__x86_64__)
#error x86_64
#elif defined(__powerpc64__)
#error powerpc64
#elif defined(__powerpc__)
#error powerpc
#else
#error unknown
#endif