/* Copyright (C) 2014-2016 Doug Torrance <dtorrance@piedmont.edu>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <curl/curl.h>
#include <errno.h>
#include <getopt.h>
#include <libgen.h>
#include <libxml/tree.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <WINGs/WINGs.h>

#define DEFAULT_TEXT_COLOR "light sea green"
#define DEFAULT_BG_COLOR "black"

typedef struct {
	char *units;
	char *woeid;
	char *zip;
	char *woeid_or_zip;
	long int interval;
	char *background;
	char *text;
	WMUserDefaults *defaults;
} Preferences;

typedef struct {
	Preferences *prefs;
	WMButton *celsius;
	WMButton *close;
	WMButton *fahrenheit;
	WMButton *save;
	WMButton *woeid;
	WMButton *zip;
	WMColorWell *background;
	WMColorWell *text;
	WMFrame *intervalFrame;
	WMFrame *locationFrame;
	WMFrame *units;
	WMFrame *colors;
	WMLabel *minutes;
	WMLabel *woeid_zip;
	WMLabel *backgroundLabel;
	WMLabel *textLabel;
	WMScreen *screen;
	WMTextField *interval;
	WMTextField *location;
	WMTextField *woeidField;
	WMTextField *zipField;
	WMWindow *window;
} PreferencesWindow;

typedef struct {
	int prefsWindowPresent;
	long int minutesLeft;
	Preferences *prefs;
	PreferencesWindow *prefsWindow;
	WMFrame *frame;
	WMLabel *icon;
	WMLabel *text;
	WMScreen *screen;
} Dockapp;

typedef struct {
  char *day;
  char *low;
  char *high;
  char *text;
} Forecast;

typedef struct {
  int length;
  Forecast *forecasts;
} ForecastArray;

typedef struct {
  char *temp;
  char *text;
  char *title;
  ForecastArray *forecasts;
  RImage *icon;
  int errorFlag;
  char *errorText;
  char retrieved[20];
} Weather;

// --- Structures
Forecast *newForecast()
{
	Forecast *forecast = wmalloc(sizeof(Forecast));
	forecast->day = NULL;
	forecast->low = NULL;
	forecast->high = NULL;
	forecast->text = NULL;
	return forecast;
}

ForecastArray *newForecastArray()
{
	ForecastArray *array = wmalloc(sizeof(ForecastArray));
	array->length = 0;
	array->forecasts = NULL;
	return array;
}

void appendForecast(ForecastArray *array, Forecast *forecast)
{
	array->length++;
	array->forecasts = (Forecast *)wrealloc(array->forecasts, sizeof(Forecast)*(array->length));
	array->forecasts[(array->length)-1] = *forecast;
}

Weather *newWeather()
{
	Weather *weather = wmalloc(sizeof(Weather));
	weather->temp = NULL;
	weather->text = NULL;
	weather->title = NULL;
	weather->icon = NULL;
	weather->forecasts = newForecastArray();
	weather->errorFlag = 0;
	weather->errorText = NULL;
	return weather;
}

void freeForecast(Forecast *forecast)
{
	wfree(forecast->day);
	wfree(forecast->low);
	wfree(forecast->high);
	wfree(forecast->text);
}

void freeForecastArray(ForecastArray *array)
{
	int i;
	for (i = 0; i < array->length; i++)
		if (&array->forecasts[i])
			freeForecast(&array->forecasts[i]);
	wfree(array);
}

void freeWeather(Weather *weather)
{
	wfree(weather->temp);
	wfree(weather->text);
	wfree(weather->title);
	if (weather->forecasts)
		freeForecastArray(weather->forecasts);
	wfree(weather->errorText);
	wfree(weather);
}

// --- Values
void setTitle(Weather *weather, const char *title)
{
  weather->title = wrealloc(weather->title, strlen(title) + 1);
  strcpy(weather->title, title);
  fprintf(stderr, "Set title: %s\n", title);
}

void setError(Weather *weather, WMScreen *screen, const char *errorText)
{
  weather->errorFlag = 1;
  weather->errorText = wrealloc(weather->errorText, strlen(errorText) + 1);
  strcpy(weather->errorText, errorText);
}

void setConditions(Weather *weather,
		   WMScreen *screen,
		   const char *temp,
		   const char *text,
		   const char *code,
		   const char *background)
{
  RContext *context;
  char *filename;
  time_t currentTime;

  fprintf(stderr, "Set conditions: temp=%s text=%s code=%s background=%s\n",
          temp, text, code, background);
        
  weather->temp = wrealloc(weather->temp, strlen(temp) + 1);
  strcpy(weather->temp, temp);
  weather->text = wrealloc(weather->text, strlen(text) + 1);
  strcpy(weather->text, text);

  if (strlen(code) == 1)
    code = wstrconcat("0", code);

  context = WMScreenRContext(screen);
  filename = wstrconcat(wstrconcat(DATADIR"/", code), ".png");
  weather->icon = RLoadImage(context, filename, 0);
  if (!weather->icon)
    {
      setError(weather, screen, wstrconcat(filename, " not found"));
    }
  else
    {
      RColor color;
      color =
        WMGetRColorFromColor(WMCreateNamedColor(screen, background, True));
      RCombineImageWithColor(weather->icon, &color);
    }

  currentTime = time(NULL);
  strftime(weather->retrieved, sizeof weather->retrieved, "%l:%M %P %Z",
           localtime(&currentTime));
}

void setForecast(Forecast *forecast,
		 const char *day,
		 const char *low,
		 const char *high,
		 const char *text)
{
  forecast->day = wrealloc(forecast->day, strlen(day) + 1);
  strcpy(forecast->day, day);
  forecast->low = wrealloc(forecast->low, strlen(low) + 1);
  strcpy(forecast->low, low);
  forecast->high = wrealloc(forecast->high, strlen(high) + 1);
  strcpy(forecast->high, high);
  forecast->text = wrealloc(forecast->text, strlen(text) + 1);
  strcpy(forecast->text, text);
}

// --- DockApp
WMWindow *WMCreateDockapp(WMScreen *screen,
                          const char *name,
                          int argc,
                          char **argv)
{
	WMWindow *dockapp;
	XWMHints *hints;
	Display *display;
	Window window;

	display = WMScreenDisplay(screen);
	dockapp = WMCreateWindow(screen, name);
	WMRealizeWidget(dockapp);

	window = WMWidgetXID(dockapp);

	hints = XGetWMHints(display, window);
	hints->flags |= WindowGroupHint | IconWindowHint | StateHint;
	hints->window_group = window;
	hints->icon_window = window;
	hints->initial_state = WithdrawnState;

	XSetWMHints(display, window, hints);
	XFree(hints);

	XSetCommand(display, window, argv, argc);

	WMResizeWidget(dockapp, 56, 56);
	return dockapp;
}

Dockapp *newDockapp(WMScreen *screen,
                    Preferences *prefs,
                    int argc,
                    char **argv)
{
	Dockapp *dockapp = wmalloc(sizeof(Dockapp));
	WMColor *background;
	WMColor *text;
	WMWindow *window;

	dockapp->screen = screen;
	dockapp->prefs = prefs;
	dockapp->minutesLeft = prefs->interval;
	dockapp->prefsWindowPresent = 0;

	window = WMCreateDockapp(screen, "wmforecast", argc, argv);

	background = WMCreateNamedColor(screen, prefs->background, True);
	if (!background) {
		background = WMCreateNamedColor(screen, DEFAULT_BG_COLOR, True);
		prefs->background = DEFAULT_BG_COLOR;
	}
	text = WMCreateNamedColor(screen, prefs->text, True);
	if (!text) {
		text = WMCreateNamedColor(screen, DEFAULT_TEXT_COLOR, True);
		prefs->text = DEFAULT_TEXT_COLOR;
	}

	dockapp->frame = WMCreateFrame(window);
	WMSetFrameRelief(dockapp->frame, WRSunken);
	WMResizeWidget(dockapp->frame, 56, 56);
	WMSetWidgetBackgroundColor(dockapp->frame, background);
	WMRealizeWidget(dockapp->frame);

	dockapp->text = WMCreateLabel(dockapp->frame);
	WMSetWidgetBackgroundColor(dockapp->text, background);
	WMSetLabelFont(
		dockapp->text,
		WMCreateFont(
			screen,
			"-Misc-Fixed-Medium-R-SemiCondensed--13-120-75-75-C-60-ISO10646-1"));
	WMSetLabelTextColor(dockapp->text, text);
	WMSetLabelTextAlignment(dockapp->text, WACenter);
	WMResizeWidget(dockapp->text, 52, 14);
	WMMoveWidget(dockapp->text, 2, 40);
	WMRealizeWidget(dockapp->text);

	dockapp->icon = WMCreateLabel(dockapp->frame);
	WMSetWidgetBackgroundColor(dockapp->icon, background);
	WMRealizeWidget(dockapp->icon);
	WMSetLabelImagePosition(dockapp->icon, WIPImageOnly);
	WMResizeWidget(dockapp->icon, 32, 32);
	WMMoveWidget(dockapp->icon, 12, 5);

	WMMapWidget(window);
	WMMapWidget(dockapp->frame);
	/* WMMapSubwidgets(dockapp->frame); */

	return dockapp;
}

