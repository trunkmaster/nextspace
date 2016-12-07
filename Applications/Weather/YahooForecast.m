/*
  Class:               YahooForecast
  Inherits from:       NSObject
  Class descritopn:    Get and parse weather forecast from yahoo.com

  Copyright (C) 2014-2016 Doug Torrance <dtorrance@piedmont.edu>
  Copyright (C) 2016 Sergii Stoian <stoian255@ukr.net>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <curl/curl.h>
#include <errno.h>
#include <getopt.h>
#include <libgen.h>
#include <libxml/tree.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <WINGs/WINGs.h>

#import "YahooForecast.h"

@implementation YahooForecast : NSObject

- (id)init
{
  forecastList = [[NSMutableArray alloc] init];
  weatherCondition = [[NSMutableDictionary alloc] init];
  [weatherCondition setObject:forecastList forKey:@"Forecasts"];
  return self;
}

- (void)dealloc
{
  [weatherCondition release];
  [forecastList release];
  [super dealloc];
}

- (void)setTitle:(const char*)title
{
  NSLog(@"Set title: %@", [NSString stringWithCString:title]);
  [weatherCondition setObject:[NSString stringWithCString:title]
                       forKey:@"Title"];
}

- (void)setTemperature:(xmlChar *)temp
         conditionDesc:(xmlChar *)text
         conditionCode:(xmlChar *)code
{
  NSString *imageName;
  
  [weatherCondition setObject:[NSString stringWithCString:(const char*)temp]
                       forKey:@"Temperature"];
  [weatherCondition setObject:[NSString stringWithCString:(const char*)text]
                       forKey:@"Description"];

  imageName = [NSString stringWithFormat:@"%s.png", code];
  [weatherCondition setObject:[NSImage imageNamed:imageName]
                       forKey:@"Image"];
}

- (void)appendForecastForDay:(xmlChar *)day
                    highTemp:(xmlChar *)high
                     lowTemp:(xmlChar *)low
                 description:(xmlChar *)desc
{
  NSDictionary *dayForecast;

  dayForecast =
    [NSDictionary dictionaryWithObjectsAndKeys:
                   [NSString stringWithCString:(const char*)day],  @"Day",
                   [NSString stringWithCString:(const char*)high], @"High",
                   [NSString stringWithCString:(const char*)low],  @"Low",
                   [NSString stringWithCString:(const char*)desc], @"Description"];
  NSLog(@"Append forecast: %@", dayForecast);
  [forecastList addObject:dayForecast];
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

- (NSDictionary *)fetchWeatherWithWOEID:(char *)woeid
                                zipCode:(char *)zip
                                  units:(char *)units
{
  char		*url;
  CURL		*curl_handle;
  CURLcode	res;
  struct MemoryStruct chunk;
  xmlDocPtr	doc;
  xmlNodePtr	cur;
  int		i;

  url = wstrdup("https://query.yahooapis.com/v1/public/yql?q="
                "select%20*%20from%20weather.forecast%20where%20woeid");
  if (strcmp(woeid, "") != 0)
    {
      NSLog(@"Fetch forecast using WOEID.");
      url = wstrappend(url, "%20%3D%20");
      url = wstrappend(url, woeid);
    }
  else
    {
      url = wstrappend(url, "%20in%20(select%20woeid%20from%20"
                       "geo.places(1)%20where%20text%3D%22");
      url = wstrappend(url, zip);
      url = wstrappend(url, "%22)");
    }
  url = wstrappend(url, "%20and%20u%3D'");
  url = wstrappend(url, units);
  url = wstrappend(url, "'&format=xml");
  /* url = wstrdup("https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20weather.forecast%20where%20woeid%20%3D%20924938&format=xml&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys"); */

  chunk.memory = wmalloc(1);
  chunk.size = 0;

  curl_global_init(CURL_GLOBAL_ALL);
  curl_handle = curl_easy_init();
  curl_easy_setopt(curl_handle, CURLOPT_URL, url);
  curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
  /* coverity[bad_sizeof] */
  curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&chunk);
  curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, "libcurl-agent/1.0");
  NSLog(@"Fetching data from %s...", url);
  res = curl_easy_perform(curl_handle);
  NSLog(@"Fetching data finished.");
  if (res != CURLE_OK)
    {
      [weatherCondition
        setObject:[NSString stringWithCString:curl_easy_strerror(res)]
           forKey:@"ErrorText"];
      curl_easy_cleanup(curl_handle);
      curl_global_cleanup();
      wfree(chunk.memory);
      return weatherCondition;
    }
  curl_easy_cleanup(curl_handle);
  curl_global_cleanup();

  doc = xmlParseMemory(chunk.memory, chunk.size);
  // wfree(chunk.memory);
  if (doc == NULL)
    {
      [weatherCondition setObject:@"Document was not parsed successfully."
                           forKey:@"ErrorText"];
      xmlFreeDoc(doc);
      return weatherCondition;
    }

  cur = xmlDocGetRootElement(doc);
  if (cur == NULL)
    {
      [weatherCondition setObject:@"Empty info from Yahoo was received."
                           forKey:@"ErrorText"];
      xmlFreeDoc(doc);
      return weatherCondition;
    }

  for (i = 0; i < 3; i++)
    {
      cur = cur->children;
      if (cur == NULL)
        {
          [weatherCondition setObject:@"Error occured while parsing Yahoo info."
                               forKey:@"ErrorText"];
          xmlFreeDoc(doc);
          return weatherCondition;
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
                      [weatherCondition setObject:@"City was not found."
                                           forKey:@"ErrorText"];
                    }
                  [self setTitle:(const char*)xmlNodeListGetString(doc, cur->children, 1)];

                }
              if ((!xmlStrcmp(cur->name, (const xmlChar *)"condition")))
                {
                  [self setTemperature:xmlGetProp(cur, (const xmlChar *)"temp")
                         conditionDesc:xmlGetProp(cur, (const xmlChar *)"text")
                         conditionCode:xmlGetProp(cur, (const xmlChar *)"code")];
                }
              if ((!xmlStrcmp(cur->name, (const xmlChar *)"forecast")))
                {
                  [self appendForecastForDay:xmlGetProp(cur, (const xmlChar *)"day")
                                    highTemp:xmlGetProp(cur, (const xmlChar *)"high")
                                     lowTemp:xmlGetProp(cur, (const xmlChar *)"low")
                                 description:xmlGetProp(cur, (const xmlChar *)"text")];
                }

              cur = cur->next;
            }
        }
      else
        {
          cur = cur->next;
        }
    }

  if ([forecastList count] > 0)
    {
      [weatherCondition setObject:forecastList forKey:@"Forecasts"];
    }

  [weatherCondition setObject:[NSDate date] forKey:@"Fetched"];

  xmlFreeDoc(doc);
  /* finish parsing xml */

  return weatherCondition;
}

@end
