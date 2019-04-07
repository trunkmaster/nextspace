
#include <sys/types.h>
#include <sys/stat.h>

#include <ctype.h>
#include <errno.h>
#include <ftw.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#include "WUtil.h"
#include "wconfig.h"

typedef enum {
	WPLString = 0x57504c01,
	WPLData = 0x57504c02,
	WPLArray = 0x57504c03,
	WPLDictionary = 0x57504c04
} WPLType;

typedef struct W_PropList {
	WPLType type;

	union {
		char *string;
		WMData *data;
		WMArray *array;
		WMHashTable *dict;
	} d;

	int retainCount;
} W_PropList;

typedef struct PLData {
	const char *ptr;
	int pos;
	const char *filename;
	int lineNumber;
} PLData;

typedef struct StringBuffer {
	char *str;
	int size;
} StringBuffer;

static unsigned hashPropList(const void *param);
static WMPropList *getPLString(PLData * pldata);
static WMPropList *getPLQString(PLData * pldata);
static WMPropList *getPLData(PLData * pldata);
static WMPropList *getPLArray(PLData * pldata);
static WMPropList *getPLDictionary(PLData * pldata);
static WMPropList *getPropList(PLData * pldata);

typedef Bool(*isEqualFunc) (const void *, const void *);

static const WMHashTableCallbacks WMPropListHashCallbacks = {
	hashPropList,
	(isEqualFunc) WMIsPropListEqualTo,
	NULL,
	NULL
};

static Bool caseSensitive = True;

#define BUFFERSIZE           8192
#define BUFFERSIZE_INCREMENT 1024

#if 0
# define DPUT(s) puts(s)
#else
# define DPUT(s)
#endif

#define COMPLAIN(pld, msg) wwarning(_("syntax error in %s %s, line %i: %s"),\
    (pld)->filename ? "file" : "PropList",\
    (pld)->filename ? (pld)->filename : "description",\
    (pld)->lineNumber, msg)

#define ISSTRINGABLE(c) (isalnum(c) || (c)=='.' || (c)=='_' || (c)=='/' \
    || (c)=='+')

#define CHECK_BUFFER_SIZE(buf, ptr) \
    if ((ptr) >= (buf).size-1) {\
    (buf).size += BUFFERSIZE_INCREMENT;\
    (buf).str = wrealloc((buf).str, (buf).size);\
    }

#define inrange(ch, min, max) ((ch)>=(min) && (ch)<=(max))
#define noquote(ch) (inrange(ch, 'a', 'z') || inrange(ch, 'A', 'Z') || inrange(ch, '0', '9') || ((ch)=='_') || ((ch)=='.') || ((ch)=='$'))
#define charesc(ch) (inrange(ch, 0x07, 0x0c) || ((ch)=='"') || ((ch)=='\\'))
#define numesc(ch) (((ch)<=0x06) || inrange(ch, 0x0d, 0x1f) || ((ch)>0x7e))
#define ishexdigit(ch) (inrange(ch, 'a', 'f') || inrange(ch, 'A', 'F') || inrange(ch, '0', '9'))
#define char2num(ch) (inrange(ch,'0','9') ? ((ch)-'0') : (inrange(ch,'a','f') ? ((ch)-0x57) : ((ch)-0x37)))
#define num2char(num) ((num) < 0xa ? ((num)+'0') : ((num)+0x57))

#define MaxHashLength 64

static unsigned hashPropList(const void *param)
{
	WMPropList *plist= (WMPropList *) param;
	unsigned ret = 0;
	unsigned ctr = 0;
	const char *key;
	int i, len;

	switch (plist->type) {
	case WPLString:
		key = plist->d.string;
		len = WMIN(strlen(key), MaxHashLength);
		for (i = 0; i < len; i++) {
			ret ^= tolower(key[i]) << ctr;
			ctr = (ctr + 1) % sizeof(char *);
		}
		/*while (*key) {
		   ret ^= tolower(*key++) << ctr;
		   ctr = (ctr + 1) % sizeof (char *);
		   } */
		break;

	case WPLData:
		key = WMDataBytes(plist->d.data);
		len = WMIN(WMGetDataLength(plist->d.data), MaxHashLength);
		for (i = 0; i < len; i++) {
			ret ^= key[i] << ctr;
			ctr = (ctr + 1) % sizeof(char *);
		}
		break;

	default:
		wwarning(_("Only string or data is supported for a proplist dictionary key"));
		wassertrv(False, 0);
		break;
	}

	return ret;
}

static WMPropList *retainPropListByCount(WMPropList * plist, int count)
{
	WMPropList *key, *value;
	WMHashEnumerator e;
	int i;

	plist->retainCount += count;

	switch (plist->type) {
	case WPLString:
	case WPLData:
		break;
	case WPLArray:
		for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
			retainPropListByCount(WMGetFromArray(plist->d.array, i), count);
		}
		break;
	case WPLDictionary:
		e = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&value, (void **)&key)) {
			retainPropListByCount(key, count);
			retainPropListByCount(value, count);
		}
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, NULL);
		break;
	}

	return plist;
}

static void releasePropListByCount(WMPropList * plist, int count)
{
	WMPropList *key, *value;
	WMHashEnumerator e;
	int i;

	plist->retainCount -= count;

	switch (plist->type) {
	case WPLString:
		if (plist->retainCount < 1) {
			wfree(plist->d.string);
			wfree(plist);
		}
		break;
	case WPLData:
		if (plist->retainCount < 1) {
			WMReleaseData(plist->d.data);
			wfree(plist);
		}
		break;
	case WPLArray:
		for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
			releasePropListByCount(WMGetFromArray(plist->d.array, i), count);
		}
		if (plist->retainCount < 1) {
			WMFreeArray(plist->d.array);
			wfree(plist);
		}
		break;
	case WPLDictionary:
		e = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&value, (void **)&key)) {
			releasePropListByCount(key, count);
			releasePropListByCount(value, count);
		}
		if (plist->retainCount < 1) {
			WMFreeHashTable(plist->d.dict);
			wfree(plist);
		}
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertr(False);
		break;
	}
}

