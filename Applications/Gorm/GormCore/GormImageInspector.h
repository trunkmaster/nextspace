/* All Rights reserved */

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@interface GormImageInspector : IBInspector
{
  id name;
  id imageView;
  id width;
  id height;
  id _currentImage;
}
@end
