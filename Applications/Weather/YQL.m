//
//  YQL.m
//  yql-ios
//
//  Created by Guilherme Chapiewski on 10/19/12.
//  Copyright (c) 2012 Guilherme Chapiewski. All rights reserved.
//  Adopted to GNUstep by Sergii Stoian on 12/08/16.
//

#import "YQL.h"

#define QUERY_PREFIX @"http://query.yahooapis.com/v1/public/yql?q="
#define QUERY_SUFFIX @"&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback="

@implementation NSString (Modifications)

// TODO: modify original gnustep-back method
- (NSString*)stringByAddingPercentEscapesUsingEncoding
{
  NSData        *data = [self dataUsingEncoding:NSASCIIStringEncoding];
  NSString      *s = nil;

  if (data != nil)
    {
      unsigned char     *src = (unsigned char*)[data bytes];
      unsigned int      slen = [data length];
      unsigned char     *dst;
      unsigned int      spos = 0;
      unsigned int      dpos = 0;
      BOOL              openQuote = NO;

      dst = (unsigned char*)NSZoneMalloc(NSDefaultMallocZone(), slen * 3);
      while (spos < slen)
        {
          unsigned char c = src[spos++];
          unsigned int  hi;
          unsigned int  lo;

          if (c <= 32 || c > 126 || c == 34 || c == 35 || c == 37
              || c == 60 || c == 61|| c == 62 || c == 91 || c == 92 || c == 93
              || c == 94 || c == 96 || c == 123 || c == 124 || c == 125)
            {
              // quoted text ends with space: adding quote before space
              if (c == 32 && openQuote == YES)
                {
                  dst[dpos++] = '%';
                  dst[dpos++] = '2';
                  dst[dpos++] = '2';
                  openQuote = NO;
                }
              
              dst[dpos++] = '%';
              hi = (c & 0xf0) >> 4;
              dst[dpos++] = (hi > 9) ? 'A' + hi - 10 : '0' + hi;
              lo = (c & 0x0f);
              dst[dpos++] = (lo > 9) ? 'A' + lo - 10 : '0' + lo;

              // '=' found: adding quote
              if (c == 61)
                {
                  dst[dpos++] = '%';
                  dst[dpos++] = '2';
                  dst[dpos++] = '2';
                  openQuote = YES;
                }
            }
          else
            {
              dst[dpos++] = c;
            }
        }
      if (openQuote == YES)
        {
          dst[dpos++] = '%';
          dst[dpos++] = '2';
          dst[dpos++] = '2';
        }
      s = [[NSString alloc] initWithBytes: dst
                                   length: dpos
                                 encoding: NSASCIIStringEncoding];
      NSZoneFree(NSDefaultMallocZone(), dst);
      IF_NO_GC([s autorelease];);
    }
  return s;
}

@end

@implementation YQL

- (NSDictionary *)query:(NSString *)statement
{
  NSString     *query;
  NSString     *queryData;
  NSData       *jsonData;
  NSError      *error = nil;
  NSDictionary *results = nil;

  // Prepare YQL query using modified NSString method implemented above
  query = [NSString stringWithFormat:@"%@%@%@",
                    QUERY_PREFIX,
                    [statement stringByAddingPercentEscapesUsingEncoding],
                    QUERY_SUFFIX];
  // NSLog(@"Yahoo query URL: %@", query);
  
  queryData = [NSString stringWithContentsOfURL:[NSURL URLWithString:query]
                                       encoding:NSUTF8StringEncoding
                                          error:&error];
  if (error)
    {
      NSLog(@"[%@ %@] NSURL error: %@",
            NSStringFromClass([self class]),
            NSStringFromSelector(_cmd),
            error.localizedDescription);
      return nil;
    }
  
  if ((jsonData = [queryData dataUsingEncoding:NSUTF8StringEncoding]))
    {
      results = [NSJSONSerialization JSONObjectWithData:jsonData
                                                options:0
                                                  error:&error];
    }

  if (error)
    {
      NSLog(@"[%@ %@] JSON error: %@",
            NSStringFromClass([self class]),
            NSStringFromSelector(_cmd),
            error.localizedDescription);
    }
    
  return results;
}

@end