char *getBalloonText(Weather *weather)
{
	char *text;
	int i;

	text = wstrconcat("\n", weather->title);
	text = wstrappend(text, "\nRetrieved: ");
	text = wstrappend(text, weather->retrieved);
	text = wstrappend(text, "\n\nCurrent Conditions:\n");
	text = wstrappend(text, weather->text);
	text = wstrappend(text, ", ");
	text = wstrappend(text, weather->temp);
	text = wstrappend(text, "°\n\nForecast:\n");
	for (i = 0; i < weather->forecasts->length && i < 7; i++) {
		text = wstrappend(text, weather->forecasts->forecasts[i].day);
		text = wstrappend(text, " - ");
		text = wstrappend(text, weather->forecasts->forecasts[i].text);
		text = wstrappend(text, ". High: ");
		text = wstrappend(text, weather->forecasts->forecasts[i].high);
		text = wstrappend(text, "° Low: ");
		text = wstrappend(text, weather->forecasts->forecasts[i].low);
		text = wstrappend(text, "°\n");
	}
 /* as per Yahoo's Attribution Guidelines
  * (https://developer.yahoo.com/attribution/) */
	text = wstrappend(text, "\nPowered by Yahoo!\n\n");
	return text;
}

/**************************************************
from http://curl.haxx.se/libcurl/c/getinmemory.html
***************************************************/
struct MemoryStruct {
  char *memory;
  size_t size;
};

