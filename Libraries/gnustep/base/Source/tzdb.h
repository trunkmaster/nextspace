/*
** The first part of this file is in the public domain, so clarified as of
** 1996-06-05 by Arthur David Olson (arthur_david_olson@nih.gov).
*/

/*
** This header is for use ONLY with the time conversion code.
** There is no guarantee that it will remain unchanged,
** or that it will remain at all.
** Do NOT copy it to any system include directory.
** Thank you!
*/

/*
** Information about time zone files.
*/

#ifndef TZDEFAULT
#define TZDEFAULT	"localtime"
#endif /* !defined TZDEFAULT */

#ifndef TZDEFRULES
#define TZDEFRULES	"posixrules"
#endif /* !defined TZDEFRULES */

/*
** Each file begins with. . .
*/

#define	TZ_MAGIC	"TZif"

struct tzhead {
 	char	tzh_magic[4];		/* TZ_MAGIC */
	char	tzh_version[1];		/* \0 for 1, 2 or 3 */
	char	tzh_reserved[15];	/* reserved for future use */
	char	tzh_ttisutcnt[4];	/* coded number of trans. time flags */
	char	tzh_ttisstdcnt[4];	/* coded number of trans. time flags */
	char	tzh_leapcnt[4];		/* coded number of leap seconds */
	char	tzh_timecnt[4];		/* coded number of transition times */
	char	tzh_typecnt[4];		/* coded number of local time types */
	char	tzh_charcnt[4];		/* coded number of abbr. chars */
};

/*
** . . .followed by. . .
**
**	tzh_timecnt (char [4])s		coded transition times a la time(2)
**	tzh_timecnt (unsigned char)s	types of local time starting at above
**	tzh_typecnt repetitions of
**		one (char [4])		coded UTC offset in seconds
**		one (unsigned char)	used to set tm_isdst
**		one (unsigned char)	that's an abbreviation list index
**	tzh_charcnt (char)s		'\0'-terminated zone abbreviations
**	tzh_leapcnt repetitions of
**		one (char [4])		coded leap second transition times
**		one (char [4])		total correction after above
**	tzh_ttisstdcnt (char)s		indexed by type; if TRUE, transition
**					time is standard time, if FALSE,
**					transition time is wall clock time
**					if absent, transition times are
**					assumed to be wall clock time
**	tzh_ttisgmtcnt (char)s		indexed by type; if TRUE, transition
**					time is UTC, if FALSE,
**					transition time is local time
**					if absent, transition times are
**					assumed to be local time
*/

/*
** In the current implementation, "tzset()" refuses to deal with files that
** exceed any of the limits below.
*/

#ifndef TZ_MAX_TIMES
/*
** A value of 370 is enough to handle a bit more than a year's worth of
** solar time (corrected daily to the nearest second) or 138 years of
** Pacific Presidential Election time
** (where there are three time zone transitions every fourth year).
** This needs to be at least 2000 to cope with TZDB v2+ as likely
** dates go far further into the future than TZDB v1
*/
#define TZ_MAX_TIMES	2000
#endif /* !defined TZ_MAX_TIMES */

#ifndef TZ_MAX_TYPES
#ifndef NOSOLAR
#define TZ_MAX_TYPES	256 /* Limited by what (unsigned char)'s can hold */
#endif /* !defined NOSOLAR */
#ifdef NOSOLAR
/*
** Must be at least 14 for Europe/Riga as of Jan 12 1995,
** as noted by Earl Chew <earl@hpato.aus.hp.com>.
*/
#define TZ_MAX_TYPES	20	/* Maximum number of local time types */
#endif /* !defined NOSOLAR */
#endif /* !defined TZ_MAX_TYPES */

#ifndef TZ_MAX_CHARS
#define TZ_MAX_CHARS	50	/* Maximum number of abbreviation characters */
				/* (limited by what unsigned chars can hold) */
#endif /* !defined TZ_MAX_CHARS */

#ifndef TZ_MAX_LEAPS
#define TZ_MAX_LEAPS	50	/* Maximum number of leap second corrections */
#endif /* !defined TZ_MAX_LEAPS */

#define SECSPERMIN	60
#define MINSPERHOUR	60
#define HOURSPERDAY	24
#define DAYSPERWEEK	7
#define DAYSPERNYEAR	365
#define DAYSPERLYEAR	366
#define SECSPERHOUR	(SECSPERMIN * MINSPERHOUR)
#define SECSPERDAY	((long) SECSPERHOUR * HOURSPERDAY)
#define MONSPERYEAR	12

#define TM_SUNDAY	0
#define TM_MONDAY	1
#define TM_TUESDAY	2
#define TM_WEDNESDAY	3
#define TM_THURSDAY	4
#define TM_FRIDAY	5
#define TM_SATURDAY	6

#define TM_JANUARY	0
#define TM_FEBRUARY	1
#define TM_MARCH	2
#define TM_APRIL	3
#define TM_MAY		4
#define TM_JUNE		5
#define TM_JULY		6
#define TM_AUGUST	7
#define TM_SEPTEMBER	8
#define TM_OCTOBER	9
#define TM_NOVEMBER	10
#define TM_DECEMBER	11

#define TM_YEAR_BASE	1900

#define EPOCH_YEAR	1970
#define EPOCH_WDAY	TM_THURSDAY

/*
** Accurate only for the past couple of centuries;
** that will probably do.
*/

#define isleap(y) (((y) % 4) == 0 && (((y) % 100) != 0 || ((y) % 400) == 0))

#ifndef USG

/*
** Use of the underscored variants may cause problems if you move your code to
** certain System-V-based systems; for maximum portability, use the
** underscore-free variants.  The underscored variants are provided for
** backward compatibility only; they may disappear from future versions of
** this file.
*/

#define SECS_PER_MIN	SECSPERMIN
#define MINS_PER_HOUR	MINSPERHOUR
#define HOURS_PER_DAY	HOURSPERDAY
#define DAYS_PER_WEEK	DAYSPERWEEK
#define DAYS_PER_NYEAR	DAYSPERNYEAR
#define DAYS_PER_LYEAR	DAYSPERLYEAR
#define SECS_PER_HOUR	SECSPERHOUR
#define SECS_PER_DAY	SECSPERDAY
#define MONS_PER_YEAR	MONSPERYEAR

#endif /* !defined USG */



/* 
 * The remainder of this file is derived from public-domain implementation
 * available from NetBSD's libc
 * src/lib/libc/time/private.h 
 * src/lib/libc/time/localtime.c
 */

#ifndef __UNCONST
#define __UNCONST(a)   ((void *)(const void *)(a))
#endif

#ifndef _DIAGASSERT
#define _DIAGASSERT(e)
#endif

#ifndef TZDIR
#define TZDIR "/usr/share/zoneinfo"
#endif

/*
** This file is in the public domain, so clarified as of
** 1996-06-05 by Arthur David Olson.
*/

/*
** This header is for use ONLY with the time conversion code.
** There is no guarantee that it will remain unchanged,
** or that it will remain at all.
** Do NOT copy it to any system include directory.
** Thank you!
*/

/*
** zdump has been made independent of the rest of the time
** conversion package to increase confidence in the verification it provides.
** You can use zdump to help in verifying other implementations.
** To do this, compile with -DUSE_LTZ=0 and link without the tz library.
*/
#ifndef USE_LTZ
# define USE_LTZ 1
#endif

/* This string was in the Factory zone through version 2016f.  */
#define GRANDPARENTED	"Local time zone must be set--see zic manual page"

/*
** Defaults for preprocessor symbols.
** You can override these in your C compiler options, e.g. '-DHAVE_GETTEXT=1'.
*/

#if !defined HAVE_GENERIC && defined __has_extension
# if __has_extension(c_generic_selections)
#  define HAVE_GENERIC 1
# else
#  define HAVE_GENERIC 0
# endif
#endif
/* _Generic is buggy in pre-4.9 GCC.  */
#if !defined HAVE_GENERIC && defined __GNUC__
# define HAVE_GENERIC (4 < __GNUC__ + (9 <= __GNUC_MINOR__))
#endif
#ifndef HAVE_GENERIC
# define HAVE_GENERIC (201112 <= __STDC_VERSION__)
#endif

/*
** Nested includes
*/

#include <time.h>
#include <sys/types.h>	/* for time_t */

#include <stdlib.h>

#ifndef ENAMETOOLONG
# define ENAMETOOLONG EINVAL
#endif
#ifndef ENOTSUP
# define ENOTSUP EINVAL
#endif
#ifndef EOVERFLOW
# define EOVERFLOW EINVAL
#endif

#if HAVE_UNISTD_H
#include <unistd.h>	/* for R_OK, and other POSIX goodness */
#endif /* HAVE_UNISTD_H */