static char *dataDescription(WMPropList * plist)
{
	const unsigned char *data;
	char *retVal;
	int i, j, length;

	data = WMDataBytes(plist->d.data);
	length = WMGetDataLength(plist->d.data);

	retVal = (char *)wmalloc(2 * length + length / 4 + 3);

	retVal[0] = '<';
	for (i = 0, j = 1; i < length; i++) {
		retVal[j++] = num2char((data[i] >> 4) & 0x0f);
		retVal[j++] = num2char(data[i] & 0x0f);
		if ((i & 0x03) == 3 && i != length - 1) {
			/* if we've just finished a 32-bit int, add a space */
			retVal[j++] = ' ';
		}
	}
	retVal[j++] = '>';
	retVal[j] = '\0';

	return retVal;
}

static char *stringDescription(WMPropList * plist)
{
	const char *str;
	char *retVal, *sPtr, *dPtr;
	int len, quote;
	unsigned char ch;

	str = plist->d.string;

	if (strlen(str) == 0) {
		return wstrdup("\"\"");
	}

	/* FIXME: make this work with unichars. */

	quote = 0;
	sPtr = (char *)str;
	len = 0;
	while ((ch = *sPtr)) {
		if (!noquote(ch)) {
			quote = 1;
			if (charesc(ch))
				len++;
			else if (numesc(ch))
				len += 3;
		}
		sPtr++;
		len++;
	}

	if (quote)
		len += 2;

	retVal = (char *)wmalloc(len + 1);

	sPtr = (char *)str;
	dPtr = retVal;

	if (quote)
		*dPtr++ = '"';

	while ((ch = *sPtr)) {
		if (charesc(ch)) {
			*(dPtr++) = '\\';
			switch (ch) {
			case '\a':
				*dPtr = 'a';
				break;
			case '\b':
				*dPtr = 'b';
				break;
			case '\t':
				*dPtr = 't';
				break;
			case '\n':
				*dPtr = 'n';
				break;
			case '\v':
				*dPtr = 'v';
				break;
			case '\f':
				*dPtr = 'f';
				break;
			default:
				*dPtr = ch;	/* " or \ */
			}
		} else if (numesc(ch)) {
			*(dPtr++) = '\\';
			*(dPtr++) = '0' + ((ch >> 6) & 07);
			*(dPtr++) = '0' + ((ch >> 3) & 07);
			*dPtr = '0' + (ch & 07);
		} else {
			*dPtr = ch;
		}
		sPtr++;
		dPtr++;
	}

	if (quote)
		*dPtr++ = '"';

	*dPtr = '\0';

	return retVal;
}

static char *description(WMPropList * plist)
{
	WMPropList *key, *val;
	char *retstr = NULL;
	char *str, *tmp, *skey, *sval;
	WMHashEnumerator e;
	int i;

	switch (plist->type) {
	case WPLString:
		retstr = stringDescription(plist);
		break;
	case WPLData:
		retstr = dataDescription(plist);
		break;
	case WPLArray:
		retstr = wstrdup("(");
		for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
			str = description(WMGetFromArray(plist->d.array, i));
			if (i == 0) {
				retstr = wstrappend(retstr, str);
			} else {
				tmp = (char *)wmalloc(strlen(retstr) + strlen(str) + 3);
				sprintf(tmp, "%s, %s", retstr, str);
				wfree(retstr);
				retstr = tmp;
			}
			wfree(str);
		}
		retstr = wstrappend(retstr, ")");
		break;
	case WPLDictionary:
		retstr = wstrdup("{");
		e = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&val, (void **)&key)) {
			skey = description(key);
			sval = description(val);
			tmp = (char *)wmalloc(strlen(retstr) + strlen(skey) + strlen(sval) + 5);
			sprintf(tmp, "%s%s = %s;", retstr, skey, sval);
			wfree(skey);
			wfree(sval);
			wfree(retstr);
			retstr = tmp;
		}
		retstr = wstrappend(retstr, "}");
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, NULL);
		break;
	}

	return retstr;
}

static char *indentedDescription(WMPropList * plist, int level)
{
	WMPropList *key, *val;
	char *retstr = NULL;
	char *str, *tmp, *skey, *sval;
	WMHashEnumerator e;
	int i;

	if (plist->type == WPLArray /* || plist->type==WPLDictionary */ ) {
		retstr = description(plist);

		if (retstr && ((2 * (level + 1) + strlen(retstr)) <= 77)) {
			return retstr;
		} else if (retstr) {
			wfree(retstr);
			retstr = NULL;
		}
	}

	switch (plist->type) {
	case WPLString:
		retstr = stringDescription(plist);
		break;
	case WPLData:
		retstr = dataDescription(plist);
		break;
	case WPLArray:
		retstr = wstrdup("(\n");
		for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
			str = indentedDescription(WMGetFromArray(plist->d.array, i), level + 1);
			if (i == 0) {
				tmp = (char *)wmalloc(2 * (level + 1) + strlen(retstr) + strlen(str) + 1);
				sprintf(tmp, "%s%*s%s", retstr, 2 * (level + 1), "", str);
				wfree(retstr);
				retstr = tmp;
			} else {
				tmp = (char *)wmalloc(2 * (level + 1) + strlen(retstr) + strlen(str) + 3);
				sprintf(tmp, "%s,\n%*s%s", retstr, 2 * (level + 1), "", str);
				wfree(retstr);
				retstr = tmp;
			}
			wfree(str);
		}
		tmp = (char *)wmalloc(strlen(retstr) + 2 * level + 3);
		sprintf(tmp, "%s\n%*s)", retstr, 2 * level, "");
		wfree(retstr);
		retstr = tmp;
		break;
	case WPLDictionary:
		retstr = wstrdup("{\n");
		e = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&val, (void **)&key)) {
			skey = indentedDescription(key, level + 1);
			sval = indentedDescription(val, level + 1);
			tmp = (char *)wmalloc(2 * (level + 1) + strlen(retstr) + strlen(skey)
					      + strlen(sval) + 6);
			sprintf(tmp, "%s%*s%s = %s;\n", retstr, 2 * (level + 1), "", skey, sval);
			wfree(skey);
			wfree(sval);
			wfree(retstr);
			retstr = tmp;
		}
		tmp = (char *)wmalloc(strlen(retstr) + 2 * level + 2);
		sprintf(tmp, "%s%*s}", retstr, 2 * level, "");
		wfree(retstr);
		retstr = tmp;
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, NULL);
		break;
	}

	return retstr;
}