static size_t
WriteMemoryCallback(void *contents, size_t size, size_t nmemb, void *userp)
{
  size_t realsize = size * nmemb;
  struct MemoryStruct *mem = (struct MemoryStruct *)userp;

  mem->memory = wrealloc(mem->memory, mem->size + realsize + 1);
  memcpy(&(mem->memory[mem->size]), contents, realsize);
  mem->size += realsize;
  mem->memory[mem->size] = 0;

  return realsize;
}

Weather *getWeather(WMScreen *screen, Preferences *prefs)
{
  char		*url;
  CURL		*curl_handle;
  CURLcode	res;
  struct MemoryStruct chunk;
  Weather	*weather;
  xmlDocPtr	doc;
  xmlNodePtr	cur;
  int		i;

  url = wstrdup("https://query.yahooapis.com/v1/public/yql?q="
                "select%20*%20from%20weather.forecast%20where%20woeid");
  if (strcmp(prefs->woeid_or_zip, "w") == 0)
    {
      url = wstrappend(url, "%20%3D%20");
      url = wstrappend(url, prefs->woeid);
    }
  else
    {
      url = wstrappend(url, "%20in%20(select%20woeid%20from%20"
                       "geo.places(1)%20where%20text%3D%22");
      url = wstrappend(url, prefs->zip);
      url = wstrappend(url, "%22)");
    }
  url = wstrappend(url, "%20and%20u%3D'");
  url = wstrappend(url, prefs->units);
  url = wstrappend(url, "'&format=xml");
  /* url = wstrdup("https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20weather.forecast%20where%20woeid%20%3D%20924938&format=xml&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys"); */

  weather = newWeather();
  chunk.memory = wmalloc(1);
  chunk.size = 0;

  curl_global_init(CURL_GLOBAL_ALL);
  curl_handle = curl_easy_init();
  curl_easy_setopt(curl_handle, CURLOPT_URL, url);
  curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
  /* coverity[bad_sizeof] */
  curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&chunk);
  curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, "libcurl-agent/1.0");
  res = curl_easy_perform(curl_handle);
  if (res != CURLE_OK)
    {
      setError(weather, screen, curl_easy_strerror(res));
      curl_easy_cleanup(curl_handle);
      curl_global_cleanup();
      wfree(chunk.memory);
      return weather;
    }
  curl_easy_cleanup(curl_handle);
  curl_global_cleanup();

  doc = xmlParseMemory(chunk.memory, chunk.size);
  if (doc == NULL)
    {
      setError(weather, screen, "Document not parsed successfully");
      xmlFreeDoc(doc);
      return weather;
    }

  cur = xmlDocGetRootElement(doc);
  if (cur == NULL)
    {
      setError(weather, screen, "Empty document");
      xmlFreeDoc(doc);
      return weather;
    }

  for (i = 0; i < 3; i++)
    {
      cur = cur->children;
      if (cur == NULL) {
        setError(weather, screen,
                 "Document not parsed successfully");
        xmlFreeDoc(doc);
        return weather;
      }
    }

  while (cur != NULL)
    {
      if ((!xmlStrcmp(cur->name, (const xmlChar *)"item")))
        {
          cur = cur->children;
          while (cur != NULL)
            {
              if ((!xmlStrcmp(cur->name, (const xmlChar *)"title")))
                {
                  if ((!xmlStrcmp(xmlNodeListGetString(doc, cur->children, 1),
                                  (const xmlChar *)"City not found")))
                    {
                      setError(weather, screen,"Location not found\n");
                    }
                  setTitle(weather,xmlNodeListGetString(doc, cur->children, 1));

                }
              if ((!xmlStrcmp(cur->name, (const xmlChar *)"condition")))
                {
                  setConditions(weather,
                                screen,
                                xmlGetProp(cur, "temp"),
                                xmlGetProp(cur, "text"),
                                xmlGetProp(cur, "code"),
                                prefs->background);
                }
              if ((!xmlStrcmp(cur->name, (const xmlChar *)"forecast")))
                {
                  Forecast *forecast = newForecast();
                  setForecast(forecast,
                              xmlGetProp(cur, "day"),
                              xmlGetProp(cur, "low"),
                              xmlGetProp(cur, "high"),
                              xmlGetProp(cur, "text"));
                  appendForecast(weather->forecasts,forecast);
                }

              cur = cur->next;
            }
        }
      else
        {
          cur = cur->next;
        }
    }

  xmlFreeDoc(doc);
  /* finishing parsing xml */

  wfree(chunk.memory);

  return weather;
}