#ifndef R_OK
#define R_OK	4
#endif /* !defined R_OK */

/* Unlike <ctype.h>'s isdigit, this also works if c < 0 | c > UCHAR_MAX. */
#define is_digit(c) ((unsigned)(c) - '0' <= 9)

#if HAVE_STDINT_H
#include <stdint.h>
#endif /* !HAVE_STDINT_H */

#if HAVE_INTTYPES_H
# include <inttypes.h>
#endif

/* Pre-C99 GCC compilers define __LONG_LONG_MAX__ instead of LLONG_MAX.  */
#ifdef __LONG_LONG_MAX__
# ifndef LLONG_MAX
#  define LLONG_MAX __LONG_LONG_MAX__
# endif
# ifndef LLONG_MIN
#  define LLONG_MIN (-1 - LLONG_MAX)
# endif
#endif

#ifndef INT_FAST64_MAX
# ifdef LLONG_MAX
typedef long long	int_fast64_t;
#  define INT_FAST64_MIN LLONG_MIN
#  define INT_FAST64_MAX LLONG_MAX
# else
#  if LONG_MAX >> 31 < 0xffffffff
Please use a compiler that supports a 64-bit integer type (or wider);
you may need to compile with "-DHAVE_STDINT_H".
#  endif
typedef long		int_fast64_t;
#  define INT_FAST64_MIN LONG_MIN
#  define INT_FAST64_MAX LONG_MAX
# endif
#endif

#ifndef INT_FAST32_MAX
# if INT_MAX >> 31 == 0
typedef long int_fast32_t;
#  define INT_FAST32_MAX LONG_MAX
#  define INT_FAST32_MIN LONG_MIN
# else
typedef int int_fast32_t;
#  define INT_FAST32_MAX INT_MAX
#  define INT_FAST32_MIN INT_MIN
# endif
#endif

#ifndef UINT_FAST64_MAX
# if defined ULLONG_MAX || defined __LONG_LONG_MAX__
typedef unsigned long long uint_fast64_t;
# else
#  if ULONG_MAX >> 31 >> 1 < 0xffffffff
Please use a compiler that supports a 64-bit integer type (or wider);
you may need to compile with "-DHAVE_STDINT_H".
#  endif
typedef unsigned long	uint_fast64_t;
# endif
#endif

#ifndef INT32_MAX
#define INT32_MAX 0x7fffffff
#endif /* !defined INT32_MAX */
#ifndef INT32_MIN
#define INT32_MIN (-1 - INT32_MAX)
#endif /* !defined INT32_MIN */

#if 3 <= __GNUC__
# define ATTRIBUTE_CONST __attribute__ ((__const__))
# define ATTRIBUTE_MALLOC __attribute__ ((__malloc__))
# define ATTRIBUTE_PURE __attribute__ ((__pure__))
# define ATTRIBUTE_FORMAT(spec) __attribute__ ((__format__ spec))
#else
# define ATTRIBUTE_CONST /* empty */
# define ATTRIBUTE_MALLOC /* empty */
# define ATTRIBUTE_PURE /* empty */
# define ATTRIBUTE_FORMAT(spec) /* empty */
#endif

#if !defined _Noreturn && __STDC_VERSION__ < 201112
# if 2 < __GNUC__ + (8 <= __GNUC_MINOR__)
#  define _Noreturn __attribute__ ((__noreturn__))
# else
#  define _Noreturn
# endif
#endif

#if __STDC_VERSION__ < 199901 && !defined restrict
# define restrict /* empty */
#endif

/*
** Workarounds for compilers/systems.
*/

#ifndef EPOCH_LOCAL
# define EPOCH_LOCAL 0
#endif
#ifndef EPOCH_OFFSET
# define EPOCH_OFFSET 0
#endif
#ifndef RESERVE_STD_EXT_IDS
# define RESERVE_STD_EXT_IDS 0
#endif

/* If standard C identifiers with external linkage (e.g., localtime)
   are reserved and are not already being renamed anyway, rename them
   as if compiling with '-Dtime_tz=time_t'.  */
#if !defined time_tz && RESERVE_STD_EXT_IDS && USE_LTZ
# define time_tz time_t
#endif

/*
** Compile with -Dtime_tz=T to build the tz package with a private
** time_t type equivalent to T rather than the system-supplied time_t.
** This debugging feature can test unusual design decisions
** (e.g., time_t wider than 'long', or unsigned time_t) even on
** typical platforms.
*/
#if defined time_tz || EPOCH_LOCAL || EPOCH_OFFSET != 0
# define TZ_TIME_T 1
#else
# define TZ_TIME_T 0
#endif

#if TZ_TIME_T
typedef time_tz tz_time_t;
#endif


/*
** Finally, some convenience items.
*/

#define TYPE_BIT(type)	(sizeof (type) * CHAR_BIT)
#define TYPE_SIGNED(type) (/*CONSTCOND*/((type) -1) < 0)
#define TWOS_COMPLEMENT(t) (/*CONSTCOND*/(t) ~ (t) 0 < 0)

/* Max and min values of the integer type T, of which only the bottom
   B bits are used, and where the highest-order used bit is considered
   to be a sign bit if T is signed.  */
#define MAXVAL(t, b) /*LINTED*/					\
  ((t) (((t) 1 << ((b) - 1 - TYPE_SIGNED(t)))			\
	- 1 + ((t) 1 << ((b) - 1 - TYPE_SIGNED(t)))))
#define MINVAL(t, b)						\
  ((t) (TYPE_SIGNED(t) ? - TWOS_COMPLEMENT(t) - MAXVAL(t, b) : 0))

/* The extreme time values, assuming no padding.  */
#define TIME_T_MIN_NO_PADDING MINVAL(time_t, TYPE_BIT(time_t))
#define TIME_T_MAX_NO_PADDING MAXVAL(time_t, TYPE_BIT(time_t))

/* The extreme time values.  These are macros, not constants, so that
   any portability problem occur only when compiling .c files that use
   the macros, which is safer for applications that need only zdump and zic.
   This implementation assumes no padding if time_t is signed and
   either the compiler lacks support for _Generic or time_t is not one
   of the standard signed integer types.  */
#if HAVE_GENERIC
# define TIME_T_MIN \
    _Generic((time_t) 0, \
	     signed char: SCHAR_MIN, short: SHRT_MIN, \
	     int: INT_MIN, long: LONG_MIN, long long: LLONG_MIN, \
	     default: TIME_T_MIN_NO_PADDING)
# define TIME_T_MAX \
    (TYPE_SIGNED(time_t) \
     ? _Generic((time_t) 0, \
		signed char: SCHAR_MAX, short: SHRT_MAX, \
		int: INT_MAX, long: LONG_MAX, long long: LLONG_MAX, \
		default: TIME_T_MAX_NO_PADDING)			    \
     : (time_t) -1)
#else
# define TIME_T_MIN TIME_T_MIN_NO_PADDING
# define TIME_T_MAX TIME_T_MAX_NO_PADDING
#endif

/*
** 302 / 1000 is log10(2.0) rounded up.
** Subtract one for the sign bit if the type is signed;
** add one for integer division truncation;
** add one more for a minus sign if the type is signed.
*/
#define INT_STRLEN_MAXIMUM(type) \
	((TYPE_BIT(type) - TYPE_SIGNED(type)) * 302 / 1000 + \
	1 + TYPE_SIGNED(type))

/*
** INITIALIZE(x)
*/

#if defined(__GNUC__) || defined(__lint__)
# define INITIALIZE(x)	((x) = 0)
#else
# define INITIALIZE(x)
#endif

/* Handy macros that are independent of tzfile implementation.  */

#define YEARSPERREPEAT		400	/* years before a Gregorian repeat */

#define SECSPERMIN	60
#define MINSPERHOUR	60
#define HOURSPERDAY	24
#define DAYSPERWEEK	7
#define DAYSPERNYEAR	365
#define DAYSPERLYEAR	366
#define SECSPERHOUR	(SECSPERMIN * MINSPERHOUR)
#ifndef SECSPERDAY
#define SECSPERDAY	((int_fast32_t) SECSPERHOUR * HOURSPERDAY)
#endif
#define MONSPERYEAR	12

#define TM_SUNDAY	0
#define TM_MONDAY	1
#define TM_TUESDAY	2
#define TM_WEDNESDAY	3
#define TM_THURSDAY	4
#define TM_FRIDAY	5
#define TM_SATURDAY	6

#define TM_JANUARY	0
#define TM_FEBRUARY	1
#define TM_MARCH	2
#define TM_APRIL	3
#define TM_MAY		4
#define TM_JUNE		5
#define TM_JULY		6
#define TM_AUGUST	7
#define TM_SEPTEMBER	8
#define TM_OCTOBER	9
#define TM_NOVEMBER	10
#define TM_DECEMBER	11

