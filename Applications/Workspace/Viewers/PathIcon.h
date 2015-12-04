//   PathIcon.m
//   An NXIcon subclass that implements file operations.
//
//   PathIcon holds information about object(file, dir) path. Set with setPath:
//   method and saved in 'paths' ivar. Any other optional information (e.g. 
//   device for mount point, application, special file attributes) set with 
//   setInfo: method and saved in 'info' ivar.

#import <NXAppKit/NXAppKit.h>

#import <NXAppKit/NXIcon.h>

@class FileSystemInterface;
@protocol NSDraggingInfo;

@interface PathIcon : NXIcon
{
  NSArray             *paths;
  NSDictionary        *info;

  unsigned int  draggingMask;
  BOOL          doubleClickPassesClick;
}

// Metainformation getters and setters
- (void)setPaths:(NSArray *)newPaths;
- (NSArray *)paths;
- (void)setInfo:(NSDictionary *)anInfo;
- (NSDictionary *)info;

// Define behaviour of double click.
- (void)setDoubleClickPassesClick:(BOOL)isPass;
- (BOOL)isDoubleClickPassesClick;

// NSDraggingDestination
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end
