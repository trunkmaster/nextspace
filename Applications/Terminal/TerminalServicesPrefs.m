/*
  Copyright (C) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#include <Foundation/Foundation.h>
#include <AppKit/NSButton.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSTableView.h>
#include <AppKit/NSTableColumn.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSClipView.h>
#include <AppKit/NSBox.h>
#include <GNUstepGUI/GSVbox.h>
#include <GNUstepGUI/GSHbox.h>
#include <AppKit/NSSavePanel.h>
#include <AppKit/NSOpenPanel.h>
#include "Label.h"

#include "TerminalServicesPrefs.h"

#include "TerminalServices.h"


@implementation TerminalServicesPrefs

- (void)_update
{
  NSString *name,*new_name;
  NSMutableDictionary *d;
  int i;

  if (current < 0)
    return;

  name = [service_list objectAtIndex:current];
  new_name = [tf_name stringValue];
  if (![new_name length])
    new_name = name;
  d = [services objectForKey:name];
  if (!d)
    d = [[NSMutableDictionary alloc] init];

  [d setObject: [tf_key stringValue]
        forKey: Key];
  [d setObject: [tf_cmdline stringValue]
        forKey: Commandline];
  [d setObject: [NSString stringWithFormat: @"%li",[pb_input indexOfSelectedItem]]
        forKey: Input];
  [d setObject: [NSString stringWithFormat: @"%li",[pb_output indexOfSelectedItem]]
        forKey: ReturnData];
  [d setObject: [NSString stringWithFormat: @"%li",[pb_type indexOfSelectedItem]]
        forKey: Type];

  i=0;
  if ([cb_string state]) i|=1;
  if ([cb_filenames state]) i|=2;
  [d setObject: [NSString stringWithFormat: @"%i",i]
        forKey: AcceptTypes];

  if (![name isEqual: new_name])
    {
      [services setObject: d
                   forKey: new_name];
      [services removeObjectForKey: name];
      [service_list replaceObjectAtIndex: current
                              withObject: new_name];
      [list reloadData];
    }
}


-(void) save
{
	NSUserDefaults *ud;

	if (!services) return;
	if (!top) return;

	[self _update];

	ud=[NSUserDefaults standardUserDefaults];

	if (![services isEqual: [TerminalServices terminalServicesDictionary]])
	{
		[ud setObject: [services copy]
			forKey: @"TerminalServices"];

		[TerminalServices updateServicesPlist];
	}
}

-(void) revert
{
	NSDictionary *d;

	[list deselectAll: self];
	DESTROY(services);
	DESTROY(service_list);

	services=[[NSMutableDictionary alloc] init];
	d=[TerminalServices terminalServicesDictionary];

	{
		NSEnumerator *e=[d keyEnumerator];
		NSString *key;
		while ((key=[e nextObject]))
		{
			[services setObject: [[d objectForKey: key] mutableCopy]
				forKey: key];
		}
	}

	service_list=[[[services allKeys]
		sortedArrayUsingSelector: @selector(compare:)]
		mutableCopy];

	[list reloadData];
	current=-1;
	[self tableViewSelectionDidChange: nil];
}


- (int)numberOfRowsInTableView: (NSTableView *)tv
{
	return [service_list count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc  row:(int)row
{
  return [service_list objectAtIndex:row];
}

-(void) tableViewSelectionDidChange: (NSNotification *)n
{
	int r=[list selectedRow];

	if (current>=0)
		[self _update];

	if (r>=0)
	{
		int i;
		NSString *name,*s;
		NSDictionary *d;

		name=[service_list objectAtIndex: r];
		d=[services objectForKey: name];

		[tf_name setEditable: YES];
		[tf_cmdline setEditable: YES];
		[tf_key setEditable: YES];
		[pb_input setEnabled: YES];
		[pb_output setEnabled: YES];
		[pb_type setEnabled: YES];
		[cb_string setEnabled: YES];
		[cb_filenames setEnabled: YES];

		[tf_name setStringValue: name];

		s=[d objectForKey: Key];
		[tf_key setStringValue: s?s:@""];

		s=[d objectForKey: Commandline];
		[tf_cmdline setStringValue: s?s:@""];

		i=[[d objectForKey: Type] intValue];
		if (i<0 || i>2) i=0;
		[pb_type selectItemAtIndex: i];

		i=[[d objectForKey: Input] intValue];
		if (i<0 || i>2) i=0;
		[pb_input selectItemAtIndex: i];

		i=[[d objectForKey: ReturnData] intValue];
		if (i<0 || i>1) i=0;
		[pb_output selectItemAtIndex: i];

		if ([d objectForKey: AcceptTypes])
		{
			i=[[d objectForKey: AcceptTypes] intValue];
			[cb_string setState: !!(i&1)];
			[cb_filenames setState: !!(i&2)];
		}
		else
		{
			[cb_string setState: 1];
			[cb_filenames setState: 0];
		}
	}
	else
	{
		[tf_name setEditable: NO];
		[tf_cmdline setEditable: NO];
		[tf_key setEditable: NO];
		[pb_input setEnabled: NO];
		[pb_output setEnabled: NO];
		[pb_type setEnabled: NO];
		[cb_string setEnabled: NO];
		[cb_filenames setEnabled: NO];

		[tf_name setStringValue: @""];
		[tf_key setStringValue: @""];
		[tf_cmdline setStringValue: @""];
	}

	current=r;
}


-(void) _removeService: (id)sender
{
	NSString *name;
	if (current<0)
		return;
	[list deselectAll: self];

	name=[service_list objectAtIndex: current];
	[services removeObjectForKey: name];
	[service_list removeObjectAtIndex: current];

	[list reloadData];
	current=-1;
	[self tableViewSelectionDidChange: nil];
}

-(void) _addService: (id)sender
{
	NSString *n=_(@"Unnamed service");
	[service_list addObject: n];
	[list reloadData];
	[list selectRow: [service_list count]-1 byExtendingSelection: NO];
}


-(void) _importServices: (id)sender
{
	NSOpenPanel *op;
	NSDictionary *d;
	NSEnumerator *e;
	NSString *name;
	int result;

	[self save];

	op=[NSOpenPanel openPanel];
	[op setAccessoryView: nil];
	[op setTitle: _(@"Import services")];
	[op setAllowsMultipleSelection: NO];
	[op setCanChooseDirectories: NO];
	[op setCanChooseFiles: YES];

	result=[op runModal];

	if (result!=NSOKButton)
		return;

	d=[NSDictionary dictionaryWithContentsOfFile: [op filename]];
	d=[d objectForKey: @"TerminalServices"];
	if (!d)
	{
		NSString *s=[NSString stringWithContentsOfFile: [op filename]];
		NSArray *lines=[s componentsSeparatedByString: @"\n"];
		NSArray *parts;
		int c=[lines count];
		int i,j,k;
		NSMutableDictionary *md=[[[NSMutableDictionary alloc] init] autorelease];
		NSMutableDictionary *service;

		for (i=0;i<c;i+=3)
		{
			if (i+3>=c)
				break;
		
			parts=[[lines objectAtIndex: i] componentsSeparatedByString: @" "];
			if ([parts count]!=11)
				break;

			service=[[NSMutableDictionary alloc] init];

			[service setObject: [lines objectAtIndex: i+2]
				forKey: Commandline];

			j=[[parts objectAtIndex: 0] intValue];
			if (j!=32)
			{
				unichar ch=j;
				[service setObject: [NSString stringWithCharacters: &ch length: 1]
					forKey: Key];
			}

			j=[[parts objectAtIndex: 2] intValue];
			k=0;
			if (j&3) /* TODO? why 1 and 2? */
				k|=ACCEPT_STRING;
			if (j&8)
				k|=ACCEPT_FILENAMES;
			[service setObject: [NSString stringWithFormat: @"%i",k]
				forKey: AcceptTypes];

			if (j==1)
			{
				k=0;
			}
			else
			{
				j=[[parts objectAtIndex: 3] intValue];
				if (j==2)
					k=INPUT_CMDLINE;
				else if (j==4)
					k=INPUT_STDIN;
				else
					k=INPUT_NO;
			}
			[service setObject: [NSString stringWithFormat: @"%i",k]
				forKey: Input];

			j=[[parts objectAtIndex: 8] intValue];
			if (j==3)
				k=1;
			else
				k=0;
			[service setObject: [NSString stringWithFormat: @"%i",k]
				forKey: ReturnData];

			j=[[parts objectAtIndex: 5] intValue];
			if (j==2)
				k=TYPE_WINDOW_IDLE;
			else if (j==4)
				k=TYPE_WINDOW_NEW;
			else
				k=TYPE_BACKGROUND;
			[service setObject: [NSString stringWithFormat: @"%i",k]
				forKey: Type];

			[md setObject: service
				forKey: [lines objectAtIndex: i+1]];
		}

		if (i<c && (i!=c-1 || [[lines objectAtIndex: i] length]!=0))
		{
			NSRunAlertPanel(_(@"Error importing services"),
				_(@"The file '%@' doesn't contain valid terminal services."),
				nil,nil,nil,
				[op filename]);
			return;
		}
		d=md;
	}

	e=[d keyEnumerator];
	while ((name=[e nextObject]))
	{
		NSString *new_name;
		NSDictionary *service,*s2;
		int i;

		service=[d objectForKey: name];
		new_name=name;
		i=2;
		while (1)
		{
			s2=[services objectForKey: new_name];
			if (!s2 || [s2 isEqual: service])
				break;

			new_name=[NSString stringWithFormat: @"%@ (%i)",
				name,i];
			i++;
		}

		if (!s2)
		{
			[services setObject: service
				forKey: new_name];
			[service_list addObject: new_name];
		}
	}

	[self save]; /* update external service list */
	[self revert]; /* reload views */
	[list reloadData];
}