#define TM_YEAR_BASE	1900

#define EPOCH_YEAR	1970
#define EPOCH_WDAY	TM_THURSDAY

#define isleap(y) (((y) % 4) == 0 && (((y) % 100) != 0 || ((y) % 400) == 0))

/*
** Since everything in isleap is modulo 400 (or a factor of 400), we know that
**	isleap(y) == isleap(y % 400)
** and so
**	isleap(a + b) == isleap((a + b) % 400)
** or
**	isleap(a + b) == isleap(a % 400 + b % 400)
** This is true even if % means modulo rather than Fortran remainder
** (which is allowed by C89 but not by C99 or later).
** We use this to avoid addition overflow problems.
*/

#define isleap_sum(a, b)	isleap((a) % 400 + (b) % 400)


/*
** The Gregorian year averages 365.2425 days, which is 31556952 seconds.
*/

#define AVGSECSPERYEAR		31556952L
#define SECSPERREPEAT \
  ((int_fast64_t) YEARSPERREPEAT * (int_fast64_t) AVGSECSPERYEAR)
#define SECSPERREPEAT_BITS	34	/* ceil(log2(SECSPERREPEAT)) */


/*	$NetBSD: localtime.c,v 1.123 2020/05/25 14:52:48 christos Exp $	*/

/* Convert timestamp from time_t to struct tm.  */

/*
** This file is in the public domain, so clarified as of
** 1996-06-05 by Arthur David Olson.
*/

/*
** Leap second handling from Bradley White.
** POSIX-style TZ environment variable handling from Guy Harris.
*/

#include <fcntl.h>

/* ms-windows lacks ssize_t but has SSIZE_T
 */
#if defined(_MSC_VER)
typedef SSIZE_T ssize_t;
#endif

#ifndef TZ_ABBR_MAX_LEN
#define TZ_ABBR_MAX_LEN	16
#endif /* !defined TZ_ABBR_MAX_LEN */

#ifndef TZ_ABBR_CHAR_SET
#define TZ_ABBR_CHAR_SET \
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 :+-._"
#endif /* !defined TZ_ABBR_CHAR_SET */

#ifndef TZ_ABBR_ERR_CHAR
#define TZ_ABBR_ERR_CHAR	'_'
#endif /* !defined TZ_ABBR_ERR_CHAR */

/*
** SunOS 4.1.1 headers lack O_BINARY.
*/

#ifdef O_BINARY
#define OPEN_MODE	(O_RDONLY | O_BINARY)
#else
#define OPEN_MODE	(O_RDONLY)
#endif /* !defined O_BINARY */

/*
** The DST rules to use if TZ has no rules and we can't load TZDEFRULES.
** Default to US rules as of 2017-05-07.
** POSIX does not specify the default DST rules;
** for historical reasons, US rules are a common default.
*/
#ifndef TZDEFRULESTRING
#define TZDEFRULESTRING ",M3.2.0,M11.1.0"
#endif

struct _ttinfo {				/* time type information */
	int_fast32_t	tt_utoff;	/* UT offset in seconds */
	BOOL		tt_isdst;	/* used to set tm_isdst */
	int		tt_desigidx;	/* abbreviation list index */
	BOOL		tt_ttisstd;	/* transition is std time */
	BOOL		tt_ttisut;	/* transition is UT */
};

struct lsinfo {				/* leap second information */
	time_t		ls_trans;	/* transition time */
	int_fast64_t	ls_corr;	/* correction to apply */
};

#define SMALLEST(a, b)	(((a) < (b)) ? (a) : (b))
#define BIGGEST(a, b)	(((a) > (b)) ? (a) : (b))

#ifdef TZNAME_MAX
#define MY_TZNAME_MAX	TZNAME_MAX
#endif /* defined TZNAME_MAX */
#ifndef TZNAME_MAX
#define MY_TZNAME_MAX	255
#endif /* !defined TZNAME_MAX */

/* BIGGEST(BIGGEST(TZ_MAX_CHARS + 1, sizeof "GMT"), (2 * (MY_TZNAME_MAX + 1)))
 */
#define	TZ_MAX_CHARS_OR_NAMES	512

#define state __state
struct state {
	int		leapcnt;
	int		timecnt;
	int		typecnt;
	int		charcnt;
	BOOL		goback;
	BOOL		goahead;
	time_t		ats[TZ_MAX_TIMES];
	unsigned char	types[TZ_MAX_TIMES];
	struct _ttinfo	ttis[TZ_MAX_TYPES];
	char		chars[TZ_MAX_CHARS_OR_NAMES];
	struct lsinfo	lsis[TZ_MAX_LEAPS];

	/* The time type to use for early times or if no transitions.
	   It is always zero for recent tzdb releases.
	   It might be nonzero for data from tzdb 2018e or earlier.  */
	int defaulttype;
};

enum r_type {
  JULIAN_DAY,		/* Jn = Julian day */
  DAY_OF_YEAR,		/* n = day of year */
  MONTH_NTH_DAY_OF_WEEK	/* Mm.n.d = month, week, day of week */
};

struct rule {
	enum r_type	r_type;		/* type of rule */
	int		r_day;		/* day number of rule */
	int		r_week;		/* week number of rule */
	int		r_mon;		/* month number of rule */
	int_fast32_t	r_time;		/* transition time of rule */
};

typedef struct {
 int tm_sec;    	/* Seconds (0-60) */
 int tm_min;    	/* Minutes (0-59) */
 int tm_hour;   	/* Hours (0-23) */
 int tm_mday;   	/* Day of the month (1-31) */
 int tm_mon;    	/* Month (0-11) */
 int tm_year;   	/* Year - 1900 */
 int tm_wday;   	/* Day of the week (0-6, Sunday = 0) */
 int tm_yday;   	/* Day in the year (0-365, 1 Jan = 0) */
 int tm_isdst;  	/* Daylight saving time */
 int tm_gmtoff;		/* Localtime offset from UTC */
 const char *tm_zone;	/* Timezone name */
} gstm;

static BOOL increment_overflow(int *, int);
static BOOL increment_overflow_time(time_t *, int_fast32_t);
static int_fast64_t leapcorr(struct state const *, time_t);
static gstm *timesub(time_t const *, int_fast32_t, struct state const *,
			  gstm *);
static BOOL typesequiv(struct state const *, int, int);
static BOOL tzparse(char const *, struct state *, BOOL);

/* Initialize *S to a value based on UTOFF, ISDST, and DESIGIDX.  */
static void
init_ttinfo(struct _ttinfo *s, int_fast32_t utoff, BOOL isdst, int desigidx)
{
	s->tt_utoff = utoff;
	s->tt_isdst = isdst;
	s->tt_desigidx = desigidx;
	s->tt_ttisstd = false;
	s->tt_ttisut = false;
}

static int_fast32_t
detzcode(const char *const codep)
{
	int_fast32_t result;
	int	i;
	int_fast32_t one = 1;
	int_fast32_t halfmaxval = one << (32 - 2);
	int_fast32_t maxval = halfmaxval - 1 + halfmaxval;
	int_fast32_t minval = -1 - maxval;

	result = codep[0] & 0x7f;
	for (i = 1; i < 4; ++i)
		result = (result << 8) | (codep[i] & 0xff);

	if (codep[0] & 0x80) {
	  /* Do two's-complement negation even on non-two's-complement machines.
	     If the result would be minval - 1, return minval.  */
	    result -= !TWOS_COMPLEMENT(int_fast32_t) && result != 0;
	    result += minval;
	}
 	return result;
}

static int_fast64_t
detzcode64(const char *const codep)
{
	int_fast64_t result;
	int	i;
	int_fast64_t one = 1;
	int_fast64_t halfmaxval = one << (64 - 2);
	int_fast64_t maxval = halfmaxval - 1 + halfmaxval;
	int_fast64_t minval = -TWOS_COMPLEMENT(int_fast64_t) - maxval;

	result = codep[0] & 0x7f;
	for (i = 1; i < 8; ++i)
		result = (result << 8) | (codep[i] & 0xff);

	if (codep[0] & 0x80) {
	  /* Do two's-complement negation even on non-two's-complement machines.
	     If the result would be minval - 1, return minval.  */
	  result -= !TWOS_COMPLEMENT(int_fast64_t) && result != 0;
	  result += minval;
	}
 	return result;
}



