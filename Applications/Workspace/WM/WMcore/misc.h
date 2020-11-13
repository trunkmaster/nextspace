/* ---[ WINGs/misc.c ]--------------------------------------------------- */

#ifndef _W_MISC_H_
#define _W_MISC_H_

typedef struct {
    int position;
    int count;
} WMRange;

WMRange wmkrange(int start, int count);

/* An application must call this function before exiting, to let WUtil do some internal cleanup */
void wutil_shutdown(void);

#endif