-(void) _exportServices: (id)sender
{
	NSSavePanel *sp;
	NSTableView *tv;
	int result;

	[self save];

	sp=[NSSavePanel savePanel];
	[sp setTitle: _(@"Export services")];

	{
		NSScrollView *sv;
		NSTableColumn *c_name;

		sv=[[NSScrollView alloc] initWithFrame: NSMakeRect(0,0,260,100)];
		[sv setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
		[sv setHasVerticalScroller: YES];
		[sv setHasHorizontalScroller: NO];
		[sv setBorderType: NSBezelBorder];

		c_name=[[NSTableColumn alloc] initWithIdentifier: @"Name"];
		[c_name setEditable: NO];
		[c_name setResizable: YES];
		[c_name setWidth: 260];

		tv=[[NSTableView alloc] initWithFrame: [[sv contentView] frame]];
		[tv setAllowsMultipleSelection: YES];
		[tv setAllowsColumnSelection: NO];
		[tv setAllowsEmptySelection: NO];
		[tv addTableColumn: c_name];
		DESTROY(c_name);
		[tv setAutoresizesAllColumnsToFit: YES];
		[tv setDataSource: self];
		[tv setDelegate: self];
		[tv setHeaderView: nil];
		[tv setCornerView: nil];
		[tv reloadData];
		[tv selectAll: self];

		[sv setDocumentView: tv];
		[sp setAccessoryView: sv];
		DESTROY(sv);
	}

	result=[sp runModal];

	if (result==NSOKButton)
	{
		NSEnumerator *e;
		NSNumber *n;
		NSMutableDictionary *d;
		NSDictionary *d2;
		NSString *name;

		d=[[NSMutableDictionary alloc] init];

		for (e=[tv selectedRowEnumerator];
		     (n=[e nextObject]);)
		{
			name=[service_list objectAtIndex: [n intValue]];
			[d setObject: [services objectForKey: name]
				forKey: name];
		}
		d2=[NSDictionary dictionaryWithObject: d
			forKey: @"TerminalServices"];
		[d2 writeToFile: [sp filename] atomically: NO];
		DESTROY(d);
	}

	DESTROY(tv);
	[sp setAccessoryView: nil];
}


-(NSString *) name
{
	return _(@"Terminal services");
}

-(void) setupButton: (NSButton *)b
{
	[b setTitle: _(@"Terminal\nservices")];
	[b sizeToFit];
}

-(void) willHide
{
}

-(NSView *) willShow
{
	if (!top)
	{
		GSHbox *hb;
	
		top=[[GSVbox alloc] init];
		[top setDefaultMinYMargin: 4];
		
		{
			GSHbox *hb;
			NSButton *b;

			hb=[[GSHbox alloc] init];
			[hb setDefaultMinXMargin: 4];
			[hb setAutoresizingMask: NSViewMinXMargin];

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Add")];
			[b setTarget: self];
			[b setAction: @selector(_addService:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Remove")];
			[b setTarget: self];
			[b setAction: @selector(_removeService:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Import...")];
			[b setTarget: self];
			[b setAction: @selector(_importServices:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Export...")];
			[b setTarget: self];
			[b setAction: @selector(_exportServices:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			[top addView: hb enablingYResizing: NO];
			DESTROY(hb);
		}

		hb=[[GSHbox alloc] init];
		[hb setDefaultMinXMargin: 4];
		[hb setAutoresizingMask: NSViewWidthSizable];

		{
			NSPopUpButton *b;
			GSVbox *vb;

			vb=[[GSVbox alloc] init];
			[vb setDefaultMinYMargin: 4];
			[vb setAutoresizingMask: NSViewMaxXMargin];

			b=pb_output=[[NSPopUpButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setAutoenablesItems: NO];
			[b addItemWithTitle: _(@"Ignore output")];
			[b addItemWithTitle: _(@"Return output")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			b=pb_input=[[NSPopUpButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setAutoenablesItems: NO];
			[b addItemWithTitle: _(@"No input")];
			[b addItemWithTitle: _(@"Input in stdin")];
			[b addItemWithTitle: _(@"Input on command line")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			b=pb_type=[[NSPopUpButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setAutoenablesItems: NO];
			[b addItemWithTitle: _(@"Run in background")];
			[b addItemWithTitle: _(@"Run in new window")];
			[b addItemWithTitle: _(@"Run in idle window")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			[hb addView: vb enablingXResizing: YES];
			DESTROY(vb);
		}

		{
			NSButton *b;
			NSBox *box;
			GSVbox *vb;

			box=[[NSBox alloc] init];
			[box setTitle: _(@"Accept types")];
			[box setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin];

			vb=[[GSVbox alloc] init];
			[vb setDefaultMinYMargin: 4];

			b=cb_filenames=[[NSButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setButtonType: NSSwitchButton];
			[b setTitle: _(@"Filenames")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			b=cb_string=[[NSButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setButtonType: NSSwitchButton];
			[b setTitle: _(@"Plain text")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			[box setContentView: vb];
			[box sizeToFit];
			DESTROY(vb);
			[hb addView: box enablingXResizing: YES];
			DESTROY(box);
		}

		[top addView: hb enablingYResizing: NO];
		DESTROY(hb);

		{
			GSTable *t;
			NSTextField *f;


			t=[[GSTable alloc] initWithNumberOfRows: 3 numberOfColumns: 2];
			[t setAutoresizingMask: NSViewWidthSizable];
			[t setXResizingEnabled: NO forColumn: 0];
			[t setXResizingEnabled: YES forColumn: 1];

			f=[NSTextField newLabel: _(@"Name:")];
			[f setAutoresizingMask: NSViewMinXMargin];
			[f setAutoresizingMask: 0];
			[t putView: f atRow: 2 column: 0 withXMargins: 2 yMargins: 2];
			DESTROY(f);

			tf_name=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable];
			[f sizeToFit];
			[t putView: f atRow: 2 column: 1];
			DESTROY(f);


			f=[NSTextField newLabel: _(@"Key:")];
			[f setAutoresizingMask: NSViewMinXMargin];
			[f setAutoresizingMask: 0];
			[t putView: f atRow: 1 column: 0 withXMargins: 2 yMargins: 2];
			DESTROY(f);

			tf_key=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable];
			[f sizeToFit];
			[t putView: f atRow: 1 column: 1];
			DESTROY(f);


			f=[NSTextField newLabel: _(@"Command line:")];
			[f setAutoresizingMask: NSViewMinXMargin];
			[f setAutoresizingMask: 0];
			[t putView: f atRow: 0 column: 0 withXMargins: 2 yMargins: 2];
			DESTROY(f);

			tf_cmdline=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable];
			[f sizeToFit];
			[t putView: f atRow: 0 column: 1];
			DESTROY(f);


			[top addView: t enablingYResizing: NO];
			DESTROY(t);
		}

		{
			NSScrollView *sv;
			NSTableColumn *c_name;

			sv=[[NSScrollView alloc] init];
			[sv setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
			[sv setHasVerticalScroller: YES];
			[sv setHasHorizontalScroller: NO];
			[sv setBorderType: NSBezelBorder];

			c_name=[[NSTableColumn alloc] initWithIdentifier: @"Name"];
			[c_name setEditable: NO];
			[c_name setResizable: YES];

			list=[[NSTableView alloc] initWithFrame: [[sv contentView] frame]];
			[list setAllowsMultipleSelection: NO];
			[list setAllowsColumnSelection: NO];
			[list setAllowsEmptySelection: NO];
			[list addTableColumn: c_name];
			DESTROY(c_name);
			[list setAutoresizesAllColumnsToFit: YES];
			[list setDataSource: self];
			[list setDelegate: self];
			[list setHeaderView: nil];
			[list setCornerView: nil];

			[sv setDocumentView: list];
			[top addView: sv enablingYResizing: YES];
			[list release];
			DESTROY(sv);
		}

		current=-1;
		[self revert];
	}
	return top;
}

-(void) dealloc
{
	DESTROY(top);
	DESTROY(services);
	DESTROY(service_list);
	[super dealloc];
}

@end