static void
scrub_abbrs(struct state *sp)
{
	int i;

	/*
	** First, replace bogus characters.
	*/
	for (i = 0; i < sp->charcnt; ++i)
		if (strchr(TZ_ABBR_CHAR_SET, sp->chars[i]) == NULL)
			sp->chars[i] = TZ_ABBR_ERR_CHAR;
	/*
	** Second, truncate long abbreviations.
	*/
	for (i = 0; i < sp->typecnt; ++i) {
		const struct _ttinfo * const	ttisp = &sp->ttis[i];
		char *cp = &sp->chars[ttisp->tt_desigidx];

		if (strlen(cp) > TZ_ABBR_MAX_LEN &&
			strcmp(cp, GRANDPARENTED) != 0)
				*(cp + TZ_ABBR_MAX_LEN) = '\0';
	}
}

static BOOL
differ_by_repeat(const time_t t1, const time_t t0)
{
	if (TYPE_BIT(time_t) - TYPE_SIGNED(time_t) < SECSPERREPEAT_BITS)
		return 0;
	return (int_fast64_t)t1 - (int_fast64_t)t0 == SECSPERREPEAT;
}

union input_buffer {
	/* The first part of the buffer, interpreted as a header.  */
	struct tzhead tzhead;

	/* The entire buffer.  */
	char buf[2 * sizeof(struct tzhead) + 2 * sizeof (struct state)
	  + 4 * TZ_MAX_TIMES];
};

/* TZDIR with a trailing '/' rather than a trailing '\0'.  */
static char const tzdirslash[sizeof TZDIR] = TZDIR "/";

/* Local storage needed for 'tzloadbody'.  */
union local_storage {
	/* The results of analyzing the file's contents after it is opened.  */
	struct file_analysis {
		/* The input buffer.  */
		union input_buffer u;

		/* A temporary state used for parsing a TZ string in the file.  */
		struct state st;
	} u;

	/* The file name to be opened.  */
	char fullname[/*CONSTCOND*/BIGGEST(sizeof (struct file_analysis),
	    sizeof tzdirslash + 1024)];
};

/* Load tz data from the file named NAME into *SP.  Read extended
   format if DOEXTEND.  Use *LSP for temporary storage.  Return 0 on
   success, an errno value on failure.  */

static int
tzloadbody1(char const *name, struct state *sp, BOOL doextend,
  union local_storage *lsp, ssize_t nread)
{
  int			i;
  int			stored;
  union input_buffer	*up = &lsp->u.u;
  size_t		tzheadsize = sizeof(struct tzhead);

  for (stored = 4; stored <= 8; stored *= 2)
    {
      int_fast32_t ttisstdcnt = detzcode(up->tzhead.tzh_ttisstdcnt);
      int_fast32_t ttisutcnt = detzcode(up->tzhead.tzh_ttisutcnt);
      int_fast64_t prevtr = 0;
      int_fast32_t prevcorr = 0;
      int_fast32_t leapcnt = detzcode(up->tzhead.tzh_leapcnt);
      int_fast32_t timecnt = detzcode(up->tzhead.tzh_timecnt);
      int_fast32_t typecnt = detzcode(up->tzhead.tzh_typecnt);
      int_fast32_t charcnt = detzcode(up->tzhead.tzh_charcnt);
      char const *p = up->buf + tzheadsize;
      /* Although tzfile(5) currently requires typecnt to be nonzero,
	 support future formats that may allow zero typecnt
	 in files that have a TZ string and no transitions.  */
      if (! (0 <= leapcnt && leapcnt < TZ_MAX_LEAPS
	     && 0 <= typecnt && typecnt < TZ_MAX_TYPES
	     && 0 <= timecnt && timecnt < TZ_MAX_TIMES
	     && 0 <= charcnt && charcnt < TZ_MAX_CHARS
	     && (ttisstdcnt == typecnt || ttisstdcnt == 0)
	     && (ttisutcnt == typecnt || ttisutcnt == 0)))
	return EINVAL;
      if ((size_t)nread
	  < (tzheadsize		/* struct tzhead */
	     + timecnt * stored	/* ats */
	     + timecnt		/* types */
	     + typecnt * 6		/* _ttinfos */
	     + charcnt		/* chars */
	     + leapcnt * (stored + 4)	/* lsinfos */
	     + ttisstdcnt		/* ttisstds */
	     + ttisutcnt))		/* ttisuts */
	return EINVAL;
      sp->leapcnt = leapcnt;
      sp->timecnt = timecnt;
      sp->typecnt = typecnt;
      sp->charcnt = charcnt;

      /* Read transitions, discarding those out of time_t range.
	 But pretend the last transition before TIME_T_MIN
	 occurred at TIME_T_MIN.  */
      timecnt = 0;
      for (i = 0; i < sp->timecnt; ++i) {
	      int_fast64_t at
		= stored == 4 ? detzcode(p) : detzcode64(p);
	      sp->types[i] = at <= TIME_T_MAX;
	      if (sp->types[i]) {
		      time_t attime
			  = ((TYPE_SIGNED(time_t) ?
			  at < TIME_T_MIN : at < 0)
			  ? TIME_T_MIN : (time_t)at);
		      if (timecnt && attime <= sp->ats[timecnt - 1]) {
			      if (attime < sp->ats[timecnt - 1])
				      return EINVAL;
			      sp->types[i - 1] = 0;
			      timecnt--;
		      }
		      sp->ats[timecnt++] = attime;
	      }
	      p += stored;
      }

      timecnt = 0;
      for (i = 0; i < sp->timecnt; ++i) {
	      unsigned char typ = *p++;
	      if (sp->typecnt <= typ)
		return EINVAL;
	      if (sp->types[i])
		      sp->types[timecnt++] = typ;
      }
      sp->timecnt = timecnt;
      for (i = 0; i < sp->typecnt; ++i) {
	      struct _ttinfo *	ttisp;
	      unsigned char isdst, desigidx;

	      ttisp = &sp->ttis[i];
	      ttisp->tt_utoff = detzcode(p);
	      p += 4;
	      isdst = *p++;
	      if (! (isdst < 2))
		      return EINVAL;
	      ttisp->tt_isdst = isdst;
	      desigidx = *p++;
	      if (! (desigidx < sp->charcnt))
		      return EINVAL;
	      ttisp->tt_desigidx = desigidx;
      }
      for (i = 0; i < sp->charcnt; ++i)
	      sp->chars[i] = *p++;
      sp->chars[i] = '\0';	/* ensure '\0' at end */

      /* Read leap seconds, discarding those out of time_t range.  */
      leapcnt = 0;
      for (i = 0; i < sp->leapcnt; ++i) {
	      int_fast64_t tr = stored == 4 ? detzcode(p) :
		  detzcode64(p);
	      int_fast32_t corr = detzcode(p + stored);
	      p += stored + 4;
	      /* Leap seconds cannot occur before the Epoch.  */
	      if (tr < 0)
		      return EINVAL;
	      if (tr <= TIME_T_MAX) {
	  /* Leap seconds cannot occur more than once per UTC month,
	     and UTC months are at least 28 days long (minus 1
	     second for a negative leap second).  Each leap second's
	     correction must differ from the previous one's by 1
	     second.  */
		      if (tr - prevtr < 28 * SECSPERDAY - 1
			  || (corr != prevcorr - 1
			  && corr != prevcorr + 1))
				return EINVAL;

		      sp->lsis[leapcnt].ls_trans =
			  (time_t)(prevtr = tr);
		      sp->lsis[leapcnt].ls_corr = prevcorr = corr;
		      leapcnt++;
	      }
      }
      sp->leapcnt = leapcnt;

      for (i = 0; i < sp->typecnt; ++i) {
	      struct _ttinfo *	ttisp;

	      ttisp = &sp->ttis[i];
	      if (ttisstdcnt == 0)
		      ttisp->tt_ttisstd = false;
	      else {
		      if (*p != true && *p != false)
			return EINVAL;
		      ttisp->tt_ttisstd = *p++;
	      }
      }
      for (i = 0; i < sp->typecnt; ++i) {
	      struct _ttinfo *	ttisp;

	      ttisp = &sp->ttis[i];
	      if (ttisutcnt == 0)
		      ttisp->tt_ttisut = false;
	      else {
		      if (*p != true && *p != false)
				      return EINVAL;
		      ttisp->tt_ttisut = *p++;
	      }
      }
      /*
      ** If this is an old file, we're done.
      */
      if (up->tzhead.tzh_version[0] == '\0')
	      break;
      nread -= p - up->buf;
      memmove(up->buf, p, (size_t)nread);
    }
  if (doextend && nread > 2
    && up->buf[0] == '\n' && up->buf[nread - 1] == '\n'
    && sp->typecnt + 2 <= TZ_MAX_TYPES)
    {
      struct state *ts = &lsp->u.st;

      up->buf[nread - 1] = '\0';
      if (tzparse(&up->buf[1], ts, false))
	{

	  /* Attempt to reuse existing abbreviations.
	     Without this, America/Anchorage would be right on
	     the edge after 2037 when TZ_MAX_CHARS is 50, as
	     sp->charcnt equals 40 (for LMT AST AWT APT AHST
	     AHDT YST AKDT AKST) and ts->charcnt equals 10
	     (for AKST AKDT).  Reusing means sp->charcnt can
	     stay 40 in this example.  */
	  int gotabbr = 0;
	  int charcnt = sp->charcnt;
	  for (i = 0; i < ts->typecnt; i++) {
	    char *tsabbr = ts->chars + ts->ttis[i].tt_desigidx;
	    int j;
	    for (j = 0; j < charcnt; j++)
	      if (strcmp(sp->chars + j, tsabbr) == 0) {
		ts->ttis[i].tt_desigidx = j;
		gotabbr++;
		break;
	      }
	    if (! (j < charcnt)) {
	      size_t tsabbrlen = strlen(tsabbr);
	      if (j + tsabbrlen < TZ_MAX_CHARS) {
		strcpy(sp->chars + j, tsabbr);
		charcnt = (int_fast32_t)(j + tsabbrlen + 1);
		ts->ttis[i].tt_desigidx = j;
		gotabbr++;
	      }
	    }
	  }
	  if (gotabbr == ts->typecnt)
	    {
	      sp->charcnt = charcnt;

	      /* Ignore any trailing, no-op transitions generated
		 by zic as they don't help here and can run afoul
		 of bugs in zic 2016j or earlier.  */
	      while (1 < sp->timecnt
		     && (sp->types[sp->timecnt - 1]
			 == sp->types[sp->timecnt - 2]))
		sp->timecnt--;

	      for (i = 0; i < ts->timecnt; i++)
		if (sp->timecnt == 0
		    || (sp->ats[sp->timecnt - 1]
			< ts->ats[i] + leapcorr(sp, ts->ats[i])))
		  break;
	      while (i < ts->timecnt
		     && sp->timecnt < TZ_MAX_TIMES) {
		sp->ats[sp->timecnt] = (time_t)
		  (ts->ats[i] + leapcorr(sp, ts->ats[i]));
		sp->types[sp->timecnt] = (sp->typecnt
					  + ts->types[i]);
		sp->timecnt++;
		i++;
	      }
	      for (i = 0; i < ts->typecnt; i++)
		sp->ttis[sp->typecnt++] = ts->ttis[i];
	    }
	}
    }
  if (sp->typecnt == 0)
    return EINVAL;
  if (sp->timecnt > 1)
    {
      for (i = 1; i < sp->timecnt; ++i)
	{
	  if (typesequiv(sp, sp->types[i], sp->types[0]))
	    {
	      if (differ_by_repeat(sp->ats[i], sp->ats[0]))
		{
		  sp->goback = true;
		  break;
		}
	    }
	}
      for (i = sp->timecnt - 2; i >= 0; --i)
	{
	  if (typesequiv(sp, sp->types[sp->timecnt - 1], sp->types[i]))
	    {
	      if (differ_by_repeat(sp->ats[sp->timecnt - 1], sp->ats[i]))
		{
		  sp->goahead = true;
		  break;
		}
	    }
	}
    }

