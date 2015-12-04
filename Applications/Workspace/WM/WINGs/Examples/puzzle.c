
#include <stdlib.h>
#include <stdio.h>
#include <WINGs/WINGs.h>
#include <stdint.h>

#define MAX_SIZE 	10*10

WMWindow *win;
WMButton *Button[MAX_SIZE];
signed char Map[MAX_SIZE];
int Size = 4;
int MoveCount;

#define MAP(x,y)  Map[(x)+(y)*Size]

int WinSize = 120;

Bool CheckWin(void)
{
	int i;

	for (i = 0; i < Size * Size - 1; i++) {
		if (Map[i] != i)
			return False;
	}

	return True;
}

void MoveButton(int button, int x, int y)
{
	WMMoveWidget(Button[button], x * (WinSize / Size), y * (WinSize / Size));
}

Bool SlideButton(int button)
{
	int x = 0, y = 0, done = 0;

	/* locate the button */
	for (y = 0; y < Size; y++) {
		for (x = 0; x < Size; x++) {
			if (MAP(x, y) == button) {
				done = 1;
				break;
			}
		}
		if (done)
			break;
	}

	if (x > 0 && MAP(x - 1, y) < 0) {
		MAP(x, y) = -1;
		MoveButton(button, x - 1, y);
		MAP(x - 1, y) = button;
	} else if (x < Size - 1 && MAP(x + 1, y) < 0) {
		MAP(x, y) = -1;
		MoveButton(button, x + 1, y);
		MAP(x + 1, y) = button;
	} else if (y > 0 && MAP(x, y - 1) < 0) {
		MAP(x, y) = -1;
		MoveButton(button, x, y - 1);
		MAP(x, y - 1) = button;
	} else if (y < Size - 1 && MAP(x, y + 1) < 0) {
		MAP(x, y) = -1;
		MoveButton(button, x, y + 1);
		MAP(x, y + 1) = button;
	} else {
		return False;
	}
	return True;
}

#define SWAP(a,b) {int tmp; tmp=a; a=b; b=tmp;}

void ResetGame(void)
{
	int i, x, y, ox, oy;

	MoveCount = 0;

	for (i = 0; i < Size * Size - 1; i++) {
		Map[i] = i;
	}
	Map[i] = -1;
	ox = x = Size - 1;
	oy = y = Size - 1;
	for (i = 0; i < 1000; i++) {
		int ok;
		ok = 1;
		switch (rand() % 4) {
		case 0:
			if (x > 0)
				x--;
			else
				ok = 0;
			break;
		case 2:
			if (x < Size - 1)
				x++;
			else
				ok = 0;
			break;
		case 1:
			if (y > 0)
				y--;
			else
				ok = 0;
			break;
		case 3:
			if (y < Size - 1)
				y++;
			else
				ok = 0;
			break;
		}
		if (ok) {
			MoveButton(MAP(x, y), ox, oy);

			SWAP(MAP(ox, oy), MAP(x, y));

			while (XPending(WMScreenDisplay(WMWidgetScreen(win)))) {
				XEvent ev;
				WMNextEvent(WMScreenDisplay(WMWidgetScreen(win)), &ev);
				WMHandleEvent(&ev);
			}
			ox = x;
			oy = y;
		}
	}
}

void buttonClick(WMWidget * w, void *ptr)
{
	char buffer[300];

	if (SlideButton((uintptr_t)ptr)) {
		MoveCount++;

		if (CheckWin()) {
			sprintf(buffer, "You finished the game in %i moves.", MoveCount);

			if (WMRunAlertPanel(WMWidgetScreen(w), win, "You Won!", buffer,
					    "Wee!", "Gah! Lemme retry!", NULL) == WAPRDefault) {
				exit(0);
			}

			ResetGame();
		}
	}
}

static void resizeObserver(void *self, WMNotification * notif)
{
	WMSize size = WMGetViewSize(WMWidgetView(win));
	int x, y;

	(void) self;
	(void) notif;

	WinSize = size.width;
	for (y = 0; y < Size; y++) {
		for (x = 0; x < Size; x++) {
			if (MAP(x, y) >= 0) {
				WMResizeWidget(Button[(int)MAP(x, y)], WinSize / Size, WinSize / Size);
				WMMoveWidget(Button[(int)MAP(x, y)], x * (WinSize / Size), y * (WinSize / Size));
			}
		}
	}

}

int main(int argc, char **argv)
{
	Display *dpy;
	WMScreen *scr;
	int x, y, i;

	WMInitializeApplication("Puzzle", &argc, argv);

	dpy = XOpenDisplay("");
	if (!dpy) {
		printf("could not open display\n");
		exit(1);
	}

	scr = WMCreateScreen(dpy, DefaultScreen(dpy));

	win = WMCreateWindow(scr, "puzzle");
	WMResizeWidget(win, WinSize, WinSize);
	WMSetWindowTitle(win, "zuPzel");
	WMSetWindowMinSize(win, 80, 80);
	WMSetWindowAspectRatio(win, 2, 2, 2, 2);
	WMSetWindowResizeIncrements(win, Size, Size);
	WMSetViewNotifySizeChanges(WMWidgetView(win), True);
	WMAddNotificationObserver(resizeObserver, NULL, WMViewSizeDidChangeNotification, WMWidgetView(win));

	for (i = y = 0; y < Size && i < Size * Size - 1; y++) {
		for (x = 0; x < Size && i < Size * Size - 1; x++) {
			char buf[32];
			WMColor *color;
			RColor col;
			RHSVColor hsv;

			hsv.hue = i * 360 / (Size * Size - 1);
			hsv.saturation = 120;
			hsv.value = 200;

			RHSVtoRGB(&hsv, &col);

			color = WMCreateRGBColor(scr, col.red << 8, col.green << 8, col.blue << 8, False);

			MAP(x, y) = i;
			Button[i] = WMCreateButton(win, WBTMomentaryLight);
			WMSetWidgetBackgroundColor(Button[i], color);
			WMReleaseColor(color);
			WMSetButtonAction(Button[i], buttonClick, (void *)(uintptr_t) i);
			WMResizeWidget(Button[i], WinSize / Size, WinSize / Size);
			WMMoveWidget(Button[i], x * (WinSize / Size), y * (WinSize / Size));
			sprintf(buf, "%i", i + 1);
			WMSetButtonText(Button[i], buf);
			WMSetButtonTextAlignment(Button[i], WACenter);
			i++;
		}
	}

	WMMapSubwidgets(win);
	WMMapWidget(win);
	WMRealizeWidget(win);

	ResetGame();

	WMScreenMainLoop(scr);

	return 0;
}