static inline int getChar(PLData * pldata)
{
	int c;

	c = pldata->ptr[pldata->pos];
	if (c == 0) {
		return 0;
	}

	pldata->pos++;

	if (c == '\n')
		pldata->lineNumber++;

	return c;
}

static inline int getNonSpaceChar(PLData * pldata)
{
	int c;

	while (1) {
		c = pldata->ptr[pldata->pos];
		if (c == 0) {
			break;
		}
		pldata->pos++;
		if (c == '\n') {
			pldata->lineNumber++;
		} else if (!isspace(c)) {
			break;
		}
	}

	return c;
}

static char *unescapestr(const char *src)
{
	char *dest = wmalloc(strlen(src) + 1);
	char *dPtr;
	char ch;

	for (dPtr = dest; ; dPtr++) {
		ch = *src++;
		if (ch == '\0')
			break;
		else if (ch != '\\')
			*dPtr = ch;
		else {
			ch = *(src++);
			if (ch == '\0') {
				*dPtr = '\\';
				break;
			} else if ((ch >= '0') && (ch <= '7')) {
				char wch;

				/* Convert octal number to character */
				wch = (ch & 07);
				ch = *src;
				if ((ch >= '0') && (ch <= '7')) {
					src++;
					wch = (wch << 3) | (ch & 07);
					ch = *src;
					if ((ch >= '0') && (ch <= '7')) {
						src++;
						wch = (wch << 3) | (ch & 07);
					}
				}
				*dPtr = wch;
			} else {
				switch (ch) {
				case 'a':
					*dPtr = '\a';
					break;
				case 'b':
					*dPtr = '\b';
					break;
				case 't':
					*dPtr = '\t';
					break;
				case 'r':
					*dPtr = '\r';
					break;
				case 'n':
					*dPtr = '\n';
					break;
				case 'v':
					*dPtr = '\v';
					break;
				case 'f':
					*dPtr = '\f';
					break;
				default:
					*dPtr = ch;
				}
			}
		}
	}

	*dPtr = 0;

	return dest;
}

static WMPropList *getPLString(PLData * pldata)
{
	WMPropList *plist;
	StringBuffer sBuf;
	int ptr = 0;
	int c;

	sBuf.str = wmalloc(BUFFERSIZE);
	sBuf.size = BUFFERSIZE;

	while (1) {
		c = getChar(pldata);
		if (ISSTRINGABLE(c)) {
			CHECK_BUFFER_SIZE(sBuf, ptr);
			sBuf.str[ptr++] = c;
		} else {
			if (c != 0) {
				pldata->pos--;
			}
			break;
		}
	}

	sBuf.str[ptr] = 0;

	if (ptr == 0) {
		plist = NULL;
	} else {
		char *tmp = unescapestr(sBuf.str);
		plist = WMCreatePLString(tmp);
		wfree(tmp);
	}

	wfree(sBuf.str);

	return plist;
}

static WMPropList *getPLQString(PLData * pldata)
{
	WMPropList *plist;
	int ptr = 0, escaping = 0, ok = 1;
	int c;
	StringBuffer sBuf;

	sBuf.str = wmalloc(BUFFERSIZE);
	sBuf.size = BUFFERSIZE;

	while (1) {
		c = getChar(pldata);
		if (!escaping) {
			if (c == '\\') {
				escaping = 1;
				continue;
			} else if (c == '"') {
				break;
			}
		} else {
			CHECK_BUFFER_SIZE(sBuf, ptr);
			sBuf.str[ptr++] = '\\';
			escaping = 0;
		}

		if (c == 0) {
			COMPLAIN(pldata, _("unterminated PropList string"));
			ok = 0;
			break;
		} else {
			CHECK_BUFFER_SIZE(sBuf, ptr);
			sBuf.str[ptr++] = c;
		}
	}

	sBuf.str[ptr] = 0;

	if (!ok) {
		plist = NULL;
	} else {
		char *tmp = unescapestr(sBuf.str);
		plist = WMCreatePLString(tmp);
		wfree(tmp);
	}

	wfree(sBuf.str);

	return plist;
}

static WMPropList *getPLData(PLData * pldata)
{
	int ok = 1;
	int len = 0;
	int c1, c2;
	unsigned char buf[BUFFERSIZE], byte;
	WMPropList *plist;
	WMData *data;

	data = WMCreateDataWithCapacity(0);

	while (1) {
		c1 = getNonSpaceChar(pldata);
		if (c1 == 0) {
			COMPLAIN(pldata, _("unterminated PropList data"));
			ok = 0;
			break;
		} else if (c1 == '>') {
			break;
		} else if (ishexdigit(c1)) {
			c2 = getNonSpaceChar(pldata);
			if (c2 == 0 || c2 == '>') {
				COMPLAIN(pldata, _("unterminated PropList data (missing hexdigit)"));
				ok = 0;
				break;
			} else if (ishexdigit(c2)) {
				byte = char2num(c1) << 4;
				byte |= char2num(c2);
				buf[len++] = byte;
				if (len == sizeof(buf)) {
					WMAppendDataBytes(data, buf, len);
					len = 0;
				}
			} else {
				COMPLAIN(pldata, _("non hexdigit character in PropList data"));
				ok = 0;
				break;
			}
		} else {
			COMPLAIN(pldata, _("non hexdigit character in PropList data"));
			ok = 0;
			break;
		}
	}

	if (!ok) {
		WMReleaseData(data);
		return NULL;
	}

	if (len > 0)
		WMAppendDataBytes(data, buf, len);

	plist = WMCreatePLData(data);
	WMReleaseData(data);

	return plist;
}

