
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <WINGs/WUtil.h>

#include "../src/wconfig.h"

#include "common.h"


#define DEFAULT_FONT "sans serif:pixelsize=12"

/* X Font Name Suffix field names */
enum {
	FOUNDRY,
	FAMILY_NAME,
	WEIGHT_NAME,
	SLANT,
	SETWIDTH_NAME,
	ADD_STYLE_NAME,
	PIXEL_SIZE,
	POINT_SIZE,
	RESOLUTION_X,
	RESOLUTION_Y,
	SPACING,
	AVERAGE_WIDTH,
	CHARSET_REGISTRY,
	CHARSET_ENCODING
};

static int countChar(const char *str, char c)
{
	int count = 0;

	if (!str)
		return 0;

	for (; *str != 0; str++) {
		if (*str == c) {
			count++;
		}
	}

	return count;
}

typedef struct str {
	const char *str;
	int len;
} str;

#define XLFD_TOKENS 14

static str *getXLFDTokens(const char *xlfd)
{
	static str tokens[XLFD_TOKENS];
	int i, len, size;
	const char *ptr;

	/* XXX: why does this assume there can't ever be XFNextPrefix? */
	if (!xlfd || *xlfd != '-' || countChar(xlfd, '-') != XLFD_TOKENS)
		return NULL;

	memset(tokens, 0, sizeof(str) * XLFD_TOKENS);

	len = strlen(xlfd);

	for (ptr = xlfd, i = 0; i < XLFD_TOKENS && len > 0; i++) {
		/* skip one '-' */
		ptr++;
		len--;
		if (len <= 0)
			break;
		size = strcspn(ptr, "-,");
		tokens[i].str = ptr;
		tokens[i].len = size;
		ptr += size;
		len -= size;
	}

	return tokens;
}

static int strToInt(str * token)
{
	static char buf[32]; /* enough for an Incredibly Big Number */

	if (token->len == 0 ||
	    token->str[0] == '*' ||
	    token->len >= sizeof(buf))
		return -1;

	memset(buf, 0, sizeof(buf));
	strncpy(buf, token->str, token->len);

	/* the code using this will gracefully handle overflows */
	return (int)strtol(buf, NULL, 10);
}

static char *mapWeightToName(str * weight)
{
	static const char *normalNames[] = { "medium", "normal", "regular" };
	static char buf[32];
	size_t i;

	if (weight->len == 0)
		return "";

	for (i = 0; i < wlengthof(normalNames); i++) {
		if (strlen(normalNames[i]) == weight->len && strncmp(normalNames[i], weight->str, weight->len)) {
			return "";
		}
	}

	snprintf(buf, sizeof(buf), ":%.*s", weight->len, weight->str);

	return buf;
}

static char *mapSlantToName(str * slant)
{
	if (slant->len == 0)
		return "";

	switch (slant->str[0]) {
	case 'i':
		return ":italic";
	case 'o':
		return ":oblique";
	case 'r':
	default:
		return "";
	}
}

static char *xlfdToFc(const char *xlfd, const char *useFamily, Bool keepXLFD)
{
	str *tokens, *family, *weight, *slant;
	char *name, buf[64];
	int size, pixelsize;

	tokens = getXLFDTokens(xlfd);
	if (!tokens)
		return wstrdup(DEFAULT_FONT);

	family = &(tokens[FAMILY_NAME]);
	weight = &(tokens[WEIGHT_NAME]);
	slant = &(tokens[SLANT]);
	pixelsize = strToInt(&tokens[PIXEL_SIZE]);
	size = strToInt(&tokens[POINT_SIZE]);

	if (useFamily) {
		name = wstrdup(useFamily);
	} else {
		if (family->len == 0 || family->str[0] == '*')
			return wstrdup(DEFAULT_FONT);

		snprintf(buf, sizeof(buf), "%.*s", family->len, family->str);
		name = wstrdup(buf);
	}

	if (size > 0 && pixelsize <= 0) {
		snprintf(buf, sizeof(buf), "-%d", size / 10);
		name = wstrappend(name, buf);
	}

	name = wstrappend(name, mapWeightToName(weight));
	name = wstrappend(name, mapSlantToName(slant));

	if (size <= 0 && pixelsize <= 0) {
		name = wstrappend(name, ":pixelsize=12");
	} else if (pixelsize > 0) {
		/* if pixelsize is present size will be ignored so we skip it */
		snprintf(buf, sizeof(buf), ":pixelsize=%d", pixelsize);
		name = wstrappend(name, buf);
	}

	if (keepXLFD) {
		name = wstrappend(name, ":xlfd=");
		name = wstrappend(name, xlfd);
	}

	return name;
}

/* return converted font (if conversion is needed) else the original font */
char *convertFont(char *font, Bool keepXLFD)
{
	if (font[0] == '-') {
		if (MB_CUR_MAX < 2) {
			return xlfdToFc(font, NULL, keepXLFD);
		} else {
			return xlfdToFc(font, "sans serif", keepXLFD);
		}
	} else {
		return font;
	}
}