static void updateDockapp(void *data)
{
  Dockapp *dockapp = (Dockapp *)data;
  WMColor *background;
  WMColor *text;
  WMScreen *screen = dockapp->screen;
  Preferences *prefs = dockapp->prefs;
  Weather *weather;
  WMPixmap *icon;

  background = WMCreateNamedColor(screen, prefs->background, True);
  text = WMCreateNamedColor(screen, prefs->text, True);

  WMSetLabelText(dockapp->text, "loading");
  WMSetWidgetBackgroundColor(dockapp->text, background);
  WMSetLabelTextColor(dockapp->text, text);
  WMRedisplayWidget(dockapp->text);

  WMSetWidgetBackgroundColor(dockapp->frame, background);
  WMSetWidgetBackgroundColor(dockapp->icon, background);

  weather = getWeather(screen, prefs);

  if (weather->errorFlag) {
    RContext *context;

    WMSetLabelText(dockapp->text, "ERROR");

    context = WMScreenRContext(screen);
    weather->icon = RLoadImage(context, DATADIR"/na.png", 0);
    if (weather->icon) {
      RColor color;

      color = WMGetRColorFromColor(
                                   WMCreateNamedColor(screen,
                                                      prefs->background, True));
      RCombineImageWithColor(weather->icon, &color);
      icon = WMCreatePixmapFromRImage(screen,
                                      weather->icon, 0);
      WMSetLabelImage(dockapp->icon, icon);
    }

    WMSetBalloonTextForView(weather->errorText,
                            WMWidgetView(dockapp->icon));

    /* try again in 1 minute */
    dockapp->minutesLeft = 1;
  } else {
    WMSetLabelText(dockapp->text, wstrconcat(weather->temp, "°"));

    icon = WMCreatePixmapFromRImage(screen, weather->icon, 0);
    WMSetLabelImage(dockapp->icon, icon);

    WMSetBalloonTextForView(getBalloonText(weather),
                            WMWidgetView(dockapp->icon));
  }

  WMRedisplayWidget(dockapp->icon);
  WMRedisplayWidget(dockapp->text);

  freeWeather(weather);
}