  /* Infer sp->defaulttype from the data.  Although this default
     type is always zero for data from recent tzdb releases,
     things are trickier for data from tzdb 2018e or earlier.

     The first set of heuristics work around bugs in 32-bit data
     generated by tzdb 2013c or earlier.  The workaround is for
     zones like Australia/Macquarie where timestamps before the
     first transition have a time type that is not the earliest
     standard-time type.  See:
     https://mm.icann.org/pipermail/tz/2013-May/019368.html */
  /*
  ** If type 0 is unused in transitions,
  ** it's the type to use for early times.
  */
  for (i = 0; i < sp->timecnt; ++i)
	  if (sp->types[i] == 0)
		  break;
  i = i < sp->timecnt ? -1 : 0;
  /*
  ** Absent the above,
  ** if there are transition times
  ** and the first transition is to a daylight time
  ** find the standard type less than and closest to
  ** the type of the first transition.
  */
  if (i < 0 && sp->timecnt > 0 && sp->ttis[sp->types[0]].tt_isdst) {
	  i = sp->types[0];
	  while (--i >= 0)
		  if (!sp->ttis[i].tt_isdst)
			  break;
  }
  /* The next heuristics are for data generated by tzdb 2018e or
     earlier, for zones like EST5EDT where the first transition
     is to DST.  */
  /*
  ** If no result yet, find the first standard type.
  ** If there is none, punt to type zero.
  */
  if (i < 0) {
	  i = 0;
	  while (sp->ttis[i].tt_isdst)
		  if (++i >= sp->typecnt) {
			  i = 0;
			  break;
		  }
  }
  /* A simple 'sp->defaulttype = 0;' would suffice here if we
     didn't have to worry about 2018e-or-earlier data.  Even
     simpler would be to remove the defaulttype member and just
     use 0 in its place.  */
  sp->defaulttype = i;

  return 0;
}

static int
tzloadbody(char const *name, struct state *sp, BOOL doextend,
  union local_storage *lsp)
{
	int			fid;
	ssize_t			nread;
	BOOL			doaccess;
	union input_buffer	*up = &lsp->u.u;
	size_t			tzheadsize = sizeof(struct tzhead);

	sp->goback = sp->goahead = false;

	if (! name) {
		name = TZDEFAULT;
		if (! name)
			return EINVAL;
	}

	if (name[0] == ':')
		++name;

	doaccess = name[0] == '/';

	if (!doaccess) {
		char const *dot;
		size_t namelen = strlen(name);
		if (sizeof lsp->fullname - sizeof tzdirslash <= namelen)
			return ENAMETOOLONG;

		/* Create a string "TZDIR/NAME".  Using sprintf here
		   would pull in stdio (and would fail if the
		   resulting string length exceeded INT_MAX!).  */
		memcpy(lsp->fullname, tzdirslash, sizeof tzdirslash);
		strcpy(lsp->fullname + sizeof tzdirslash, name);

		/* Set doaccess if NAME contains a ".." file name
		   component, as such a name could read a file outside
		   the TZDIR virtual subtree.  */
		for (dot = name; (dot = strchr(dot, '.')) != NULL; dot++)
		  if ((dot == name || dot[-1] == '/') && dot[1] == '.'
		      && (dot[2] == '/' || !dot[2])) {
		    doaccess = true;
		    break;
		  }

		name = lsp->fullname;
	}
	if (doaccess && access(name, R_OK) != 0)
		return errno;

	fid = open(name, OPEN_MODE);
	if (fid < 0)
		return errno;
	nread = read(fid, up->buf, sizeof up->buf);
	if (nread < (ssize_t)tzheadsize) {
		int err = nread < 0 ? errno : EINVAL;
		close(fid);
		return err;
	}
	if (close(fid) < 0)
		return errno;

	return tzloadbody1(name, sp, doextend, lsp, nread);
}

/* Load tz data from the file named NAME into *SP.  Read extended
   format if DOEXTEND.  Return 0 on success, an errno value on failure.  */
static int
tzload(char const *name, struct state *sp, BOOL doextend)
{
  union local_storage *lsp = malloc(sizeof *lsp);

  if (!lsp)
    {
      return errno;
    }
  else
    {
      int err = tzloadbody(name, sp, doextend, lsp);
      free(lsp);
      return err;
    }
}

static BOOL
typesequiv(const struct state *sp, int a, int b)
{
	BOOL result;

	if (sp == NULL ||
		a < 0 || a >= sp->typecnt ||
		b < 0 || b >= sp->typecnt)
			result = false;
	else {
		const struct _ttinfo *	ap = &sp->ttis[a];
		const struct _ttinfo *	bp = &sp->ttis[b];
		result = (ap->tt_utoff == bp->tt_utoff
			  && ap->tt_isdst == bp->tt_isdst
			  && ap->tt_ttisstd == bp->tt_ttisstd
			  && ap->tt_ttisut == bp->tt_ttisut
			  && (strcmp(&sp->chars[ap->tt_desigidx],
				     &sp->chars[bp->tt_desigidx])
			      == 0));
	}
	return result;
}

