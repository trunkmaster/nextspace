
#import "XSPathView.h"

#import <AppKit/AppKit.h>

#import "XSIcon.h"

static NSImage * arrowImage = nil;
static Class pathViewIconClass = nil;

@implementation XSPathView

+ (void)setIconClass:(Class)aClass
{
  if (![[[aClass new] autorelease] isKindOfClass:[XSIcon class]])
    {
      [NSException raise:NSInvalidArgumentException
		  format:@"XSPathView: in `+setIconClass:' "
			 @"class %@ is not a subclass of XSIcon", aClass];
    }

  pathViewIconClass = aClass;
}

+ (Class)iconClass
{
  return pathViewIconClass;
}

+ (void)initialize
{
  arrowImage = [[NSImage alloc]
    initByReferencingFile: [[NSBundle bundleForClass:self]
	  pathForResource: @"XSRightArrow" ofType: @"tiff"]];

  pathViewIconClass = [XSIcon class];
}

- (void)dealloc
{
  TEST_RELEASE(path);
  TEST_RELEASE(names);
  TEST_RELEASE(multipleSelection);
  TEST_RELEASE(iconDragTypes);

  [super dealloc];
}

- initWithFrame:(NSRect)r
{
  [super initWithFrame:r];

  autoAdjustsToFitIcons = YES;

  selectable = YES;
  allowsMultipleSelection = NO;
  allowsArrowsSelection = NO;
  allowsAlphanumericSelection = NO;

  multipleSelection = [pathViewIconClass new];
  [multipleSelection setIconImage:[[[NSImage alloc]
	    initByReferencingFile:[[NSBundle bundleForClass:[self class]]
		  pathForResource:@"XSMultipleSelection" ofType:@"tiff"]]
		  autorelease]];
  [multipleSelection setEditable:NO];
  path = nil;
  names = nil;

  target = self;
  action = @selector(changePath:);

  iconClass = pathViewIconClass;

  return self;
}

- (void)drawRect:(NSRect)r
{
  unsigned int i, n;

  NSLog(@"XSPathView origin: %f.%f %fx%f", 
	r.origin.x, r.origin.y, r.size.width, r.size.height);

  for (i=1, n = [icons count]; i<n; i++)
    {
      NSPoint p;
      
      p = NSMakePoint((i * slotSize.width) - ([arrowImage size].width + 5),
		      slotSize.height/2);
      
      p.x = floorf(p.x);
      p.y = floorf(p.y);
      [arrowImage compositeToPoint:p
			 operation:NSCompositeSourceOver];
    }

  [super drawRect:r];
}

- (void)setPath:(NSString *)aPath
  trailingNames:(NSArray *)someNames
{
  unsigned length;

  if (delegate == nil)
    {
      NSLog(@"XSPathView: attempt to set path without a delegate "
	      @"assigned to define the icons to use.");

      return;
    }

  length = [aPath length];
  // remove a trailing "/" character
  if (length > 1 && [aPath characterAtIndex:length-1] == '/')
    {
      aPath = [aPath substringToIndex:length-1];
    }

  // Set icons for path of "folders"
  if (![path isEqualToString:aPath])
    {
      unsigned int i, n;
      NSArray      *pathComponents;
      NSString     *donePath = @"";

      ASSIGN(path, aPath);

      [self removeIcon:multipleSelection];

      pathComponents = [path pathComponents];

      for (i=0, n=[pathComponents count]; i<n; i++)
	{
	  NSString *component = [pathComponents objectAtIndex:i];
	  id       icon;

	  donePath = [donePath stringByAppendingPathComponent:component];

	  if (i < [icons count])
	    {
	      icon = [icons objectAtIndex:i];
	      [icon deselect:nil];
	    }
	  else
	    {
	      icon = [[iconClass new] autorelease];
	      [icon registerForDraggedTypes:iconDragTypes];
	      [icon setIconImage:[delegate pathView:self 
	                         imageForIconAtPath:donePath]];
	      [icon setLabelString:[delegate pathView:self 
		                   labelForIconAtPath:donePath]];
	      [self setSlotsWide:i+1];
	      [self putIcon:icon intoSlot:XSMakeIconSlot(i, 0)];
	    }

	  [icon 
	    setIconImage:[delegate pathView:self imageForIconAtPath:donePath]];
	  [icon 
	    setLabelString:[delegate pathView:self labelForIconAtPath:donePath]];
	}
    }

  // Set icon for "file"
  if (![names isEqual:someNames])
    {
      if (!([names count] > 0))
	{
	  [[icons lastObject] deselect:nil];
	}

      [self removeIcon:multipleSelection];

      ASSIGN(names, someNames);

      if ([names count] > 0)
	{
	  unsigned int i = [[path pathComponents] count];

	  if ([names count] == 1)
	    {
	      id       icon;
	      NSString *_path;

	      _path = [path 
		stringByAppendingPathComponent:[names objectAtIndex:0]];
	      if ([icons count] > i)
		{
	  	  icon = [icons objectAtIndex:i];
		}
	      else
		{
		  icon = [[iconClass new] autorelease];
		  [icon registerForDraggedTypes:iconDragTypes];
		  [self setSlotsWide:i+1];
		  [self putIcon:icon intoSlot:XSMakeIconSlot(i, 0)];
		}

	      [icon setIconImage:[delegate pathView: self
	                         imageForIconAtPath:_path]];
	      [icon setLabelString:
		[delegate pathView:self labelForIconAtPath:_path]];
	    }
	  else
	    {
	      if ([icons indexOfObjectIdenticalTo:multipleSelection] 
		  == NSNotFound) 
		{
		  [self setSlotsWide:i+1];
		  [self putIcon:multipleSelection
		       intoSlot:XSMakeIconSlot(i, 0)];
		}
	      [multipleSelection 
		setLabelString:[NSString 
	          stringWithFormat:_(@"%d Elements"),[names count]]];
	    }
	}
    }

  // remove trailing icons
    {
      unsigned int i, n;

      i = [[path pathComponents] count];
      if ([names count] > 0)
	{
  	  i++;
	}

      for (n=[icons count]; i<n; i++)
	{
	  [self removeIconInSlot:XSMakeIconSlot(i, 0)];
	}
    }

  [self setSlotsWide:[icons count]];
  [[icons lastObject] select:nil];
}