static WMPropList *getPLArray(PLData * pldata)
{
	Bool first = True;
	int ok = 1;
	int c;
	WMPropList *array, *obj;

	array = WMCreatePLArray(NULL);

	while (1) {
		c = getNonSpaceChar(pldata);
		if (c == 0) {
			COMPLAIN(pldata, _("unterminated PropList array"));
			ok = 0;
			break;
		} else if (c == ')') {
			break;
		} else if (c == ',') {
			/* continue normally */
		} else if (!first) {
			COMPLAIN(pldata, _("missing or unterminated PropList array"));
			ok = 0;
			break;
		} else {
			pldata->pos--;
		}
		first = False;

		obj = getPropList(pldata);
		if (!obj) {
			COMPLAIN(pldata, _("could not get PropList array element"));
			ok = 0;
			break;
		}
		WMAddToPLArray(array, obj);
		WMReleasePropList(obj);
	}

	if (!ok) {
		WMReleasePropList(array);
		array = NULL;
	}

	return array;
}

static WMPropList *getPLDictionary(PLData * pldata)
{
	int ok = 1;
	int c;
	WMPropList *dict, *key, *value;

	dict = WMCreatePLDictionary(NULL, NULL);

	while (1) {
		c = getNonSpaceChar(pldata);
		if (c == 0) {
			COMPLAIN(pldata, _("unterminated PropList dictionary"));
			ok = 0;
			break;
		} else if (c == '}') {
			break;
		}

		DPUT("getting PropList dictionary key");
		if (c == '<') {
			key = getPLData(pldata);
		} else if (c == '"') {
			key = getPLQString(pldata);
		} else if (ISSTRINGABLE(c)) {
			pldata->pos--;
			key = getPLString(pldata);
		} else {
			if (c == '=') {
				COMPLAIN(pldata, _("missing PropList dictionary key"));
			} else {
				COMPLAIN(pldata, _("missing PropList dictionary entry key "
						   "or unterminated dictionary"));
			}
			ok = 0;
			break;
		}

		if (!key) {
			COMPLAIN(pldata, _("error parsing PropList dictionary key"));
			ok = 0;
			break;
		}

		c = getNonSpaceChar(pldata);
		if (c != '=') {
			WMReleasePropList(key);
			COMPLAIN(pldata, _("missing = in PropList dictionary entry"));
			ok = 0;
			break;
		}

		DPUT("getting PropList dictionary entry value for key");
		value = getPropList(pldata);
		if (!value) {
			COMPLAIN(pldata, _("error parsing PropList dictionary entry value"));
			WMReleasePropList(key);
			ok = 0;
			break;
		}

		c = getNonSpaceChar(pldata);
		if (c != ';') {
			COMPLAIN(pldata, _("missing ; in PropList dictionary entry"));
			WMReleasePropList(key);
			WMReleasePropList(value);
			ok = 0;
			break;
		}

		WMPutInPLDictionary(dict, key, value);
		WMReleasePropList(key);
		WMReleasePropList(value);
	}

	if (!ok) {
		WMReleasePropList(dict);
		dict = NULL;
	}

	return dict;
}

static WMPropList *getPropList(PLData * pldata)
{
	WMPropList *plist;
	int c;

	c = getNonSpaceChar(pldata);

	switch (c) {
	case 0:
		DPUT("End of PropList");
		plist = NULL;
		break;

	case '{':
		DPUT("Getting PropList dictionary");
		plist = getPLDictionary(pldata);
		break;

	case '(':
		DPUT("Getting PropList array");
		plist = getPLArray(pldata);
		break;

	case '<':
		DPUT("Getting PropList data");
		plist = getPLData(pldata);
		break;

	case '"':
		DPUT("Getting PropList quoted string");
		plist = getPLQString(pldata);
		break;

	default:
		if (ISSTRINGABLE(c)) {
			DPUT("Getting PropList string");
			pldata->pos--;
			plist = getPLString(pldata);
		} else {
			COMPLAIN(pldata, _("was expecting a string, data, array or "
					   "dictionary. If it's a string, try enclosing " "it with \"."));
			if (c == '#' || c == '/') {
				wwarning(_("Comments are not allowed inside WindowMaker owned" " domain files."));
			}
			plist = NULL;
		}
		break;
	}

	return plist;
}

void WMPLSetCaseSensitive(Bool caseSensitiveness)
{
	caseSensitive = caseSensitiveness;
}

WMPropList *WMCreatePLString(const char *str)
{
	WMPropList *plist;

	wassertrv(str != NULL, NULL);

	plist = (WMPropList *) wmalloc(sizeof(W_PropList));
	plist->type = WPLString;
	plist->d.string = wstrdup(str);
	plist->retainCount = 1;

	return plist;
}

WMPropList *WMCreatePLData(WMData * data)
{
	WMPropList *plist;

	wassertrv(data != NULL, NULL);

	plist = (WMPropList *) wmalloc(sizeof(W_PropList));
	plist->type = WPLData;
	plist->d.data = WMRetainData(data);
	plist->retainCount = 1;

	return plist;
}

WMPropList *WMCreatePLDataWithBytes(const unsigned char *bytes, unsigned int length)
{
	WMPropList *plist;

	wassertrv(bytes != NULL, NULL);

	plist = (WMPropList *) wmalloc(sizeof(W_PropList));
	plist->type = WPLData;
	plist->d.data = WMCreateDataWithBytes(bytes, length);
	plist->retainCount = 1;

	return plist;
}

WMPropList *WMCreatePLDataWithBytesNoCopy(unsigned char *bytes, unsigned int length, WMFreeDataProc * destructor)
{
	WMPropList *plist;

	wassertrv(bytes != NULL, NULL);

	plist = (WMPropList *) wmalloc(sizeof(W_PropList));
	plist->type = WPLData;
	plist->d.data = WMCreateDataWithBytesNoCopy(bytes, length, destructor);
	plist->retainCount = 1;

	return plist;
}