// --- Preferences
void readPreferences(Preferences *prefs)
{
  if (prefs->defaults) {
    char *value;
    value = WMGetUDStringForKey(prefs->defaults, "units");
    if (value)
      prefs->units = value;
    value = WMGetUDStringForKey(prefs->defaults, "woeid");
    if (value)
      prefs->woeid = value;
    value = WMGetUDStringForKey(prefs->defaults, "zip");
    if (value)
      prefs->zip = value;
    value = WMGetUDStringForKey(prefs->defaults, "woeid_or_zip");
    if (value)
      prefs->woeid_or_zip = value;
    value = WMGetUDStringForKey(prefs->defaults, "interval");
    if (value)
      prefs->interval = strtol(value, NULL, 10);
    value = WMGetUDStringForKey(prefs->defaults, "background");
    if (value)
      prefs->background = value;
    value = WMGetUDStringForKey(prefs->defaults, "text");
    if (value)
      prefs->text = value;
  }
}

Preferences *setPreferences(int argc, char **argv)
{
  int c;
  Preferences *prefs = wmalloc(sizeof(Preferences));

  /* set defaults */
  prefs->units = "f";
  prefs->woeid = "2502265";
  prefs->zip = NULL;
  prefs->woeid_or_zip = NULL;
  prefs->interval = 60;
  prefs->background = DEFAULT_BG_COLOR;
  prefs->text = DEFAULT_TEXT_COLOR;
  prefs->defaults = WMGetStandardUserDefaults();
  readPreferences(prefs);

  /* command line */
  while (1) {
    static struct option long_options[] = {
      {"version", no_argument, 0, 'v'},
      {"help", no_argument, 0, 'h'},
      {"woeid", required_argument, 0, 'w'},
      {"units", required_argument, 0, 'u'},
      {"zip", required_argument, 0, 'z'},
      {"interval", required_argument, 0, 'i'},
      {"background", required_argument, 0, 'b'},
      {"text", required_argument, 0, 't'},
      {0, 0, 0, 0}
    };
    int option_index = 0;

    c = getopt_long(argc, argv, "vhw:u:z:i:b:t:",
                    long_options, &option_index);

    if (c == -1)
      break;

    switch (c) {
    case 0:
      if (long_options[option_index].flag != 0)
        break;
      printf("option %s", long_options[option_index].name);
      if (optarg)
        printf(" with arg %s", optarg);
      printf("\n");
      break;

    case 'v':
      printf("%s\n"
             "Copyright © 2014-2016 Doug Torrance\n"
             "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>\n"
             "This is free software: you are free to change and redistribute it.\n"
             "There is NO WARRANTY, to the extent permitted by law.\n"
             , PACKAGE_STRING);
      exit(0);

    case 'w':
      prefs->woeid_or_zip = "w";
      prefs->woeid = optarg;
      break;
    case 'u':
      if ((strcmp(optarg, "f") != 0) && (strcmp(optarg, "c") != 0)) {
        printf("units must be 'f' or 'c'\n");
        exit(0);
      }
      prefs->units = optarg;
      break;

    case 'z':
      prefs->woeid_or_zip = "z";
      prefs->zip = optarg;
      break;

    case 'i':
      prefs->interval = strtol(optarg, NULL, 10);
      break;

    case 'b':
      prefs->background = optarg;
      break;

    case 't':
      prefs->text = optarg;
      break;

    case '?':
    case 'h':
      printf("A weather dockapp for Window Maker using the Yahoo Weather API\n"
             "Usage: wmforecast [OPTIONS]\n"
             "Options:\n"
             "    -v, --version            print the version number\n"
             "    -h, --help               print this help screen\n"
             "    -i, --interval <min>     number of minutes between refreshes (default 60)\n"
             "    -u, --units <c|f>        whether to use Celsius or Fahrenheit (default f)\n"
             "    -w, --woeid <woeid>      Where on Earth ID (default is 2502265 for\n"
             "                             Sunnyvale, CA -- to find your WOEID, search\n"
             "                             for your city at http://weather.yahoo.com and\n"
             "                             look in the URL.)\n"
             "    -z, --zip <zip>          ZIP code or Location ID (Yahoo has deprecated this\n"
             "                             option and it is not guaranteed to work)\n"
             "    -b, --background <color> set background color\n"
             "    -t, --text <color>       set text color\n"
             "Report bugs to: %s\n"
             "wmforecast home page: %s\n",
             PACKAGE_BUGREPORT, PACKAGE_URL
             );
      exit(0);

    default:

      abort();
    }
  }

  if (!prefs->woeid_or_zip)
    prefs->woeid_or_zip = "w";

  return prefs;
}

