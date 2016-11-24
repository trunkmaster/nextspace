/* jpeg.c - load JPEG image from file
 *
 * Raster graphics library
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
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

#include <config.h>

/* Avoid a compiler warning */
#undef HAVE_STDLIB_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <jpeglib.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include "wraster.h"
#include "imgformat.h"

/*
 * <setjmp.h> is used for the optional error recovery mechanism shown in
 * the second part of the example.
 */

#include <setjmp.h>

/*
 * ERROR HANDLING:
 *
 * The JPEG library's standard error handler (jerror.c) is divided into
 * several "methods" which you can override individually.  This lets you
 * adjust the behavior without duplicating a lot of code, which you might
 * have to update with each future release.
 *
 * Our example here shows how to override the "error_exit" method so that
 * control is returned to the library's caller when a fatal error occurs,
 * rather than calling exit() as the standard error_exit method does.
 *
 * We use C's setjmp/longjmp facility to return control.  This means that the
 * routine which calls the JPEG library must first execute a setjmp() call to
 * establish the return point.  We want the replacement error_exit to do a
 * longjmp().  But we need to make the setjmp buffer accessible to the
 * error_exit routine.  To do this, we make a private extension of the
 * standard JPEG error handler object.  (If we were using C++, we'd say we
 * were making a subclass of the regular error handler.)
 *
 * Here's the extended error handler struct:
 */

struct my_error_mgr {
	struct jpeg_error_mgr pub;	/* "public" fields */

	jmp_buf setjmp_buffer;	/* for return to caller */
};

typedef struct my_error_mgr *my_error_ptr;

/*
 * Here's the routine that will replace the standard error_exit method:
 */

static noreturn void my_error_exit(j_common_ptr cinfo)
{
	/* cinfo->err really points to a my_error_mgr struct, so coerce pointer */
	my_error_ptr myerr = (my_error_ptr) cinfo->err;

	/* Always display the message. */
	/* We could postpone this until after returning, if we chose. */
	(*cinfo->err->output_message) (cinfo);

	/* Return control to the setjmp point */
	longjmp(myerr->setjmp_buffer, 1);
}

RImage *RLoadJPEG(const char *file_name)
{
	RImage *image = NULL;
	struct jpeg_decompress_struct cinfo;
	int i;
	unsigned char *ptr;
	JSAMPROW buffer[1], bptr;
	FILE *file;
	/* We use our private extension JPEG error handler.
	 * Note that this struct must live as long as the main JPEG parameter
	 * struct, to avoid dangling-pointer problems.
	 */
	struct my_error_mgr jerr;

	file = fopen(file_name, "rb");
	if (!file) {
		RErrorCode = RERR_OPEN;
		return NULL;
	}

	cinfo.err = jpeg_std_error(&jerr.pub);
	jerr.pub.error_exit = my_error_exit;
	/* Establish the setjmp return context for my_error_exit to use. */
	if (setjmp(jerr.setjmp_buffer)) {
		/* If we get here, the JPEG code has signaled an error.
		 * We need to clean up the JPEG object, close the input file, and return.
		 */
		jpeg_destroy_decompress(&cinfo);
		fclose(file);
		return NULL;
	}

	jpeg_create_decompress(&cinfo);

	jpeg_stdio_src(&cinfo, file);

	jpeg_read_header(&cinfo, TRUE);

	if (cinfo.image_width < 1 || cinfo.image_height < 1) {
		buffer[0] = NULL;	/* Initialize pointer to avoid spurious free in cleanup code */
		RErrorCode = RERR_BADIMAGEFILE;
		goto bye;
	}

	buffer[0] = (JSAMPROW) malloc(cinfo.image_width * cinfo.num_components);

	if (!buffer[0]) {
		RErrorCode = RERR_NOMEMORY;
		goto bye;
	}

	if (cinfo.jpeg_color_space == JCS_GRAYSCALE) {
		cinfo.out_color_space = JCS_GRAYSCALE;
	} else
		cinfo.out_color_space = JCS_RGB;
	cinfo.quantize_colors = FALSE;
	cinfo.do_fancy_upsampling = FALSE;
	cinfo.do_block_smoothing = FALSE;
	jpeg_calc_output_dimensions(&cinfo);

	image = RCreateImage(cinfo.image_width, cinfo.image_height, False);

	if (!image) {
		RErrorCode = RERR_NOMEMORY;
		goto bye;
	}
	jpeg_start_decompress(&cinfo);

	ptr = image->data;

	if (cinfo.out_color_space == JCS_RGB) {
		while (cinfo.output_scanline < cinfo.output_height) {
			jpeg_read_scanlines(&cinfo, buffer, (JDIMENSION) 1);
			bptr = buffer[0];
			memcpy(ptr, bptr, cinfo.image_width * 3);
			ptr += cinfo.image_width * 3;
		}
	} else {
		while (cinfo.output_scanline < cinfo.output_height) {
			jpeg_read_scanlines(&cinfo, buffer, (JDIMENSION) 1);
			bptr = buffer[0];
			for (i = 0; i < cinfo.image_width; i++) {
				*ptr++ = *bptr;
				*ptr++ = *bptr;
				*ptr++ = *bptr++;
			}
		}
	}

	jpeg_finish_decompress(&cinfo);

 bye:
	jpeg_destroy_decompress(&cinfo);

	fclose(file);

	if (buffer[0])
		free(buffer[0]);

	return image;
}