WMPropList *WMCreatePLArray(WMPropList * elem, ...)
{
	WMPropList *plist, *nelem;
	va_list ap;

	plist = (WMPropList *) wmalloc(sizeof(W_PropList));
	plist->type = WPLArray;
	plist->d.array = WMCreateArray(4);
	plist->retainCount = 1;

	if (!elem)
		return plist;

	WMAddToArray(plist->d.array, WMRetainPropList(elem));

	va_start(ap, elem);

	while (1) {
		nelem = va_arg(ap, WMPropList *);
		if (!nelem) {
			va_end(ap);
			return plist;
		}
		WMAddToArray(plist->d.array, WMRetainPropList(nelem));
	}
}

WMPropList *WMCreatePLDictionary(WMPropList * key, WMPropList * value, ...)
{
	WMPropList *plist, *nkey, *nvalue, *k, *v;
	va_list ap;

	plist = (WMPropList *) wmalloc(sizeof(W_PropList));
	plist->type = WPLDictionary;
	plist->d.dict = WMCreateHashTable(WMPropListHashCallbacks);
	plist->retainCount = 1;

	if (!key || !value)
		return plist;

	WMHashInsert(plist->d.dict, WMRetainPropList(key), WMRetainPropList(value));

	va_start(ap, value);

	while (1) {
		nkey = va_arg(ap, WMPropList *);
		if (!nkey) {
			va_end(ap);
			return plist;
		}
		nvalue = va_arg(ap, WMPropList *);
		if (!nvalue) {
			va_end(ap);
			return plist;
		}
		if (WMHashGetItemAndKey(plist->d.dict, nkey, (void **)&v, (void **)&k)) {
			WMHashRemove(plist->d.dict, k);
			WMReleasePropList(k);
			WMReleasePropList(v);
		}
		WMHashInsert(plist->d.dict, WMRetainPropList(nkey), WMRetainPropList(nvalue));
	}
}

WMPropList *WMRetainPropList(WMPropList * plist)
{
	WMPropList *key, *value;
	WMHashEnumerator e;
	int i;

	plist->retainCount++;

	switch (plist->type) {
	case WPLString:
	case WPLData:
		break;
	case WPLArray:
		for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
			WMRetainPropList(WMGetFromArray(plist->d.array, i));
		}
		break;
	case WPLDictionary:
		e = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&value, (void **)&key)) {
			WMRetainPropList(key);
			WMRetainPropList(value);
		}
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, NULL);
		break;
	}

	return plist;
}

void WMReleasePropList(WMPropList * plist)
{
	WMPropList *key, *value;
	WMHashEnumerator e;
	int i;

	plist->retainCount--;

	switch (plist->type) {
	case WPLString:
		if (plist->retainCount < 1) {
			wfree(plist->d.string);
			wfree(plist);
		}
		break;
	case WPLData:
		if (plist->retainCount < 1) {
			WMReleaseData(plist->d.data);
			wfree(plist);
		}
		break;
	case WPLArray:
		for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
			WMReleasePropList(WMGetFromArray(plist->d.array, i));
		}
		if (plist->retainCount < 1) {
			WMFreeArray(plist->d.array);
			wfree(plist);
		}
		break;
	case WPLDictionary:
		e = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&value, (void **)&key)) {
			WMReleasePropList(key);
			WMReleasePropList(value);
		}
		if (plist->retainCount < 1) {
			WMFreeHashTable(plist->d.dict);
			wfree(plist);
		}
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertr(False);
		break;
	}
}

void WMInsertInPLArray(WMPropList * plist, int index, WMPropList * item)
{
	wassertr(plist->type == WPLArray);

	retainPropListByCount(item, plist->retainCount);
	WMInsertInArray(plist->d.array, index, item);
}

void WMAddToPLArray(WMPropList * plist, WMPropList * item)
{
	wassertr(plist->type == WPLArray);

	retainPropListByCount(item, plist->retainCount);
	WMAddToArray(plist->d.array, item);
}

void WMDeleteFromPLArray(WMPropList * plist, int index)
{
	WMPropList *item;

	wassertr(plist->type == WPLArray);

	item = WMGetFromArray(plist->d.array, index);
	if (item != NULL) {
		WMDeleteFromArray(plist->d.array, index);
		releasePropListByCount(item, plist->retainCount);
	}
}

void WMRemoveFromPLArray(WMPropList * plist, WMPropList * item)
{
	WMPropList *iPtr;
	int i;

	wassertr(plist->type == WPLArray);

	for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
		iPtr = WMGetFromArray(plist->d.array, i);
		if (WMIsPropListEqualTo(item, iPtr)) {
			WMDeleteFromArray(plist->d.array, i);
			releasePropListByCount(iPtr, plist->retainCount);
			break;
		}
	}
}

void WMPutInPLDictionary(WMPropList * plist, WMPropList * key, WMPropList * value)
{
	wassertr(plist->type == WPLDictionary);

	/*WMRetainPropList(key); */
	WMRemoveFromPLDictionary(plist, key);
	retainPropListByCount(key, plist->retainCount);
	retainPropListByCount(value, plist->retainCount);
	WMHashInsert(plist->d.dict, key, value);
	/*WMReleasePropList(key); */
}

void WMRemoveFromPLDictionary(WMPropList * plist, WMPropList * key)
{
	WMPropList *k, *v;

	wassertr(plist->type == WPLDictionary);

	if (WMHashGetItemAndKey(plist->d.dict, key, (void **)&v, (void **)&k)) {
		WMHashRemove(plist->d.dict, k);
		releasePropListByCount(k, plist->retainCount);
		releasePropListByCount(v, plist->retainCount);
	}
}

WMPropList *WMMergePLDictionaries(WMPropList * dest, WMPropList * source, Bool recursive)
{
	WMPropList *key, *value, *dvalue;
	WMHashEnumerator e;

	wassertrv(source->type == WPLDictionary && dest->type == WPLDictionary, NULL);

	if (source == dest)
		return dest;

	e = WMEnumerateHashTable(source->d.dict);
	while (WMNextHashEnumeratorItemAndKey(&e, (void **)&value, (void **)&key)) {
		if (recursive && value->type == WPLDictionary) {
			dvalue = WMHashGet(dest->d.dict, key);
			if (dvalue && dvalue->type == WPLDictionary) {
				WMMergePLDictionaries(dvalue, value, True);
			} else {
				WMPutInPLDictionary(dest, key, value);
			}
		} else {
			WMPutInPLDictionary(dest, key, value);
		}
	}

	return dest;
}

