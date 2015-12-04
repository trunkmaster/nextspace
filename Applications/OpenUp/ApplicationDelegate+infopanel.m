/*
 File:       ApplicationDelegate+infopanel.m
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include "ApplicationDelegate.h"
#include "NSColor+utils.h"

@implementation ApplicationDelegate(infopanel)

- showInfoPanel:sender;
{
  // Its becoming a pain keeping the info panel which outlines
  // the capabilities of the application in sync with its
  // capabilities, across both OpenStep and Rhapsody as well,
  // every time I make a release, I need to open up IB to change
  // the release number time to fix that

  NSString *version = [[NSBundle mainBundle] pathForResource:@"version" ofType:@""];
  NSString *versionFormat = [infoPanelTextField stringValue];
    
  [infoPanelTextField setStringValue:
						[NSString stringWithFormat:versionFormat, 
								  [NSString stringWithContentsOfFile:version]]];

  if (!infoPanelSupportedTypes)
	infoPanelSupportedTypes = [[self infoAboutSupportedFileExtensions] retain];

  [infoTableView setBackgroundColor:[NSColor tanTextBackgroundColor]];

  [[[infoTableView tableColumnWithIdentifier:@"tools"] headerCell] setFont:[NSFont systemFontOfSize:10]];
  [[[infoTableView tableColumnWithIdentifier:@"extensions"] headerCell] setFont:[NSFont systemFontOfSize:10]];
  [[[infoTableView tableColumnWithIdentifier:@"comments"] headerCell] setFont:[NSFont systemFontOfSize:10]];

  [[[infoTableView tableColumnWithIdentifier:@"tools"] dataCell] setFont:[NSFont systemFontOfSize:10]];
  [[[infoTableView tableColumnWithIdentifier:@"extensions"] dataCell] setFont:[NSFont systemFontOfSize:10]];
  [[[infoTableView tableColumnWithIdentifier:@"comments"] dataCell] setFont:[NSFont systemFontOfSize:10]];

  [infoTableView setDataSource:infoPanelSupportedTypes];
  [infoTableView reloadData];

  [infoPanel makeKeyAndOrderFront:self];

  return self;
}


- (NSArray *)infoAboutSupportedFileExtensions;
{
  NSEnumerator        *overFileTypes;
  NSDictionary        *eachFileType;
  NSMutableArray      *outputArray=[NSMutableArray array];
  NSMutableDictionary *tempDict;

  overFileTypes = [fileTypeConfigArray objectEnumerator];
  while ( (eachFileType = [overFileTypes nextObject]) )
	{
	  id extensions = [eachFileType objectForKey:@"file_extension"];
	  id tools;
	  id wrappedTools;

	  wrappedTools = [eachFileType objectForKey:@"wrapped_programs"];
	  if (wrappedTools)
		{
		  if (![wrappedTools isKindOfClass:[NSArray class]])
			{
			  wrappedTools = [NSArray arrayWithObject:wrappedTools];
			}
		  tools = [wrappedTools componentsJoinedByString:@","];
		}
	  else
		tools=@"";

	  if ( [extensions isKindOfClass:[NSArray class]])
		{
		  int i;
		  for (i=0; i < [extensions count]; i++)
			{
			  id       comments = [eachFileType objectForKey:@"Comments"];
			  NSString *tempString;

			  tempString = [[NSBundle mainBundle] 
							 localizedStringForKey:[extensions objectAtIndex:i]
							 value:@"MISSING"
							 table:@"filesConfigComments"];
			  if (![tempString isEqual:@"MISSING"])
				comments = tempString;
                
			  if ([comments isKindOfClass:[NSDictionary class]])
				comments = [[eachFileType objectForKey:@"Comments"] 
							 objectForKey:[extensions objectAtIndex:i]];

			  tempDict = [NSMutableDictionary dictionary];
			  [tempDict setObject:[extensions objectAtIndex:i] 
						forKey:@"extensions"];
			  [tempDict setObject:tools forKey:@"tools"];
			  if (comments)
				[tempDict setObject:comments forKey:@"comments"];
			  else
				[tempDict setObject:@"" forKey:@"comments"];

			  [outputArray addObject:tempDict];
			}
		}
	  else
		{
		  id comments=[eachFileType objectForKey:@"Comments"];
		  NSString *tempString;
		  tempString=[[NSBundle mainBundle] localizedStringForKey:extensions
											value:@"MISSING"
											table:@"filesConfigComments"];
		  if (![tempString isEqual:@"MISSING"])
			comments=tempString;

		  tempDict=[NSMutableDictionary dictionary];
		  [tempDict setObject:extensions forKey:@"extensions"];
		  [tempDict setObject:tools forKey:@"tools"];
		  if (comments)
			[tempDict setObject:comments forKey:@"comments"];
		  else
			[tempDict setObject:@"" forKey:@"comments"];
		  
		  [outputArray addObject:tempDict];
		}
	}

  return [NSArray arrayWithArray:outputArray];
}

@end
