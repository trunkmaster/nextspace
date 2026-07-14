/* GormObjectInspector.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include "GormObjectInspector.h"

@implementation GormObjectInspector

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      if([bundle loadNibNamed: @"GormObjectInspector" owner: self topLevelObjects: NULL] == NO)
	{
	  NSLog(@"Couldn't load GormObjectInsector");
	  return nil;
	}

      sets = [[NSMutableArray alloc] init];
      gets = [[NSMutableDictionary alloc] init];
      types = [[NSMutableDictionary alloc] init];

      [okButton setEnabled: NO];
      
      revertButton = nil;
    }
  return self;
}

- (NSInteger) browser: (NSBrowser*)sender numberOfRowsInColumn: (NSInteger)column
{
  return [sets count];
}

- (BOOL) browser: (NSBrowser*)sender
selectCellWithString: (NSString*)title
	inColumn: (NSInteger)col
{
  [self update: self];
  return YES;
}

- (NSString*) browser: (NSBrowser*)sender titleOfColumn: (NSInteger)col
{
  return @"Attribute setters";
}

- (void) browser: (NSBrowser*)sender
 willDisplayCell: (id)aCell
	   atRow: (NSInteger)row
	  column: (NSInteger)col
{
  if (row >= 0 && row < [sets count])
    {
      [aCell setStringValue: [sets objectAtIndex: row]];
      [aCell setEnabled: YES];
    }
  else
    {
      [aCell setStringValue: @""];
      [aCell setEnabled: NO];
    }
  [aCell setLeaf: YES];
}

- (void) dealloc
{
  RELEASE(gets);
  RELEASE(sets);
  RELEASE(types);
  [super dealloc];
}

- (void) ok: (id)sender
{
  NSString	*name = [[browser selectedCell] stringValue];
  NSUInteger	pos;

  if (name == nil || (pos = [sets indexOfObject: name]) == NSNotFound)
    {
      [label setTitle: _(@"No Type")];
      [value setStringValue: @""];
      [okButton setEnabled: NO];
    }
  else
    {
      SEL	set = NSSelectorFromString(name);
      NSString	*type = [types objectForKey: name];
      
      [super ok: sender];
      if (type == typeChar)
	{
	  char	v = [value intValue];
	  void	(*imp)(id,SEL,char);

	  imp = (void (*)(id,SEL,char))[object methodForSelector: set];
	  (*imp)(object, set, v);
	}
      else if (type == typeUChar)
	{
	  unsigned char	v = [value intValue];
	  void		(*imp)(id,SEL,unsigned char);

	  imp = (void (*)(id,SEL,unsigned char))[object methodForSelector: set];
	  (*imp)(object, set, v);
	}
      else if (type == typeInt)
	{
	  int	v = [value intValue];
	  void	(*imp)(id,SEL,int);

	  imp = (void (*)(id,SEL,int))[object methodForSelector: set];
	  (*imp)(object, set, v);
	}
      else if (type == typeUInt)
	{
	  unsigned int	v = [value intValue];
	  void		(*imp)(id,SEL,unsigned int);

	  imp = (void (*)(id,SEL,unsigned int))[object methodForSelector: set];
	  (*imp)(object, set, v);
	}
      else if (type == typeFloat)
	{
	  float	v = [value floatValue];
	  void	(*imp)(id,SEL,float);

	  imp = (void (*)(id,SEL,float))[object methodForSelector: set];
	  (*imp)(object, set, v);
	}
      else if (type == typeDouble)
	{
	  float	v = [value doubleValue];
	  void	(*imp)(id,SEL,double);

	  imp = (void (*)(id,SEL,double))[object methodForSelector: set];
	  (*imp)(object, set, v);
	}
      else
	{
	  id	v = [value stringValue];
	  IMP	imp = [object methodForSelector: set];

	  if (isString == YES)
	    {
	      (*imp)(object, set, v);
	    }
	  else
	    {
	      int	result;

	      v = [v stringByTrimmingSpaces];
	      result = NSRunAlertPanel(_(@"Settings"),
		[NSString stringWithFormat: _(@"Set object using '%@' as"), v],
				       _(@"Object name"),_( @"String"), _(@"Class name"));
	      if (result == NSAlertAlternateReturn)
		{
		  (*imp)(object, set, v);
		}
	      else if (result == NSAlertOtherReturn)
		{
		  Class	c = NSClassFromString(v);

		  if (c != 0)
		    {
		      (*imp)(object, set, [[c alloc] init]);
		    }
		}
	      else
		{
		  id	o = [[(id<IB>)[NSApp delegate] activeDocument] objectForName: v];

		  if (o != nil)
		    {
		      (*imp)(object, set, o);
		    }
		}
	    }
	}
      [self update: self];
    }
}

- (void) setObject: (id)anObject
{
  if (anObject != nil && anObject != object)
    {
      Class	c = [anObject class];

      ASSIGN(object, anObject);
      [sets removeAllObjects];
      [gets removeAllObjects];
      [types removeAllObjects];

      while (c != nil && c != [NSObject class])
	{
	      unsigned int		count;
	      Method			*methods = class_copyMethodList(c, &count);
	      int			i;

	      for (i = 0; i < count; i++)
		{
		  SEL		sSel = method_getName(methods[i]);
		  NSString	*set = NSStringFromSelector(sSel);

		  /*
		   * We are interested in methods that set values - they have
		   * a 'set' prefic and a colon as the last character.
		   * we ignore duplicates from superclasses.
		   */
		  if ([set hasPrefix: @"set"] == YES
		    && [set rangeOfString: @":"].location == [set length] - 1
		    && [sets containsObject: set] == NO)
		    {
		      char		tmp[[set cStringLength]+1];
		      const char	*tInfo = method_getTypeEncoding(methods[i]);
		      NSString		*type = nil;
		      NSString		*get;
		      SEL		gSel;

		      /*
		       * see if we can find an appropriate method to get the
		       * current value for an attribute we want to set.
		       */
		      [set getCString: tmp];
		      tmp[3] = tolower(tmp[3]);
		      tmp[strlen(tmp)-1] = '\0';
		      get = [NSString stringWithCString: &tmp[3]];
		      gSel = NSSelectorFromString(get);
		      if (gSel == 0 || [object respondsToSelector: gSel] == NO)
			{
			  get = nil;
			}

		      /*
		       * Skip the return type and the receiver and
		       * selector specifications to the first (only) arg.
		       */
		      tInfo = objc_skip_typespec(tInfo);
		      if (*tInfo == '+')
			{
			  tInfo++;
			}
		      while (isdigit(*tInfo))
			{
			  tInfo++;
			}
		      tInfo = objc_skip_argspec(tInfo);
		      tInfo = objc_skip_argspec(tInfo);

		      /*
		       * Now find arguments whose types we can reasonably
		       * deal with.
		       */
		      switch (*tInfo)
			{
			  case _C_ID:
			    type = typeId;
			    break;
			  case _C_CHR:
			    type = typeChar;
			    break;
			  case _C_UCHR:
			    type = typeUChar;
			    break;
			  case _C_INT:
			    type = typeInt;
			    break;
			  case _C_UINT:
			    type = typeUInt;
			    break;
			  case _C_FLT:
			    type = typeFloat;
			    break;
			  case _C_DBL:
			    type = typeDouble;
			    break;
			  default:
			    type = nil;
			    break;
			}
		      if (type != nil)
			{
			  [sets addObject: set];
			  if (get != nil)
			    {
			      [gets setObject: get forKey: set];
			    }
			  [types setObject: type forKey: set];
			}
		    }
		}
	  free(methods);
	  c = [c superclass]; 
	}
      [sets sortUsingSelector: @selector(compare:)];
      [browser loadColumnZero];
      [self update: self];
    }
}

