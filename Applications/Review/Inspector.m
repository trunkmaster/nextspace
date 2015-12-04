/* 
 * Inspector.m created by probert on 2001-11-15 20:24:20 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: Inspector.m,v 1.4 2001/11/18 16:18:20 probert Exp $
 */

#import "Inspector.h"

@implementation Inspector

static Inspector *_inspector = nil;

+ (Inspector *)sharedInspector
{
    if( _inspector == nil ) {
        _inspector = [[Inspector alloc] init];
    }

    return _inspector;
}

- (id)init
{
    if ( self = [super init] ) {
        unsigned int style = NSTitledWindowMask | NSClosableWindowMask;
        NSRect rect = NSMakeRect(200,300,260,360);
	NSTextField *tf;

        inspector = [[NSWindow alloc] initWithContentRect:rect
                                                styleMask:style
                                                  backing:NSBackingStoreBuffered
                                                    defer:YES];
        [inspector setMinSize:NSMakeSize(260,360)];
        [inspector setTitle:@"Image Inspector"];
        [inspector setDelegate:self];
        [inspector setReleasedWhenClosed:NO];
        [inspector center];
        [inspector setFrameAutosaveName:@"Inspector"];

        rect = NSMakeRect(16,300,48,48);
        imgButton = [[NSButton alloc] initWithFrame:rect];
        [imgButton setButtonType: NSMomentaryLight];
        [imgButton setBordered:NO];
        [imgButton setImagePosition:NSImageOnly];  
	[[inspector contentView] addSubview:imgButton];
	RELEASE(imgButton);

        rect = NSMakeRect(72,312,172,25);
	nameField = [[NSTextField alloc] initWithFrame:rect];
        [nameField setFont: [NSFont systemFontOfSize: 18]];
        [nameField setAlignment: NSLeftTextAlignment];
        [nameField setBackgroundColor: [NSColor lightGrayColor]];
        [nameField setBezeled: NO];
        [nameField setEditable: NO];
        [nameField setSelectable: NO];
        [nameField setStringValue:@"No Image!"];
	[[inspector contentView] addSubview:nameField];
	RELEASE(nameField);

        rect = NSMakeRect(16,262,32,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Path:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(56,262,212,21);
	pathField = [[NSTextField alloc] initWithFrame:rect];
        [pathField setAlignment: NSLeftTextAlignment];
        [pathField setBackgroundColor:[NSColor lightGrayColor]];
        [pathField setBezeled: NO];
        [pathField setEditable: NO];
        [pathField setSelectable: NO];
        [pathField setStringValue:@"No path..."];
	[[inspector contentView] addSubview:pathField];
	RELEASE(pathField);

        rect = NSMakeRect(16,222,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"File Size:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,222,156,21);
	sizeField = [[NSTextField alloc] initWithFrame:rect];
        [sizeField setAlignment: NSLeftTextAlignment];
        [sizeField setBackgroundColor:[NSColor lightGrayColor]];
        [sizeField setBezeled: NO];
        [sizeField setEditable: NO];
        [sizeField setSelectable: NO];
        [sizeField setStringValue:@""];
	[[inspector contentView] addSubview:sizeField];
	RELEASE(sizeField);

        rect = NSMakeRect(16,202,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Permissions:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,202,156,21);
	permissionsField = [[NSTextField alloc] initWithFrame:rect];
        [permissionsField setAlignment: NSLeftTextAlignment];
        [permissionsField setBackgroundColor:[NSColor lightGrayColor]];
        [permissionsField setBezeled: NO];
        [permissionsField setEditable: NO];
        [permissionsField setSelectable: NO];
        [permissionsField setStringValue:@""];
	[[inspector contentView] addSubview:permissionsField];
	RELEASE(permissionsField);

        rect = NSMakeRect(16,182,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Modification Date:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,182,156,21);
	dateField = [[NSTextField alloc] initWithFrame:rect];
        [dateField setAlignment: NSLeftTextAlignment];
        [dateField setBackgroundColor:[NSColor lightGrayColor]];
        [dateField setBezeled: NO];
        [dateField setEditable: NO];
        [dateField setSelectable: NO];
        [dateField setStringValue:@""];
	[[inspector contentView] addSubview:dateField];
	RELEASE(dateField);

        rect = NSMakeRect(16,162,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"File Owner:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,162,156,21);
	ownerField = [[NSTextField alloc] initWithFrame:rect];
        [ownerField setAlignment: NSLeftTextAlignment];
        [ownerField setBackgroundColor:[NSColor lightGrayColor]];
        [ownerField setBezeled: NO];
        [ownerField setEditable: NO];
        [ownerField setSelectable: NO];
        [ownerField setStringValue:@""];
	[[inspector contentView] addSubview:ownerField];
	RELEASE(ownerField);

        rect = NSMakeRect(16,122,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Image Size:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,122,156,21);
	resField = [[NSTextField alloc] initWithFrame:rect];
        [resField setAlignment: NSLeftTextAlignment];
        [resField setBackgroundColor:[NSColor lightGrayColor]];
        [resField setBezeled: NO];
        [resField setEditable: NO];
        [resField setSelectable: NO];
        [resField setStringValue:@""];
	[[inspector contentView] addSubview:resField];
	RELEASE(resField);
	
        rect = NSMakeRect(16,102,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Bits per Sample:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,102,156,21);
	bitsField = [[NSTextField alloc] initWithFrame:rect];
        [bitsField setAlignment: NSLeftTextAlignment];
        [bitsField setBackgroundColor:[NSColor lightGrayColor]];
        [bitsField setBezeled: NO];
        [bitsField setEditable: NO];
        [bitsField setSelectable: NO];
        [bitsField setStringValue:@""];
	[[inspector contentView] addSubview:bitsField];
	RELEASE(bitsField);

        rect = NSMakeRect(16,82,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Has Alpha:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,82,156,21);
	alphaField = [[NSTextField alloc] initWithFrame:rect];
        [alphaField setAlignment: NSLeftTextAlignment];
        [alphaField setBackgroundColor:[NSColor lightGrayColor]];
        [alphaField setBezeled: NO];
        [alphaField setEditable: NO];
        [alphaField setSelectable: NO];
        [alphaField setStringValue:@""];
	[[inspector contentView] addSubview:alphaField];
	RELEASE(alphaField);

        rect = NSMakeRect(16,62,104,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Image Reps:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(128,62,156,21);
	repsField = [[NSTextField alloc] initWithFrame:rect];
        [repsField setAlignment: NSLeftTextAlignment];
        [repsField setBackgroundColor:[NSColor lightGrayColor]];
        [repsField setBezeled: NO];
        [repsField setEditable: NO];
        [repsField setSelectable: NO];
        [repsField setStringValue:@""];
	[[inspector contentView] addSubview:repsField];
	RELEASE(repsField);

        rect = NSMakeRect(16,22,64,21);
	tf = [[NSTextField alloc] initWithFrame:rect];
        [tf setAlignment: NSRightTextAlignment];
        [tf setBackgroundColor:[NSColor lightGrayColor]];
        [tf setBezeled: NO];
        [tf setEditable: NO];
        [tf setSelectable: NO];
        [tf setStringValue:@"Col Space:"];
	[[inspector contentView] addSubview:tf];
	RELEASE(tf);
        rect = NSMakeRect(88,22,180,21);
	colSpaceField = [[NSTextField alloc] initWithFrame:rect];
        [colSpaceField setAlignment: NSLeftTextAlignment];
        [colSpaceField setBackgroundColor:[NSColor lightGrayColor]];
        [colSpaceField setBezeled: NO];
        [colSpaceField setEditable: NO];
        [colSpaceField setSelectable: NO];
        [colSpaceField setStringValue:@""];
	[[inspector contentView] addSubview:colSpaceField];
	RELEASE(colSpaceField);
    }
    return self;
}

- (void)dealloc
{
    RELEASE(inspector);

    [super dealloc];
}

- (void)show
{
    if (![inspector isVisible]) { 
        [inspector setFrameUsingName:@"Inspector"];
    }

    [inspector makeKeyAndOrderFront:self];
}

- (void)imageWindowDidBecomeActive:(id<ImageShowing>)imgWin
{
    NSString *string = [imgWin path];      

    [imgButton setImage:[[NSWorkspace sharedWorkspace] iconForFile:string]];

    string = (string = [imgWin imageName]) ? string : @"";
    [nameField setStringValue:string];
    
    string = (string = [imgWin imagePath]) ? string : @"";
    [pathField setStringValue:string];

    string = (string = [imgWin imageSize]) ? string : @"";
    [sizeField setStringValue:string];

    string = (string = [imgWin imageFilePermissions]) ? string : @"";
    [permissionsField setStringValue:string];
    
    string = (string = [imgWin imageFileModificationDate]) ? string : @"";
    [dateField setStringValue:string];
    
    string = (string = [imgWin imageFileOwner]) ? string : @"";
    [ownerField setStringValue:string];
    
    string = (string = [imgWin imageResolution]) ? string : @"";
    [resField setStringValue:string];
    
    string = (string = [imgWin bitsPerSample]) ? string : @"";
    [bitsField setStringValue:string];

    string = (string = [imgWin colorSpaceName]) ? string : @"";
    [colSpaceField setStringValue:string];

    string = (string = [imgWin hasAlpha]) ? string : @"";
    [alphaField setStringValue:string];

    string = (string = [imgWin imageReps]) ? string : @"";
    [repsField setStringValue:string];
}

@end