static const int	mon_lengths[2][MONSPERYEAR] = {
	{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
	{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
};

static const int	year_lengths[2] = {
	DAYSPERNYEAR, DAYSPERLYEAR
};

/*
** Given a pointer into a timezone string, scan until a character that is not
** a valid character in a time zone abbreviation is found.
** Return a pointer to that character.
*/

static ATTRIBUTE_PURE const char *
getzname(const char *strp)
{
	char	c;

	while ((c = *strp) != '\0' && !is_digit(c) && c != ',' && c != '-' &&
		c != '+')
			++strp;
	return strp;
}

/*
** Given a pointer into an extended timezone string, scan until the ending
** delimiter of the time zone abbreviation is located.
** Return a pointer to the delimiter.
**
** As with getzname above, the legal character set is actually quite
** restricted, with other characters producing undefined results.
** We don't do any checking here; checking is done later in common-case code.
*/

static ATTRIBUTE_PURE const char *
getqzname(const char *strp, const int delim)
{
	int	c;

	while ((c = *strp) != '\0' && c != delim)
		++strp;
	return strp;
}

/*
** Given a pointer into a timezone string, extract a number from that string.
** Check that the number is within a specified range; if it is not, return
** NULL.
** Otherwise, return a pointer to the first character not part of the number.
*/

static const char *
getnum(const char *strp, int *const nump, const int min, const int max)
{
	char	c;
	int	num;

	if (strp == NULL || !is_digit(c = *strp)) {
		errno = EINVAL;
		return NULL;
	}
	num = 0;
	do {
		num = num * 10 + (c - '0');
		if (num > max) {
			errno = EOVERFLOW;
			return NULL;	/* illegal value */
		}
		c = *++strp;
	} while (is_digit(c));
	if (num < min) {
		errno = EINVAL;
		return NULL;		/* illegal value */
	}
	*nump = num;
	return strp;
}

/*
** Given a pointer into a timezone string, extract a number of seconds,
** in hh[:mm[:ss]] form, from the string.
** If any error occurs, return NULL.
** Otherwise, return a pointer to the first character not part of the number
** of seconds.
*/

static const char *
getsecs(const char *strp, int_fast32_t *const secsp)
{
	int	num;

	/*
	** 'HOURSPERDAY * DAYSPERWEEK - 1' allows quasi-Posix rules like
	** "M10.4.6/26", which does not conform to Posix,
	** but which specifies the equivalent of
	** "02:00 on the first Sunday on or after 23 Oct".
	*/
	strp = getnum(strp, &num, 0, HOURSPERDAY * DAYSPERWEEK - 1);
	if (strp == NULL)
		return NULL;
	*secsp = num * (int_fast32_t) SECSPERHOUR;
	if (*strp == ':') {
		++strp;
		strp = getnum(strp, &num, 0, MINSPERHOUR - 1);
		if (strp == NULL)
			return NULL;
		*secsp += num * SECSPERMIN;
		if (*strp == ':') {
			++strp;
			/* 'SECSPERMIN' allows for leap seconds.  */
			strp = getnum(strp, &num, 0, SECSPERMIN);
			if (strp == NULL)
				return NULL;
			*secsp += num;
		}
	}
	return strp;
}

/*
** Given a pointer into a timezone string, extract an offset, in
** [+-]hh[:mm[:ss]] form, from the string.
** If any error occurs, return NULL.
** Otherwise, return a pointer to the first character not part of the time.
*/

static const char *
getoffset(const char *strp, int_fast32_t *const offsetp)
{
	BOOL neg = false;

	if (*strp == '-') {
		neg = true;
		++strp;
	} else if (*strp == '+')
		++strp;
	strp = getsecs(strp, offsetp);
	if (strp == NULL)
		return NULL;		/* illegal time */
	if (neg)
		*offsetp = -*offsetp;
	return strp;
}

/*
** Given a pointer into a timezone string, extract a rule in the form
** date[/time]. See POSIX section 8 for the format of "date" and "time".
** If a valid rule is not found, return NULL.
** Otherwise, return a pointer to the first character not part of the rule.
*/

static const char *
getrule(const char *strp, struct rule *const rulep)
{
	if (*strp == 'J') {
		/*
		** Julian day.
		*/
		rulep->r_type = JULIAN_DAY;
		++strp;
		strp = getnum(strp, &rulep->r_day, 1, DAYSPERNYEAR);
	} else if (*strp == 'M') {
		/*
		** Month, week, day.
		*/
		rulep->r_type = MONTH_NTH_DAY_OF_WEEK;
		++strp;
		strp = getnum(strp, &rulep->r_mon, 1, MONSPERYEAR);
		if (strp == NULL)
			return NULL;
		if (*strp++ != '.')
			return NULL;
		strp = getnum(strp, &rulep->r_week, 1, 5);
		if (strp == NULL)
			return NULL;
		if (*strp++ != '.')
			return NULL;
		strp = getnum(strp, &rulep->r_day, 0, DAYSPERWEEK - 1);
	} else if (is_digit(*strp)) {
		/*
		** Day of year.
		*/
		rulep->r_type = DAY_OF_YEAR;
		strp = getnum(strp, &rulep->r_day, 0, DAYSPERLYEAR - 1);
	} else	return NULL;		/* invalid format */
	if (strp == NULL)
		return NULL;
	if (*strp == '/') {
		/*
		** Time specified.
		*/
		++strp;
		strp = getoffset(strp, &rulep->r_time);
	} else	rulep->r_time = 2 * SECSPERHOUR;	/* default = 2:00:00 */
	return strp;
}

/*
** Given a year, a rule, and the offset from UT at the time that rule takes
** effect, calculate the year-relative time that rule takes effect.
*/

static int_fast32_t
transtime(const int year, const struct rule *const rulep,
	  const int_fast32_t offset)
{
	BOOL	leapyear;
	int_fast32_t value;
	int	i;
	int		d, m1, yy0, yy1, yy2, dow;

	INITIALIZE(value);
	leapyear = isleap(year);
	switch (rulep->r_type) {

	case JULIAN_DAY:
		/*
		** Jn - Julian day, 1 == January 1, 60 == March 1 even in leap
		** years.
		** In non-leap years, or if the day number is 59 or less, just
		** add SECSPERDAY times the day number-1 to the time of
		** January 1, midnight, to get the day.
		*/
		value = (rulep->r_day - 1) * SECSPERDAY;
		if (leapyear && rulep->r_day >= 60)
			value += SECSPERDAY;
		break;

	case DAY_OF_YEAR:
		/*
		** n - day of year.
		** Just add SECSPERDAY times the day number to the time of
		** January 1, midnight, to get the day.
		*/
		value = rulep->r_day * SECSPERDAY;
		break;

	case MONTH_NTH_DAY_OF_WEEK:
		/*
		** Mm.n.d - nth "dth day" of month m.
		*/

		/*
		** Use Zeller's Congruence to get day-of-week of first day of
		** month.
		*/
		m1 = (rulep->r_mon + 9) % 12 + 1;
		yy0 = (rulep->r_mon <= 2) ? (year - 1) : year;
		yy1 = yy0 / 100;
		yy2 = yy0 % 100;
		dow = ((26 * m1 - 2) / 10 +
			1 + yy2 + yy2 / 4 + yy1 / 4 - 2 * yy1) % 7;
		if (dow < 0)
			dow += DAYSPERWEEK;

		/*
		** "dow" is the day-of-week of the first day of the month. Get
		** the day-of-month (zero-origin) of the first "dow" day of the
		** month.
		*/
		d = rulep->r_day - dow;
		if (d < 0)
			d += DAYSPERWEEK;
		for (i = 1; i < rulep->r_week; ++i) {
			if (d + DAYSPERWEEK >=
				mon_lengths[leapyear][rulep->r_mon - 1])
					break;
			d += DAYSPERWEEK;
		}

		/*
		** "d" is the day-of-month (zero-origin) of the day we want.
		*/
		value = d * SECSPERDAY;
		for (i = 0; i < rulep->r_mon - 1; ++i)
			value += mon_lengths[leapyear][i] * SECSPERDAY;
		break;
	}

	/*
	** "value" is the year-relative time of 00:00:00 UT on the day in
	** question. To get the year-relative time of the specified local
	** time on that day, add the transition time and the current offset
	** from UT.
	*/
	return value + rulep->r_time + offset;
}

/*
** Given a POSIX section 8-style TZ string, fill in the rule tables as
** appropriate.
*/

//#define	DEB(X) fprintf(stderr, "tzparse %d\n", X);
#define	DEB(X) 
static BOOL
tzparse(const char *name, struct state *sp, BOOL lastditch)
{
  const char 	*stdname;
  const char 	*dstname;
  size_t	stdlen;
  size_t	dstlen;
  size_t	charcnt;
  int_fast32_t	stdoffset;
  int_fast32_t	dstoffset;
  char		*cp;
  BOOL		load_ok;

  DEB(1)
  dstname = NULL; /* XXX gcc */
  stdname = name;
  if (lastditch) {
	  stdlen = sizeof "GMT" - 1;
	  name += stdlen;
	  stdoffset = 0;
  } else {
	  if (*name == '<') {
		  name++;
		  stdname = name;
		  name = getqzname(name, '>');
		  if (*name != '>')
		    {
		      DEB(2)
		      return false;
		    }
		  stdlen = name - stdname;
		  name++;
	  } else {
		  name = getzname(name);
		  stdlen = name - stdname;
	  }
	  if (!stdlen)
	    {
	      DEB(3)
	      return false;
	    }
	  name = getoffset(name, &stdoffset);
	  if (name == NULL)
	    {
	      DEB(4)
	      return false;
	    }
  }
  charcnt = stdlen + 1;
  if (sizeof sp->chars < charcnt)
    {
      DEB(5)
      return false;
    }
  load_ok = tzload(TZDEFRULES, sp, false) == 0;
  if (!load_ok)
	  sp->leapcnt = 0;		/* so, we're off a little */
  if (*name != '\0') {
	  if (*name == '<') {
		  dstname = ++name;
		  name = getqzname(name, '>');
		  if (*name != '>')
		    {
		      DEB(6)
		      return false;
		    }
		  dstlen = name - dstname;
		  name++;
	  } else {
		  dstname = name;
		  name = getzname(name);
		  dstlen = name - dstname; /* length of DST abbr. */
	  }
	  if (!dstlen)
	    {
	      DEB(7)
	      return false;
	    }
	  charcnt += dstlen + 1;
	  if (sizeof sp->chars < charcnt)
	    {
	      DEB(8)
	      return false;
	    }
	  if (*name != '\0' && *name != ',' && *name != ';') {
		  name = getoffset(name, &dstoffset);
		  if (name == NULL)
		    {
		      DEB(9)
		      return false;
		    }
	  } else	dstoffset = stdoffset - SECSPERHOUR;
	  if (*name == '\0' && !load_ok)
		  name = TZDEFRULESTRING;
	  if (*name == ',' || *name == ';') {
		  struct rule	start;
		  struct rule	end;
		  int		year;
		  int		yearlim;
		  int		timecnt;
		  time_t	janfirst;
		  int_fast32_t	janoffset = 0;
		  int yearbeg;

		  ++name;
		  if ((name = getrule(name, &start)) == NULL)
		    {
		      DEB(10)
		      return false;
		    }
		  if (*name++ != ',')
		    {
		      DEB(11)
		      return false;
		    }
		  if ((name = getrule(name, &end)) == NULL)
		    {
		      DEB(12)
		      return false;
		    }
		  if (*name != '\0')
		    {
		      DEB(13)
		      return false;
		    }
		  sp->typecnt = 2;	/* standard time and DST */
		  /*
		  ** Two transitions per year, from EPOCH_YEAR forward.
		  */
		  init_ttinfo(&sp->ttis[0], -stdoffset, false, 0);
		  init_ttinfo(&sp->ttis[1], -dstoffset, true, 
		      (int)(stdlen + 1));
		  sp->defaulttype = 0;
		  timecnt = 0;
		  janfirst = 0;
		  yearbeg = EPOCH_YEAR;

		  do {
		    int_fast32_t yearsecs
		      = year_lengths[isleap(yearbeg - 1)] * SECSPERDAY;
		    yearbeg--;
		    if (increment_overflow_time(&janfirst, -yearsecs)) {
		      janoffset = -yearsecs;
		      break;
		    }
		  } while (EPOCH_YEAR - YEARSPERREPEAT / 2 < yearbeg);

		  yearlim = yearbeg + YEARSPERREPEAT + 1;
		  for (year = yearbeg; year < yearlim; year++) {
			  int_fast32_t
			    starttime = transtime(year, &start, stdoffset),
			    endtime = transtime(year, &end, dstoffset);
			  int_fast32_t
			    yearsecs = (year_lengths[isleap(year)]
					* SECSPERDAY);
			  BOOL reversed = endtime < starttime;
			  if (reversed) {
				  int_fast32_t swap = starttime;
				  starttime = endtime;
				  endtime = swap;
			  }
			  if (reversed
			      || (starttime < endtime
				  && (endtime - starttime
				      < (yearsecs
					 + (stdoffset - dstoffset))))) {
				  if (TZ_MAX_TIMES - 2 < timecnt)
					  break;
				  sp->ats[timecnt] = janfirst;
				  if (! increment_overflow_time
				      (&sp->ats[timecnt],
				       janoffset + starttime))
				    sp->types[timecnt++] = !reversed;
				  sp->ats[timecnt] = janfirst;
				  if (! increment_overflow_time
				      (&sp->ats[timecnt],
				       janoffset + endtime)) {
				    sp->types[timecnt++] = reversed;
				    yearlim = year + YEARSPERREPEAT + 1;
				  }
			  }
			  if (increment_overflow_time
			      (&janfirst, janoffset + yearsecs))
				  break;
			  janoffset = 0;
		  }
		  sp->timecnt = timecnt;
		  if (! timecnt) {
			  sp->ttis[0] = sp->ttis[1];
			  sp->typecnt = 1;	/* Perpetual DST.  */
		  } else if (YEARSPERREPEAT < year - yearbeg)
			  sp->goback = sp->goahead = true;
	  } else {
		  int_fast32_t	theirstdoffset;
		  int_fast32_t	theirdstoffset;
		  int_fast32_t	theiroffset;
		  BOOL		isdst;
		  int		i;
		  int		j;

		  if (*name != '\0')
		    {
		      DEB(14)
		      return false;
		    }
		  /*
		  ** Initial values of theirstdoffset and theirdstoffset.
		  */
		  theirstdoffset = 0;
		  for (i = 0; i < sp->timecnt; ++i) {
			  j = sp->types[i];
			  if (!sp->ttis[j].tt_isdst) {
				  theirstdoffset =
					  - sp->ttis[j].tt_utoff;
				  break;
			  }
		  }
		  theirdstoffset = 0;
		  for (i = 0; i < sp->timecnt; ++i) {
			  j = sp->types[i];
			  if (sp->ttis[j].tt_isdst) {
				  theirdstoffset =
					  - sp->ttis[j].tt_utoff;
				  break;
			  }
		  }
		  /*
		  ** Initially we're assumed to be in standard time.
		  */
		  isdst = false;
		  /*
		  ** Now juggle transition times and types
		  ** tracking offsets as you do.
		  */
		  for (i = 0; i < sp->timecnt; ++i) {
			  j = sp->types[i];
			  sp->types[i] = sp->ttis[j].tt_isdst;
			  if (sp->ttis[j].tt_ttisut) {
				  /* No adjustment to transition time */
			  } else {
				  /*
				  ** If daylight saving time is in
				  ** effect, and the transition time was
				  ** not specified as standard time, add
				  ** the daylight saving time offset to
				  ** the transition time; otherwise, add
				  ** the standard time offset to the
				  ** transition time.
				  */
				  /*
				  ** Transitions from DST to DDST
				  ** will effectively disappear since
				  ** POSIX provides for only one DST
				  ** offset.
				  */
				  if (isdst && !sp->ttis[j].tt_ttisstd) {
					  sp->ats[i] += (time_t)
					      (dstoffset - theirdstoffset);
				  } else {
					  sp->ats[i] += (time_t)
					      (stdoffset - theirstdoffset);
				  }
			  }
			  theiroffset = -sp->ttis[j].tt_utoff;
			  if (sp->ttis[j].tt_isdst)
				  theirstdoffset = theiroffset;
			  else	theirdstoffset = theiroffset;
		  }
		  /*
		  ** Finally, fill in ttis.
		  */
		  init_ttinfo(&sp->ttis[0], -stdoffset, false, 0);
		  init_ttinfo(&sp->ttis[1], -dstoffset, true,
		      (int)(stdlen + 1));
		  sp->typecnt = 2;
		  sp->defaulttype = 0;
	  }
  } else {
	  dstlen = 0;
	  sp->typecnt = 1;		/* only standard time */
	  sp->timecnt = 0;
	  init_ttinfo(&sp->ttis[0], -stdoffset, false, 0);
	  init_ttinfo(&sp->ttis[1], 0, false, 0);
	  sp->defaulttype = 0;
  }
  sp->charcnt = (int)charcnt;
  cp = sp->chars;
  (void) memcpy(cp, stdname, stdlen);
  cp += stdlen;
  *cp++ = '\0';
  if (dstlen != 0) {
	  (void) memcpy(cp, dstname, dstlen);
	  *(cp + dstlen) = '\0';
  }
  DEB(15);
  return true;
}

/*
** The easy way to behave "as if no library function calls" localtime
** is to not call it, so we drop its guts into "localsub", which can be
** freely called. (And no, the PANS doesn't require the above behavior,
** but it *is* desirable.)
**
*/

/*ARGSUSED*/
static gstm *
localsub(struct state const *sp, time_t const *timep, int_fast32_t setname,
	 gstm *const tmp)
{
  const struct _ttinfo	*ttisp;
  int			i;
  gstm 		*result;
  const time_t		t = *timep;

  if ((sp->goback && t < sp->ats[0])
    || (sp->goahead && t > sp->ats[sp->timecnt - 1]))
    {
      time_t	newt = t;
      time_t	seconds;
      time_t	years;

      if (t < sp->ats[0])
	seconds = sp->ats[0] - t;
      else
	seconds = t - sp->ats[sp->timecnt - 1];
      --seconds;
      years = (time_t)((seconds / SECSPERREPEAT + 1) * YEARSPERREPEAT);
      seconds = (time_t)(years * AVGSECSPERYEAR);
      if (t < sp->ats[0])
	newt += seconds;
      else
	newt -= seconds;
      if (newt < sp->ats[0] || newt > sp->ats[sp->timecnt - 1])
	{
	  errno = EINVAL;
	  return NULL;	/* "cannot happen" */
	}
      result = localsub(sp, &newt, setname, tmp);
      if (result)
	{
	  int_fast64_t newy;

	  newy = result->tm_year;
	  if (t < sp->ats[0])
	    {
	      newy -= years;
	    }
	  else
	    {
	      newy += years;
	    }
	  if (! (INT_MIN <= newy && newy <= INT_MAX))
	    {
	      errno = EOVERFLOW;
	      return NULL;
	    }
	  result->tm_year = (int)newy;
	}
      return result;
    }
  if (sp->timecnt == 0 || t < sp->ats[0])
    {
      i = sp->defaulttype;
    }
  else
    {
      int	lo = 1;
      int	hi = sp->timecnt;

      while (lo < hi)
	{
	  int	mid = (lo + hi) / 2;

	  if (t < sp->ats[mid])
	    {
	      hi = mid;
	    }
	  else
	    {
	      lo = mid + 1;
	    }
	}
      i = (int) sp->types[lo - 1];
    }
  ttisp = &sp->ttis[i];
  /*
  ** To get (wrong) behavior that's compatible with System V Release 2.0
  ** you'd replace the statement below with
  **	t += ttisp->tt_utoff;
  **	timesub(&t, 0L, sp, tmp);
  */
  result = timesub(&t, ttisp->tt_utoff, sp, tmp);
  if (result)
    {
      result->tm_isdst = ttisp->tt_isdst;
      result->tm_zone = __UNCONST(&sp->chars[ttisp->tt_desigidx]);
    }
  return result;
}



/*
** Return the number of leap years through the end of the given year
** where, to make the math easy, the answer for year zero is defined as zero.
*/
static int
leaps_thru_end_of_nonneg(int y)
{
	return y / 4 - y / 100 + y / 400;
}

static int ATTRIBUTE_PURE
leaps_thru_end_of(const int y)
{
	return (y < 0
		? -1 - leaps_thru_end_of_nonneg(-1 - y)
		: leaps_thru_end_of_nonneg(y));
}

static gstm *
timesub(const time_t *timep, int_fast32_t offset,
    const struct state *sp, gstm *tmp)
{
  const struct lsinfo *	lp;
  time_t		tdays;
  int			idays;	/* unsigned would be so 2003 */
  int_fast64_t		rem;
  int			y;
  const int *		ip;
  int_fast64_t		corr;
  int			hit;
  int			i;

  corr = 0;
  hit = false;
  i = (sp == NULL) ? 0 : sp->leapcnt;
  while (--i >= 0) {
	  lp = &sp->lsis[i];
	  if (*timep >= lp->ls_trans) {
		  corr = lp->ls_corr;
		  hit = (*timep == lp->ls_trans
			 && (i == 0 ? 0 : lp[-1].ls_corr) < corr);
		  break;
	  }
  }
  y = EPOCH_YEAR;
  tdays = (time_t)(*timep / SECSPERDAY);
  rem = *timep % SECSPERDAY;
  while (tdays < 0 || tdays >= year_lengths[isleap(y)]) {
	  int		newy;
	  time_t	tdelta;
	  int	idelta;
	  int	leapdays;

	  tdelta = tdays / DAYSPERLYEAR;
	  if (! ((! TYPE_SIGNED(time_t) || INT_MIN <= tdelta)
		 && tdelta <= INT_MAX))
		  goto out_of_range;
	  _DIAGASSERT(__type_fit(int, tdelta));
	  idelta = (int)tdelta;
	  if (idelta == 0)
		  idelta = (tdays < 0) ? -1 : 1;
	  newy = y;
	  if (increment_overflow(&newy, idelta))
		  goto out_of_range;
	  leapdays = leaps_thru_end_of(newy - 1) -
		  leaps_thru_end_of(y - 1);
	  tdays -= ((time_t) newy - y) * DAYSPERNYEAR;
	  tdays -= leapdays;
	  y = newy;
  }
  /*
  ** Given the range, we can now fearlessly cast...
  */
  idays = (int) tdays;
  rem += offset - corr;
  while (rem < 0) {
	  rem += SECSPERDAY;
	  --idays;
  }
  while (rem >= SECSPERDAY) {
	  rem -= SECSPERDAY;
	  ++idays;
  }
  while (idays < 0) {
	  if (increment_overflow(&y, -1))
		  goto out_of_range;
	  idays += year_lengths[isleap(y)];
  }
  while (idays >= year_lengths[isleap(y)]) {
	  idays -= year_lengths[isleap(y)];
	  if (increment_overflow(&y, 1))
		  goto out_of_range;
  }
  tmp->tm_year = y;
  if (increment_overflow(&tmp->tm_year, -TM_YEAR_BASE))
	  goto out_of_range;
  tmp->tm_yday = idays;
  /*
  ** The "extra" mods below avoid overflow problems.
  */
  tmp->tm_wday = EPOCH_WDAY +
	  ((y - EPOCH_YEAR) % DAYSPERWEEK) *
	  (DAYSPERNYEAR % DAYSPERWEEK) +
	  leaps_thru_end_of(y - 1) -
	  leaps_thru_end_of(EPOCH_YEAR - 1) +
	  idays;
  tmp->tm_wday %= DAYSPERWEEK;
  if (tmp->tm_wday < 0)
	  tmp->tm_wday += DAYSPERWEEK;
  tmp->tm_hour = (int) (rem / SECSPERHOUR);
  rem %= SECSPERHOUR;
  tmp->tm_min = (int) (rem / SECSPERMIN);
  /*
  ** A positive leap second requires a special
  ** representation. This uses "... ??:59:60" et seq.
  */
  tmp->tm_sec = (int) (rem % SECSPERMIN) + hit;
  ip = mon_lengths[isleap(y)];
  for (tmp->tm_mon = 0; idays >= ip[tmp->tm_mon]; ++(tmp->tm_mon))
	  idays -= ip[tmp->tm_mon];
  tmp->tm_mday = (int) (idays + 1);
  tmp->tm_isdst = 0;
  tmp->tm_gmtoff = offset;
  return tmp;
out_of_range:
  errno = EOVERFLOW;
  return NULL;
}



#ifndef WRONG
#define WRONG	((time_t)-1)
#endif /* !defined WRONG */

/*
** Normalize logic courtesy Paul Eggert.
*/

static BOOL
increment_overflow(int *ip, int j)
{
	int const	i = *ip;

	/*
	** If i >= 0 there can only be overflow if i + j > INT_MAX
	** or if j > INT_MAX - i; given i >= 0, INT_MAX - i cannot overflow.
	** If i < 0 there can only be overflow if i + j < INT_MIN
	** or if j < INT_MIN - i; given i < 0, INT_MIN - i cannot overflow.
	*/
	if ((i >= 0) ? (j > INT_MAX - i) : (j < INT_MIN - i))
		return true;
	*ip += j;
	return false;
}

static BOOL
increment_overflow_time(time_t *tp, int_fast32_t j)
{
	/*
	** This is like
	** 'if (! (TIME_T_MIN <= *tp + j && *tp + j <= TIME_T_MAX)) ...',
	** except that it does the right thing even if *tp + j would overflow.
	*/
	if (! (j < 0
	       ? (TYPE_SIGNED(time_t) ? TIME_T_MIN - j <= *tp : -1 - j < *tp)
	       : *tp <= TIME_T_MAX - j))
		return true;
	*tp += j;
	return false;
}

static int_fast64_t
leapcorr(struct state const *sp, time_t t)
{
	struct lsinfo const * lp;
	int		i;

	i = sp->leapcnt;
	while (--i >= 0) {
		lp = &sp->lsis[i];
		if (t >= lp->ls_trans)
			return lp->ls_corr;
	}
	return 0;
}