static void closePreferences(WMWidget *widget, void *data)
{
  Dockapp *d = (Dockapp *)data;
  WMDestroyWidget(d->prefsWindow->window);
  d->prefsWindowPresent = 0;
}

static void savePreferences(WMWidget *widget, void *data)
{
  Dockapp *d = (Dockapp *)data;

  if (WMGetButtonSelected(d->prefsWindow->celsius))
    WMSetUDStringForKey(d->prefs->defaults, "c", "units");
  if (WMGetButtonSelected(d->prefsWindow->fahrenheit))
    WMSetUDStringForKey(d->prefs->defaults, "f", "units");
  if (WMGetButtonSelected(d->prefsWindow->woeid))
    WMSetUDStringForKey(d->prefs->defaults, "w", "woeid_or_zip");
  if (WMGetButtonSelected(d->prefsWindow->zip))
    WMSetUDStringForKey(d->prefs->defaults, "z", "woeid_or_zip");
  WMSetUDStringForKey(d->prefs->defaults,
                      WMGetTextFieldText(d->prefsWindow->woeidField),
                      "woeid");
  WMSetUDStringForKey(d->prefs->defaults,
                      WMGetTextFieldText(d->prefsWindow->zipField),
                      "zip");
  WMSetUDStringForKey(d->prefs->defaults,
                      WMGetTextFieldText(d->prefsWindow->interval),
                      "interval");
  WMSetUDStringForKey(d->prefs->defaults,
                      WMGetColorRGBDescription(
                                               WMGetColorWellColor(
                                                                   d->prefsWindow->background)),
                      "background");
  WMSetUDStringForKey(d->prefs->defaults,
                      WMGetColorRGBDescription(
                                               WMGetColorWellColor(
                                                                   d->prefsWindow->text)),
                      "text");

  WMSaveUserDefaults(d->prefs->defaults);

  readPreferences(d->prefs);
  updateDockapp(d);
}