- (NSString *) path
{
  return path;
}

- (NSArray *) trailingNames
{
  return names;
}

- (void) iconClicked: sender
{
  unsigned i, idx;
  NSString * newPath = @"";
  NSArray * pathComponents;

  [super iconClicked: sender];

  if (![delegate respondsToSelector:@selector(pathView:didChangePathTo:)])
    {
      return;
    }

  // do not select the last icon
  if ([icons lastObject] == sender)
    {
      return;
    }

  idx = [icons indexOfObjectIdenticalTo:sender];
  if (idx == NSNotFound)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: _(@"XSPathView: tried to find an icon "
			    @"which isn't in the container")];
    }

  pathComponents = [path pathComponents];
  for (i=0; i<=idx; i++)
    {
      newPath = [newPath 
	stringByAppendingPathComponent:[pathComponents objectAtIndex:i]];
    }

  [self setPath:newPath trailingNames:nil];
  [delegate pathView:self didChangePathTo:newPath];
}

- (void) iconDoubleClicked: sender
{
  // only allow the last icon to be double-clicked
  if ([icons lastObject] == sender)
    [super iconDoubleClicked: sender];
}

- (NSArray *) pathsForIcon: (XSIcon *) icon
{
  unsigned int idx = [icons indexOfObjectIdenticalTo: icon];

  if (idx == NSNotFound)
    return nil;

  if ([names count] > 0 && icon == [icons lastObject]) {
      NSMutableArray * array = [NSMutableArray array];
      NSEnumerator * e = [names objectEnumerator];
      NSString * filename;

      while ((filename = [e nextObject]) != nil)
	{
	  [array addObject:[path stringByAppendingPathComponent:filename]];
	}

      return [[array copy] autorelease];
  } else {
      NSString * newPath = @"";
      NSEnumerator * pathEnum = [[path pathComponents]
	objectEnumerator],
	* iconEnum = [icons objectEnumerator];

      do newPath = [newPath stringByAppendingPathComponent: [pathEnum nextObject]];
      while ([iconEnum nextObject] != icon);

      return [NSArray arrayWithObject: newPath];
  }
}

- (void)setIconClass:(Class)aClass
{
  NSString *_path;
  NSArray  *_names;

  if (![[[aClass new] autorelease] isKindOfClass:[XSIcon class]])
    {
      [NSException raise:NSInvalidArgumentException
		  format:@"XSPathView: in `-+setIconClass:' "
			 @"class %@ is not a subclass of XSIcon", 
			 [aClass className]];
    }

  iconClass = aClass;

  if (path)
    {
      _path = [path retain];
      _names = [names retain];
      DESTROY(path);
      DESTROY(names);
      [self removeAllIcons];
      [self setPath:_path trailingNames:_names];
      DESTROY(_path);
      DESTROY(_names);
    }
}

- (Class)iconClass
{
  return iconClass;
}

- (void) setIconDragTypes: (NSArray *) types
{
  ASSIGN(iconDragTypes, types);

  [icons makeObjectsPerform: @selector(unregisterDraggedTypes)];
  [icons makeObjectsPerform: @selector(registerForDraggedTypes:)
		 withObject: iconDragTypes];

  // this is no dragging destination
  [multipleSelection unregisterDraggedTypes];
}

- (NSArray *) iconDragTypes
{
  return iconDragTypes;
}

- (void)mouseDown:(NSEvent *)ev
{
  // Do nothing. It prevents icons deselection.
}

- (BOOL)acceptsFirstResponder
{
  // Do nothing. It prevents first responder stealing.
  return NO;
}

@end