WMPropList *WMSubtractPLDictionaries(WMPropList * dest, WMPropList * source, Bool recursive)
{
	WMPropList *key, *value, *dvalue;
	WMHashEnumerator e;

	wassertrv(source->type == WPLDictionary && dest->type == WPLDictionary, NULL);

	if (source == dest) {
		WMPropList *keys = WMGetPLDictionaryKeys(dest);
		int i;

		for (i = 0; i < WMGetArrayItemCount(keys->d.array); i++) {
			WMRemoveFromPLDictionary(dest, WMGetFromArray(keys->d.array, i));
		}
		WMReleasePropList(keys);
		return dest;
	}

	e = WMEnumerateHashTable(source->d.dict);
	while (WMNextHashEnumeratorItemAndKey(&e, (void **)&value, (void **)&key)) {
		dvalue = WMHashGet(dest->d.dict, key);
		if (!dvalue)
			continue;
		if (WMIsPropListEqualTo(value, dvalue)) {
			WMRemoveFromPLDictionary(dest, key);
		} else if (recursive && value->type == WPLDictionary && dvalue->type == WPLDictionary) {
			WMSubtractPLDictionaries(dvalue, value, True);
		}
	}

	return dest;
}

int WMGetPropListItemCount(WMPropList * plist)
{
	switch (plist->type) {
	case WPLString:
	case WPLData:
		return 0;	/* should this be 1 instead? */
	case WPLArray:
		return WMGetArrayItemCount(plist->d.array);
	case WPLDictionary:
		return (int)WMCountHashTable(plist->d.dict);
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, 0);
		break;
	}

	return 0;
}

Bool WMIsPLString(WMPropList * plist)
{
	return (plist->type == WPLString);
}

Bool WMIsPLData(WMPropList * plist)
{
	return (plist->type == WPLData);
}

Bool WMIsPLArray(WMPropList * plist)
{
	return (plist->type == WPLArray);
}

Bool WMIsPLDictionary(WMPropList * plist)
{
	return (plist->type == WPLDictionary);
}

Bool WMIsPropListEqualTo(WMPropList * plist, WMPropList * other)
{
	WMPropList *key1, *item1, *item2;
	WMHashEnumerator enumerator;
	int n, i;

	if (plist->type != other->type)
		return False;

	switch (plist->type) {
	case WPLString:
		if (caseSensitive) {
			return (strcmp(plist->d.string, other->d.string) == 0);
		} else {
			return (strcasecmp(plist->d.string, other->d.string) == 0);
		}
	case WPLData:
		return WMIsDataEqualToData(plist->d.data, other->d.data);
	case WPLArray:
		n = WMGetArrayItemCount(plist->d.array);
		if (n != WMGetArrayItemCount(other->d.array))
			return False;
		for (i = 0; i < n; i++) {
			item1 = WMGetFromArray(plist->d.array, i);
			item2 = WMGetFromArray(other->d.array, i);
			if (!WMIsPropListEqualTo(item1, item2))
				return False;
		}
		return True;
	case WPLDictionary:
		if (WMCountHashTable(plist->d.dict) != WMCountHashTable(other->d.dict))
			return False;
		enumerator = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&enumerator, (void **)&item1, (void **)&key1)) {
			item2 = WMHashGet(other->d.dict, key1);
			if (!item2 || !item1 || !WMIsPropListEqualTo(item1, item2))
				return False;
		}
		return True;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, False);
		break;
	}

	return False;
}

char *WMGetFromPLString(WMPropList * plist)
{
	wassertrv(plist->type == WPLString, NULL);

	return plist->d.string;
}

WMData *WMGetFromPLData(WMPropList * plist)
{
	wassertrv(plist->type == WPLData, NULL);

	return plist->d.data;
}

const unsigned char *WMGetPLDataBytes(WMPropList * plist)
{
	wassertrv(plist->type == WPLData, NULL);

	return WMDataBytes(plist->d.data);
}

int WMGetPLDataLength(WMPropList * plist)
{
	wassertrv(plist->type == WPLData, 0);

	return WMGetDataLength(plist->d.data);
}

WMPropList *WMGetFromPLArray(WMPropList * plist, int index)
{
	wassertrv(plist->type == WPLArray, NULL);

	return WMGetFromArray(plist->d.array, index);
}

WMPropList *WMGetFromPLDictionary(WMPropList * plist, WMPropList * key)
{
	wassertrv(plist->type == WPLDictionary, NULL);

	return WMHashGet(plist->d.dict, key);
}

WMPropList *WMGetPLDictionaryKeys(WMPropList * plist)
{
	WMPropList *array, *key;
	WMHashEnumerator enumerator;

	wassertrv(plist->type == WPLDictionary, NULL);

	array = (WMPropList *) wmalloc(sizeof(W_PropList));
	array->type = WPLArray;
	array->d.array = WMCreateArray(WMCountHashTable(plist->d.dict));
	array->retainCount = 1;

	enumerator = WMEnumerateHashTable(plist->d.dict);
	while ((key = WMNextHashEnumeratorKey(&enumerator))) {
		WMAddToArray(array->d.array, WMRetainPropList(key));
	}

	return array;
}

WMPropList *WMShallowCopyPropList(WMPropList * plist)
{
	WMPropList *ret = NULL;
	WMPropList *key, *item;
	WMHashEnumerator e;
	WMData *data;
	int i;

	switch (plist->type) {
	case WPLString:
		ret = WMCreatePLString(plist->d.string);
		break;
	case WPLData:
		data = WMCreateDataWithData(plist->d.data);
		ret = WMCreatePLData(data);
		WMReleaseData(data);
		break;
	case WPLArray:
		ret = (WMPropList *) wmalloc(sizeof(W_PropList));
		ret->type = WPLArray;
		ret->d.array = WMCreateArrayWithArray(plist->d.array);
		ret->retainCount = 1;

		for (i = 0; i < WMGetArrayItemCount(ret->d.array); i++)
			WMRetainPropList(WMGetFromArray(ret->d.array, i));

		break;
	case WPLDictionary:
		ret = WMCreatePLDictionary(NULL, NULL);
		e = WMEnumerateHashTable(plist->d.dict);
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&item, (void **)&key)) {
			WMPutInPLDictionary(ret, key, item);
		}
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, NULL);
		break;
	}

	return ret;
}