static void editPreferences(void *data)
{
  char intervalPtr[50];
  Dockapp *d = (Dockapp *)data;

  d->prefsWindowPresent = 1;

  d->prefsWindow = wmalloc(sizeof(PreferencesWindow));

  d->prefsWindow->screen = d->screen;
  d->prefsWindow->prefs = d->prefs;


  d->prefsWindow->window = WMCreateWindow(d->prefsWindow->screen, "wmforecast");
  WMSetWindowTitle(d->prefsWindow->window, "wmforecast");
  WMSetWindowCloseAction(d->prefsWindow->window, closePreferences, d);
  WMResizeWidget(d->prefsWindow->window, 424, 150);
  WMRealizeWidget(d->prefsWindow->window);
  WMMapWidget(d->prefsWindow->window);

  d->prefsWindow->units = WMCreateFrame(d->prefsWindow->window);
  WMSetFrameTitle(d->prefsWindow->units, "Units");
  WMResizeWidget(d->prefsWindow->units, 112, 80);
  WMMoveWidget(d->prefsWindow->units, 10, 10);
  WMRealizeWidget(d->prefsWindow->units);
  WMMapWidget(d->prefsWindow->units);

  d->prefsWindow->celsius = WMCreateButton(d->prefsWindow->units, WBTRadio);
  WMSetButtonText(d->prefsWindow->celsius, "Celsius");
  WMMoveWidget(d->prefsWindow->celsius, 10, 20);
  if (strcmp(d->prefsWindow->prefs->units, "c") == 0)
    WMSetButtonSelected(d->prefsWindow->celsius, 1);
  WMRealizeWidget(d->prefsWindow->celsius);
  WMMapWidget(d->prefsWindow->celsius);

  d->prefsWindow->fahrenheit = WMCreateButton(d->prefsWindow->units, WBTRadio);
  WMSetButtonText(d->prefsWindow->fahrenheit, "Fahrenheit");
  WMMoveWidget(d->prefsWindow->fahrenheit, 10, 44);
  if (strcmp(d->prefsWindow->prefs->units, "f") == 0)
    WMSetButtonSelected(d->prefsWindow->fahrenheit, 1);
  WMRealizeWidget(d->prefsWindow->fahrenheit);
  WMMapWidget(d->prefsWindow->fahrenheit);

  WMGroupButtons(d->prefsWindow->celsius, d->prefsWindow->fahrenheit);

  d->prefsWindow->locationFrame = WMCreateFrame(d->prefsWindow->window);
  WMSetFrameTitle(d->prefsWindow->locationFrame, "Location");
  WMResizeWidget(d->prefsWindow->locationFrame, 160, 80);
  WMMoveWidget(d->prefsWindow->locationFrame, 132, 10);
  WMRealizeWidget(d->prefsWindow->locationFrame);
  WMMapWidget(d->prefsWindow->locationFrame);

  d->prefsWindow->woeid = WMCreateButton(d->prefsWindow->locationFrame, WBTRadio);
  WMSetButtonText(d->prefsWindow->woeid, "WOEID");
  WMMoveWidget(d->prefsWindow->woeid, 10, 20);
  if (strcmp(d->prefsWindow->prefs->woeid_or_zip, "w") == 0)
    WMSetButtonSelected(d->prefsWindow->woeid, 1);
  WMRealizeWidget(d->prefsWindow->woeid);
  WMMapWidget(d->prefsWindow->woeid);

  d->prefsWindow->woeidField = WMCreateTextField(d->prefsWindow->locationFrame);
  WMSetTextFieldText(d->prefsWindow->woeidField, d->prefsWindow->prefs->woeid);
  WMResizeWidget(d->prefsWindow->woeidField, 60, 20);
  WMMoveWidget(d->prefsWindow->woeidField, 90, 20);
  WMRealizeWidget(d->prefsWindow->woeidField);
  WMMapWidget(d->prefsWindow->woeidField);

  d->prefsWindow->zip = WMCreateButton(d->prefsWindow->locationFrame, WBTRadio);
  WMSetButtonText(d->prefsWindow->zip, "ZIP code");
  WMMoveWidget(d->prefsWindow->zip, 10, 44);
  if (strcmp(d->prefsWindow->prefs->woeid_or_zip, "z") == 0)
    WMSetButtonSelected(d->prefsWindow->zip, 1);
  WMRealizeWidget(d->prefsWindow->zip);
  WMMapWidget(d->prefsWindow->zip);

  d->prefsWindow->zipField = WMCreateTextField(d->prefsWindow->locationFrame);
  WMSetTextFieldText(d->prefsWindow->zipField, d->prefsWindow->prefs->zip);
  WMResizeWidget(d->prefsWindow->zipField, 60, 20);
  WMMoveWidget(d->prefsWindow->zipField, 90, 44);
  WMRealizeWidget(d->prefsWindow->zipField);
  WMMapWidget(d->prefsWindow->zipField);

  d->prefsWindow->intervalFrame = WMCreateFrame(d->prefsWindow->window);
  WMSetFrameTitle(d->prefsWindow->intervalFrame, "Refresh interval");
  WMResizeWidget(d->prefsWindow->intervalFrame, 112, 80);
  WMMoveWidget(d->prefsWindow->intervalFrame, 302, 10);
  WMRealizeWidget(d->prefsWindow->intervalFrame);
  WMMapWidget(d->prefsWindow->intervalFrame);

  WMGroupButtons(d->prefsWindow->woeid, d->prefsWindow->zip);

  d->prefsWindow->interval = WMCreateTextField(d->prefsWindow->intervalFrame);
  sprintf(intervalPtr, "%lu", d->prefsWindow->prefs->interval);
  WMSetTextFieldText(d->prefsWindow->interval, intervalPtr);
  WMResizeWidget(d->prefsWindow->interval, 30, 20);
  WMMoveWidget(d->prefsWindow->interval, 15, 33);
  WMRealizeWidget(d->prefsWindow->interval);
  WMMapWidget(d->prefsWindow->interval);

  d->prefsWindow->minutes = WMCreateLabel(d->prefsWindow->intervalFrame);
  WMSetLabelText(d->prefsWindow->minutes, "minutes");
  WMMoveWidget(d->prefsWindow->minutes, 45, 35);
  WMRealizeWidget(d->prefsWindow->minutes);
  WMMapWidget(d->prefsWindow->minutes);

  d->prefsWindow->colors = WMCreateFrame(d->prefsWindow->window);
  WMSetFrameTitle(d->prefsWindow->colors, "Colors");
  WMResizeWidget(d->prefsWindow->colors, 265, 50);
  WMMoveWidget(d->prefsWindow->colors, 10, 92);
  WMRealizeWidget(d->prefsWindow->colors);
  WMMapWidget(d->prefsWindow->colors);

  d->prefsWindow->backgroundLabel = WMCreateLabel(d->prefsWindow->colors);
  WMSetLabelText(d->prefsWindow->backgroundLabel, "Background");
  WMSetLabelTextAlignment(d->prefsWindow->backgroundLabel, WACenter);
  WMResizeWidget(d->prefsWindow->backgroundLabel, 70, 20);
  WMMoveWidget(d->prefsWindow->backgroundLabel, 10, 20);
  WMRealizeWidget(d->prefsWindow->backgroundLabel);
  WMMapWidget(d->prefsWindow->backgroundLabel);

  d->prefsWindow->background = WMCreateColorWell(d->prefsWindow->colors);
  WMSetColorWellColor(d->prefsWindow->background, WMCreateNamedColor(d->screen, d->prefs->background, True));
  WMMoveWidget(d->prefsWindow->background, 88, 16);
  WMRealizeWidget(d->prefsWindow->background);
  WMMapWidget(d->prefsWindow->background);

  d->prefsWindow->textLabel = WMCreateLabel(d->prefsWindow->colors);
  WMSetLabelText(d->prefsWindow->textLabel, "Text");
  WMSetLabelTextAlignment(d->prefsWindow->textLabel, WACenter);
  WMResizeWidget(d->prefsWindow->textLabel, 26, 20);
  WMMoveWidget(d->prefsWindow->textLabel, 156, 20);
  WMRealizeWidget(d->prefsWindow->textLabel);
  WMMapWidget(d->prefsWindow->textLabel);

  d->prefsWindow->text = WMCreateColorWell(d->prefsWindow->colors);
  WMSetColorWellColor(d->prefsWindow->text,
                      WMCreateNamedColor(d->screen, d->prefs->text, True));
  WMMoveWidget(d->prefsWindow->text, 190, 16);
  WMRealizeWidget(d->prefsWindow->text);
  WMMapWidget(d->prefsWindow->text);

  d->prefsWindow->save = WMCreateButton(d->prefsWindow->window,
                                        WBTMomentaryPush);
  WMSetButtonText(d->prefsWindow->save, "Save");
  WMSetButtonAction(d->prefsWindow->save, savePreferences, d);
  WMMoveWidget(d->prefsWindow->save, 285, 110);
  WMRealizeWidget(d->prefsWindow->save);
  WMMapWidget(d->prefsWindow->save);

  d->prefsWindow->close = WMCreateButton(d->prefsWindow->window,
                                         WBTMomentaryPush);
  WMSetButtonText(d->prefsWindow->close, "Close");
  WMSetButtonAction(d->prefsWindow->close, closePreferences, d);
  WMMoveWidget(d->prefsWindow->close, 353, 110);
  WMRealizeWidget(d->prefsWindow->close);
  WMMapWidget(d->prefsWindow->close);
}

