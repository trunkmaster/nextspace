/*
 * Author: Len Trigg <trigg@cs.waikato.ac.nz>
 */

/*
 Update: Franck Wolff <frawolff@club-internet.fr>
 -----------------------------------------------------------------------
 List of updated functions :
 - main :
 add -s option for a save panel...
 -----------------------------------------------------------------------
 */

#include <WINGs/WINGs.h>

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#include "logo.xpm"

void wAbort()
{
	exit(1);
}

char *ProgName;

void usage(void)
{
	fprintf(stderr,
		"usage:\n"
		"\t%s [-options]\n"
		"\n"
		"options:\n"
		"  -s\t\tSave panel (default open panel)\n"
		"  -i <str>\tInitial directory (default /)\n"
		"  -t <str>\tQuery window title (default none)\n"
		"\n"
		"information:\n"
		"\t%s pops up a WindowMaker style file selection panel.\n"
		"\n" "version:\n" "\t%s\n", ProgName, ProgName, __DATE__);
	exit(0);
}

#define OPEN_PANEL_TYPE 0
#define SAVE_PANEL_TYPE 1

int main(int argc, char **argv)
{
	Display *dpy = XOpenDisplay("");
	WMScreen *scr;
	WMPixmap *pixmap;
	WMOpenPanel *oPanel;
	WMSavePanel *sPanel;
	/*  RImage *image; */
	char *title = NULL;
	char *initial = "/";
	int ch;
	int panelType = OPEN_PANEL_TYPE;
	extern char *optarg;
	extern int optind;

	if (!dpy) {
		puts("could not open display");
		exit(1);
	}

	WMInitializeApplication("WMFile", &argc, argv);

	ProgName = argv[0];

	while ((ch = getopt(argc, argv, "si:ht:")) != -1)
		switch (ch) {
		case 's':
			panelType = SAVE_PANEL_TYPE;
			break;
		case 'i':
			initial = optarg;
			break;
		case 't':
			title = optarg;
			break;
		default:
			usage();
		}

	for (; optind < argc; optind++)
		usage();

	scr = WMCreateSimpleApplicationScreen(dpy);

	pixmap = WMCreatePixmapFromXPMData(scr, GNUSTEP_XPM);
	WMSetApplicationIconPixmap(scr, pixmap);
	WMReleasePixmap(pixmap);
	if (panelType == SAVE_PANEL_TYPE) {
		sPanel = WMGetSavePanel(scr);
		if (WMRunModalFilePanelForDirectory(sPanel, NULL, initial,
						    /*title */ NULL, NULL) == True)
			printf("%s\n", WMGetFilePanelFileName(sPanel));
		else
			printf("\n");
	} else {
		oPanel = WMGetOpenPanel(scr);
		if (WMRunModalFilePanelForDirectory(oPanel, NULL, initial,
						    /*title */ NULL, NULL) == True)
			printf("%s\n", WMGetFilePanelFileName(oPanel));
		else
			printf("\n");
	}
	return 0;
}