WMPropList *WMDeepCopyPropList(WMPropList * plist)
{
	WMPropList *ret = NULL;
	WMPropList *key, *item;
	WMHashEnumerator e;
	WMData *data;
	int i;

	switch (plist->type) {
	case WPLString:
		ret = WMCreatePLString(plist->d.string);
		break;
	case WPLData:
		data = WMCreateDataWithData(plist->d.data);
		ret = WMCreatePLData(data);
		WMReleaseData(data);
		break;
	case WPLArray:
		ret = WMCreatePLArray(NULL);
		for (i = 0; i < WMGetArrayItemCount(plist->d.array); i++) {
			item = WMDeepCopyPropList(WMGetFromArray(plist->d.array, i));
			WMAddToArray(ret->d.array, item);
		}
		break;
	case WPLDictionary:
		ret = WMCreatePLDictionary(NULL, NULL);
		e = WMEnumerateHashTable(plist->d.dict);
		/* While we copy an existing dictionary there is no way that we can
		 * have duplicate keys, so we don't need to first remove a key/value
		 * pair before inserting the new key/value.
		 */
		while (WMNextHashEnumeratorItemAndKey(&e, (void **)&item, (void **)&key)) {
			WMHashInsert(ret->d.dict, WMDeepCopyPropList(key), WMDeepCopyPropList(item));
		}
		break;
	default:
		wwarning(_("Used proplist functions on non-WMPropLists objects"));
		wassertrv(False, NULL);
		break;
	}

	return ret;
}

WMPropList *WMCreatePropListFromDescription(const char *desc)
{
	WMPropList *plist = NULL;
	PLData *pldata;

	pldata = (PLData *) wmalloc(sizeof(PLData));
	pldata->ptr = desc;
	pldata->lineNumber = 1;

	plist = getPropList(pldata);

	if (getNonSpaceChar(pldata) != 0 && plist) {
		COMPLAIN(pldata, _("extra data after end of property list"));
		/*
		 * We can't just ignore garbage after the end of the description
		 * (especially if the description was read from a file), because
		 * the "garbage" can be the real data and the real garbage is in
		 * fact in the beginning of the file (which is now inside plist)
		 */
		WMReleasePropList(plist);
		plist = NULL;
	}

	wfree(pldata);

	return plist;
}

char *WMGetPropListDescription(WMPropList * plist, Bool indented)
{
	return (indented ? indentedDescription(plist, 0) : description(plist));
}

WMPropList *WMReadPropListFromFile(const char *file)
{
	WMPropList *plist = NULL;
	PLData *pldata;
	char *read_buf;
	FILE *f;
	struct stat stbuf;
	size_t length;

	f = fopen(file, "rb");
	if (!f) {
		/* let the user print the error message if he really needs to */
		/*werror(_("could not open domain file '%s' for reading"), file); */
		return NULL;
	}

	if (stat(file, &stbuf) == 0) {
		length = (size_t) stbuf.st_size;
	} else {
		werror(_("could not get size for file '%s'"), file);
		fclose(f);
		return NULL;
	}

	read_buf = wmalloc(length + 1);
	if (fread(read_buf, length, 1, f) != 1) {
		if (ferror(f)) {
			werror(_("error reading from file '%s'"), file);
		}
		fclose(f);
		wfree(read_buf);
		return NULL;
	}
	read_buf[length] = '\0';
	fclose(f);

	pldata = (PLData *) wmalloc(sizeof(PLData));
	pldata->ptr = read_buf;
	pldata->filename = file;
	pldata->lineNumber = 1;

	plist = getPropList(pldata);

	if (getNonSpaceChar(pldata) != 0 && plist) {
		COMPLAIN(pldata, _("extra data after end of property list"));
		/*
		 * We can't just ignore garbage after the end of the description
		 * (especially if the description was read from a file), because
		 * the "garbage" can be the real data and the real garbage is in
		 * fact in the beginning of the file (which is now inside plist)
		 */
		WMReleasePropList(plist);
		plist = NULL;
	}

	wfree(read_buf);
	wfree(pldata);

	return plist;
}

WMPropList *WMReadPropListFromPipe(const char *command)
{
	FILE *file;
	WMPropList *plist;
	PLData *pldata;
	char *read_buf, *read_ptr;
	size_t remain_size, line_size;
	const size_t block_read_size = 4096;
	const size_t block_read_margin = 512;

	file = popen(command, "r");

	if (!file) {
		werror(_("%s:could not open menu file"), command);
		return NULL;
	}

	/* read from file till EOF or OOM and fill proplist buffer*/
	remain_size = block_read_size;
	read_buf = wmalloc(remain_size);
	read_ptr = read_buf;
	while (fgets(read_ptr, remain_size, file) != NULL) {
		line_size = strlen(read_ptr);

		remain_size -= line_size;
		read_ptr += line_size;

		if (remain_size < block_read_margin) {
			size_t read_length;

			read_length = read_ptr - read_buf;
			read_buf = wrealloc(read_buf, read_length + block_read_size);
			read_ptr = read_buf + read_length;
			remain_size = block_read_size;
		}
	}

	pclose(file);

	pldata = (PLData *) wmalloc(sizeof(PLData));
	pldata->ptr = read_buf;
	pldata->filename = command;
	pldata->lineNumber = 1;

	plist = getPropList(pldata);

	if (getNonSpaceChar(pldata) != 0 && plist) {
		COMPLAIN(pldata, _("extra data after end of property list"));
		/*
		 * We can't just ignore garbage after the end of the description
		 * (especially if the description was read from a file), because
		 * the "garbage" can be the real data and the real garbage is in
		 * fact in the beginning of the file (which is now inside plist)
		 */
		WMReleasePropList(plist);
		plist = NULL;
	}

	wfree(read_buf);
	wfree(pldata);

	return plist;
}