static void refresh(XEvent *event, void *data)
{
	Dockapp *d = (Dockapp *)data;
	if (WMIsDoubleClick(event) && event->xbutton.button == Button1) {
		d->minutesLeft = d->prefs->interval;
		updateDockapp(d);
	}
	if (event->xbutton.button == Button3 && !d->prefsWindowPresent)
		editPreferences(d);
}

static void timerHandler(void *data)
{
	Dockapp *d = (Dockapp *)data;

	d->minutesLeft--;
	if (d->minutesLeft == 0) {
		d->minutesLeft = d->prefs->interval;
		updateDockapp(data);
	}
}

int main(int argc, char **argv)
{
  Display *display;
  Dockapp *dockapp;
  Preferences *prefs;
  WMScreen *screen;

  WMInitializeApplication("wmforecast", &argc, argv);

  prefs = setPreferences(argc, argv);

  display = XOpenDisplay("");

  screen = WMCreateScreen(display, DefaultScreen(display));
  dockapp = newDockapp(screen, prefs, argc, argv);

  /* WMCreateEventHandler(WMWidgetView(dockapp->icon), ButtonPressMask, */
  /* 		     refresh, dockapp); */

  /* updateDockapp(dockapp); */
  /* WMAddPersistentTimerHandler(60*1000, /\* one minute *\/ */
  /* 			    timerHandler, dockapp); */

  WMScreenMainLoop(screen);
}