- (void) update: (id)sender
{
  NSString	*name = [[browser selectedCell] stringValue];
  NSUInteger	pos;

  isString = NO;
  if (name == nil || (pos = [sets indexOfObject: name]) == NSNotFound)
    {
      [label setTitle: _(@"No Type")];
      [value setStringValue: @""];
      [okButton setEnabled: NO];
    }
  else if ([gets objectForKey: name] != nil)
    {
      SEL	get = NSSelectorFromString([gets objectForKey: name]);
      NSString	*type = [types objectForKey: name];

      [label setTitle: type];
      if (type == typeChar)
	{
	  char	v;
	  char	(*imp)();

	  imp = (char (*)())[object methodForSelector: get];
	  v = (*imp)(object, get);
	  [value setStringValue: [NSString stringWithFormat: @"%d", v]];
	}
      else if (type == typeUChar)
	{
	  unsigned char	v;
	  unsigned char	(*imp)();

	  imp = (unsigned char (*)())[object methodForSelector: get];
	  v = (*imp)(object, get);
	  [value setStringValue: [NSString stringWithFormat: @"%d", v]];
	}
      else if (type == typeInt)
	{
	  int	v;
	  int	(*imp)();

	  imp = (int (*)())[object methodForSelector: get];
	  v = (*imp)(object, get);
	  [value setStringValue: [NSString stringWithFormat: @"%d", v]];
	}
      else if (type == typeUInt)
	{
	  unsigned	v;
	  unsigned	(*imp)();

	  imp = (unsigned (*)()) [object methodForSelector: get];
	  v = (*imp)(object, get);
	  [value setStringValue: [NSString stringWithFormat: @"%u", v]];
	}
      else if (type == typeFloat)
	{
	  float	v;
	  float	(*imp)();

	  imp = (float (*)())[object methodForSelector: get];
	  v = (*imp)(object, get);
	  [value setStringValue: [NSString stringWithFormat: @"%f", v]];
	}
      else if (type == typeDouble)
	{
	  double	v;
	  double	(*imp)();

	  imp = (double (*)())[object methodForSelector: get];
	  v = (*imp)(object, get);
	  [value setStringValue: [NSString stringWithFormat: @"%g", v]];
	}
      else
	{
	  id	v;
	  IMP	imp = [object methodForSelector: get];

	  v = (*imp)(object, get);
	  if (v != nil && [v isKindOfClass: [NSString class]] == YES)
	    {
	      isString = YES;	/* Existing value is a string. */
	    }
	  [value setStringValue: [v description]];
	}
      [okButton setEnabled: YES];
    }
  else
    {
      [label setTitle: [NSString stringWithFormat: _(@"%@ - value unknown"),
	[types objectForKey: name]]];
      [value setStringValue: @""];
      [okButton setEnabled: YES];
    }
}

- (BOOL) wantsButtons
{
  return YES;
}
@end