/* TODO: review this function's code */

Bool WMWritePropListToFile(WMPropList * plist, const char *path)
{
	char *thePath = NULL;
	char *desc;
	FILE *theFile;
#ifdef	HAVE_MKSTEMP
	int fd, mask;
#endif

	if (!wmkdirhier(path))
		return False;

	/* Use the path name of the destination file as a prefix for the
	 * mkstemp() call so that we can be sure that both files are on
	 * the same filesystem and the subsequent rename() will work. */
	thePath = wstrconcat(path, ".XXXXXX");

#ifdef  HAVE_MKSTEMP
	/*
	 * We really just want to read the current umask, but as Coverity is
	 * pointing a possible security issue:
	 * some versions of mkstemp do not set file rights properly on the
	 * created file, so it is recommended so set the umask beforehand.
	 * As we need to set an umask to read the current value, we take this
	 * opportunity to set a temporary aggresive umask so Coverity won't
	 * complain, even if we do not really care in the present use case.
	 */
	mask = umask(S_IRWXG | S_IRWXO);
	if ((fd = mkstemp(thePath)) < 0) {
		werror(_("mkstemp (%s) failed"), thePath);
		goto failure;
	}
	umask(mask);
	fchmod(fd, 0666 & ~mask);
	if ((theFile = fdopen(fd, "wb")) == NULL) {
		close(fd);
	}
#else
	if (mktemp(thePath) == NULL) {
		werror(_("mktemp (%s) failed"), thePath);
		goto failure;
	}
	theFile = fopen(thePath, "wb");
#endif

	if (theFile == NULL) {
		werror(_("open (%s) failed"), thePath);
		goto failure;
	}

	desc = indentedDescription(plist, 0);

	if (fprintf(theFile, "%s\n", desc) != strlen(desc) + 1) {
		werror(_("writing to file: %s failed"), thePath);
		wfree(desc);
		goto failure;
	}

	wfree(desc);

	(void)fsync(fileno(theFile));
	if (fclose(theFile) != 0) {
		werror(_("fclose (%s) failed"), thePath);
		goto failure;
	}

	/* If we used a temporary file, we still need to rename() it be the
	 * real file.  Also, we need to try to retain the file attributes of
	 * the original file we are overwriting (if we are) */
	if (rename(thePath, path) != 0) {
		werror(_("rename ('%s' to '%s') failed"), thePath, path);
		goto failure;
	}

	wfree(thePath);
	return True;

 failure:
	unlink(thePath);
	wfree(thePath);
	return False;
}

/*
 * create a directory hierarchy
 *
 * if the last octet of `path' is `/', the full path is
 * assumed to be a directory; otherwise path is assumed to be a
 * file, and the last component is stripped off. the rest is the
 * the hierarchy to be created.
 *
 * refuses to create anything outside $GNUSTEP_USER_ROOT
 *
 * returns 1 on success, 0 on failure
 */
int wmkdirhier(const char *path)
{
	const char *t;
	char *thePath = NULL, buf[1024];
	size_t p, plen;
	struct stat st;

	/* Only create directories under $GNUSTEP_USER_ROOT */
	if ((t = wusergnusteppath()) == NULL)
		return 0;
	if (strncmp(path, t, strlen(t)) != 0)
		return 0;

	thePath = wstrdup(path);
	/* Strip the trailing component if it is a file */
	p = strlen(thePath);
	while (p && thePath[p] != '/')
		thePath[p--] = '\0';

	thePath[p] = '\0';

	/* Shortcut if it already exists */
	if (stat(thePath, &st) == 0) {
		wfree(thePath);
		if (S_ISDIR(st.st_mode)) {
			/* Is a directory alright */
			return 1;
		} else {
			/* Exists, but not a directory, the caller
			 * might just as well abort now */
			return 0;
		}
	}

	memset(buf, 0, sizeof(buf));
	strncpy(buf, t, sizeof(buf) - 1);
	p = strlen(buf);
	plen = strlen(thePath);

	do {
		while (p++ < plen && thePath[p] != '/')
			;

		strncpy(buf, thePath, p);
		if (mkdir(buf, 0777) == -1 && errno == EEXIST &&
		    stat(buf, &st) == 0 && !S_ISDIR(st.st_mode)) {
			werror(_("Could not create component %s"), buf);
			wfree(thePath);
			return 0;
		}
	} while (p < plen);

	wfree(thePath);
	return 1;
}

/* ARGSUSED2 */
static int wrmdirhier_fn(const char *path, const struct stat *st,
    int type, struct FTW *ftw)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) st;
	(void) ftw;

	switch(type) {
	case FTW_D:
		break;
	case FTW_DP:
		return rmdir(path);
		break;
	case FTW_F:
	case FTW_SL:
	case FTW_SLN:
		return unlink(path);
		break;
	case FTW_DNR:
	case FTW_NS:
	default:
		return EPERM;
	}

	/* NOTREACHED */
	return 0;
}

/*
 * remove a directory hierarchy
 *
 * refuses to remove anything outside $GNUSTEP_USER_ROOT
 *
 * returns 1 on success, 0 on failure
 *
 * TODO: revisit what's error and what's not
 *
 * with inspirations from OpenBSD's bin/rm/rm.c
 */
int wrmdirhier(const char *path)
{
	struct stat st;
	int error;
	const char *t;

	/* Only remove directories under $GNUSTEP_USER_ROOT */
	if ((t = wusergnusteppath()) == NULL)
		return EPERM;
	if (strncmp(path, t, strlen(t)) != 0)
		return EPERM;

	/* Shortcut if it doesn't exist to begin with */
	if (stat(path, &st) == -1)
		return ENOENT;

	error = nftw(path, wrmdirhier_fn, 1, FTW_PHYS);

	return error;
}
