/* load_webp.c - load WEBP image from file
 *
 * Raster graphics library
 *
 * Copyright (c) 2014 Window Maker Team
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#include "config.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <webp/decode.h>

#include "wraster.h"
#include "imgformat.h"


RImage *RLoadWEBP(const char *file_name)
{
	FILE *file;
	RImage *image = NULL;
	char buffer[20];
	int raw_data_size;
	int r;
	uint8_t *raw_data;
	WebPBitstreamFeatures features;
	uint8_t *ret = NULL;

	file = fopen(file_name, "rb");
	if (!file) {
		RErrorCode = RERR_OPEN;
		return NULL;
	}

	if (!fread(buffer, sizeof(buffer), 1, file)) {
		RErrorCode = RERR_BADIMAGEFILE;
		fclose(file);
		return NULL;
	}

	if (!(buffer[ 0] == 'R' && buffer[ 1] == 'I' && buffer[ 2] == 'F' && buffer[ 3] == 'F' &&
	      buffer[ 8] == 'W' && buffer[ 9] == 'E' && buffer[10] == 'B' && buffer[11] == 'P' &&
	      buffer[12] == 'V' && buffer[13] == 'P' && buffer[14] == '8' &&
#if WEBP_DECODER_ABI_VERSION < 0x0003	/* old versions don't support WEBPVP8X and WEBPVP8L */
	      buffer[15] == ' ')) {
#else
	      (buffer[15] == ' ' || buffer[15] == 'X' || buffer[15] == 'L'))) {
#endif
		RErrorCode = RERR_BADFORMAT;
		fclose(file);
		return NULL;
	}

	fseek(file, 0L, SEEK_END);
	raw_data_size = ftell(file);

	if (raw_data_size <= 0) {
		fprintf(stderr, "wrlib: Failed to find the WEBP file size for \"%s\"\n", file_name);
		RErrorCode = RERR_BADIMAGEFILE;
		fclose(file);
		return NULL;
	}

	raw_data = (uint8_t *) malloc(raw_data_size);

	if (!raw_data) {
		RErrorCode = RERR_NOMEMORY;
		fclose(file);
		return NULL;
	}

	fseek(file, 0L, SEEK_SET);
	r = fread(raw_data, 1, raw_data_size, file);
	fclose(file);

	if (r != raw_data_size) {
		RErrorCode = RERR_READ;
		free(raw_data);
		return NULL;
	}

	if (WebPGetFeatures(raw_data, raw_data_size, &features) != VP8_STATUS_OK) {
		fprintf(stderr, "wrlib: WebPGetFeatures has failed on \"%s\"\n", file_name);
		RErrorCode = RERR_BADIMAGEFILE;
		free(raw_data);
		return NULL;
	}

	if (features.has_alpha) {
		image = RCreateImage(features.width, features.height, True);
		if (!image) {
			RErrorCode = RERR_NOMEMORY;
			free(raw_data);
			return NULL;
		}
		ret = WebPDecodeRGBAInto(raw_data, raw_data_size, image->data,
		                         features.width * features.height * 4,
		                         features.width * 4);
	} else {
		image = RCreateImage(features.width, features.height, False);
		if (!image) {
			RErrorCode = RERR_NOMEMORY;
			free(raw_data);
			return NULL;
		}
		ret = WebPDecodeRGBInto(raw_data, raw_data_size, image->data,
		                        features.width * features.height * 3,
		                        features.width * 3);
	}

	free(raw_data);

	if (!ret) {
		fprintf(stderr, "wrlib: Failed to decode WEBP from file \"%s\"\n", file_name);
		RErrorCode = RERR_BADIMAGEFILE;
		RReleaseImage(image);
		return NULL;
	}

	return image;
}
