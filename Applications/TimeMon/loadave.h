/* Copyright 1991, 1994, 1997 Scott Hess.  Permission to use, copy, modify,
 * and distribute this software and its documentation for any purpose
 * and without fee is hereby granted, provided that this copyright
 * notice appear in all copies.  The copyright notice need not appear
 * on binary-only distributions - just in source code.
 * 
 * Scott Hess makes no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express
 * or implied warranty.
 */

#define CPUSTATES 5
#define CP_SYS 0
#define CP_USER 1
#define CP_NICE 2
#define CP_IOWAIT 3
#define CP_IDLE 4

/* These codes are returned from la_init() and la_read(). */
enum la_error
{
  LA_NOERR,		/* No problem. */
  LA_ERROR		/* Problem. */
};

/* The times are returned in an array of 5 unsigned long long:s, and should
   be cumulative counts of 'time'.  The unit used doesn't matter.  E.g.
   number of jiffies since system startup would work ok.  Idle and user are
   the most important states; the others can be set to 0 if you can't get
   values for them.  */

/* Get ready for operation and retrieve the current times. */
int la_init(unsigned long long *times);

/* Retrieve the current times. */
int la_read(unsigned long long *times);

/* Close up anything that's open. */
void la_finish(void);

