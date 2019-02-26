//
//
//

#include <stdio.h>

#import <Foundation/Foundation.h>
#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>
#import <NXSystem/NXPower.h>

char *get_monitor_name(unsigned char* edid)
{
  static char name[13];
  unsigned i, j;
  
  for (i = 0x36; i < 0x7E; i += 0x12) // read through descriptor blocks...
    {
      if (edid[i] == 0x00) // not a timing descriptor
        { 
          if (edid[i+3] == 0xfc) // Model Name tag
            {
              for (j = 0; j < 13; j++)
                {
                  if (edid[i+5+j] == 0x0a)
                    name[j] = 0x00;
                  else
                    name[j] = edid[i+5+j];
                }
            }
        }
    }

  return name;
}

char *get_vendor_name(unsigned char* edid)
{
  static char v_name[4];
  
  /* Vendor Name: 3 characters, standardized by microsoft, somewhere.
   * bytes 8 and 9: f e d c b a 9 8  7 6 5 4 3 2 1 0
   * Character 1 is e d c b a
   * Character 2 is 9 8 7 6 5
   * Character 3 is 4 3 2 1 0
   * Those values start at 0 (0x00 is 'A', 0x01 is 'B', 0x19 is 'Z', etc.)
   */
  v_name[0] = (edid[8] >> 2 & 0x1f) + 'A' - 1;
  v_name[1] = (((edid[8] & 0x3) << 3) | ((edid[9] & 0xe0) >> 5)) + 'A' - 1;
  v_name[2] = (edid[9] & 0x1f) + 'A' - 1;
  v_name[3] = '\0';
  
  return v_name;
}

void fadeInFadeOutTest(NXScreen *sScreen)
{
  NSArray   *displays = [sScreen connectedDisplays];
  for (NXDisplay *display in displays)
    {
      if ([display isActive])
        {
          CGFloat br = [display gammaBrightness];
          
          [display fadeToBlack:br];
          // [display fadeTo:0 interval:2.0 brightness:br];
          sleep(2);
          [display fadeToNormal:br];
          // [display fadeTo:1 interval:2.0 brightness:br];
        }
    }
}

void gammaCorrectionTest(NXScreen *sScreen)
{
  // NSArray   *displays = [sScreen connectedDisplays];
  // for (NXDisplay *display in displays)
    // {
      // CGFloat gamma = 1.25;
      // if ([display isActive])
      //   {
      //     fprintf(stderr, "Initial Gamma> Correction value = %0.2f, Brightness = %0.2f\n",
      //             1.0/[display gammaValue].red, [display gammaBrightness]);
          
      //     [display setGammaCorrectionValue:1.0];
      //     fprintf(stderr, ">>> Gamma Correction value = %0.2f, Gamma Brightness = %0.2f\n",
      //             1.0/[display gammaValue].red, [display gammaBrightness]);
  
      //     [display setGammaCorrectionValue:1.25];
          
      //     fprintf(stderr, ">>> Gamma Correction value = %0.2f, Gamma Brightness = %0.2f\n",
      //             1.0/[display gammaValue].red, [display gammaBrightness]);
      //   }
    // }

}

void screenInfo(NXScreen *screen)
{
  NSSize size;
  
  fprintf(stderr, "------\n");
  fprintf(stderr, " Screen Information\n");
  fprintf(stderr, "---------------------------------------------------------------------------------\n");
  size = [screen sizeInMilimeters];
  fprintf(stderr, "Physical size\t: %.0f mm x %.0f mm\n",
          size.width, size.height);
  size = [screen sizeInPixels];
  fprintf(stderr, "Size\t\t: %.0f x %.0f\n", size.width, size.height);
  fprintf(stderr, "Color depth\t: %lu\n", [screen colorDepth]);
}

void listDisplays(NSArray *displays, NSString *title)
{
  NSDictionary	*resolution;
  NSSize	size;
  NSPoint	position;
  
  fprintf(stderr, "------\n");
  fprintf(stderr, " %s\n", [title cString]);
  fprintf(stderr, "---------------------------------------------------------------------------------\n");
  fprintf(stderr, " Name \tConnected\t Lid   \tActive \t Main  \t DPI \tResolution\tPosition\n");
  fprintf(stderr, "------\t---------\t-------\t-------\t-------\t-----\t----------\t--------\n");
  for (NXDisplay *d in displays)
    {
      resolution = [d activeResolution];
      size = NSSizeFromString([resolution objectForKey:@"Size"]);
      position = d.frame.origin;
      fprintf(stderr, "%s\t  %s\t\t%s\t  %s\t%s\t%.0f\t%4.0fx%4.0f\t%.0f,%.0f\n",
              [[d outputName] cString],
              ([d isConnected]) ? "Yes" : "No",
              ([d isBuiltin] && [NXPower isLidClosed]) ? "Closed" : "Opened",
              ([d isActive]) ? "Yes" : "No",
              ([d isMain]) ? "Yes" : "No",
              [d dpi],
              size.width, size.height,
              position.x, position.y);
    }
}

void displayDetails(NXDisplay *display)
{
  NSSize  size;
  NSPoint point;
  
  fprintf(stderr, "---------------------------------------------------------------------------------\n");
  fprintf(stderr, "Output name\t\t: \e[7m%s\e[27m\n", [[display outputName] cString]);
  fprintf(stderr, "---------------------------------------------------------------------------------\n");
  fprintf(stderr, "Connected\t\t: %s\n", [display isConnected] ? "Yes" : "No");
  fprintf(stderr, "Active\t\t\t: %s\n", [display isActive] ? "Yes" : "No");
  fprintf(stderr, "Main\t\t\t: %s\n", [display isMain] ? "Yes" : "No");
  fprintf(stderr, "Builtin\t\t\t: %s\n", [display isBuiltin] ? "Yes" : "No");
  size = [display physicalSize];
  fprintf(stderr, "Physical size (mm)\t: %.0f x %.0f\n", size.width, size.height);
  fprintf(stderr, "Dot per inch\t\t: %.0f\n", [display dpi]);
  size = NSSizeFromString([[display activeResolution] objectForKey:@"Size"]);
  fprintf(stderr, "Resolution\t\t: %.0f x %.0f\n", size.width, size.height);
  size = NSSizeFromString([[display bestResolution] objectForKey:NXDisplaySizeKey]);
  fprintf(stderr, "Preferred resolution\t: %.0f x %.0f\n", size.width, size.height);
  point = [display frame].origin;
  fprintf(stderr, "Position on screen\t: %.0f, %.0f\n", point.x, point.y);
  fprintf(stderr, "Frame\t\t\t: %s\n", [NSStringFromRect([display frame]) cString]);
  fprintf(stderr, "Hidden frame\t\t: %s\n", [NSStringFromRect([display hiddenFrame]) cString]);
  fprintf(stderr, "Gamma supported\t\t: %s\n", [display isGammaSupported] ? "Yes" : "No");
  fprintf(stderr, "Gamma value\t\t: %.2f\n", [display gamma]);

  {
    // NSLog(@"\tProperties:");
    NSDictionary	*properties = [display properties];
    NSData		*edidData = [properties objectForKey:@"EDID"];
    unsigned char	*edid = (unsigned char *)[edidData bytes];

    if ([edidData length] > 0)
      {
        // NSLog(@"\t\tEDID: ");
        // for (NSUInteger i=0; i < [edidData length]; i++)
        //   {
        //     fprintf(stderr, "%x", edid[i]);
        //   }
        // fprintf(stderr, "\n");
        fprintf(stderr, "Monitor name\t\t: %s\n", get_monitor_name(edid));
        fprintf(stderr, "Vendor name\t\t: %s\n", get_vendor_name(edid));
            
        // Gamma. Divide by 100, add 1.
        // Defaults to 1, so if 0, it'll be 1 anyway.
        if (edid[0x17] != 0xff)
          {
            float monitorGamma;
            monitorGamma = (float)((((float)edid[0x17]) / 100) + 1);
            fprintf(stderr, "Monitor Gamma\t\t: %.2f\n", monitorGamma);
          }
      }
  }
}

int main(int argc, char *argv[])
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NXScreen		*screen = [NXScreen sharedScreen];
  NXDisplay		*display = nil;
  BOOL			setMode, showDetails;

  if (argc == 1)
    {
      screenInfo(screen);
      listDisplays([screen activeDisplays], @"Active displays");
    }
  
  for (int i=1; i < argc; i++)
    {
      if (argv[i][0] == '-')
        {
          if (strcmp(argv[i], "-listAll") == 0)
            {
              listDisplays([screen allDisplays], @"All registered displays");
            }
          else if (strcmp(argv[i], "-listActive") == 0)
            {
              listDisplays([screen activeDisplays], @"Active displays");
            }
          else if (strcmp(argv[i], "-details") == 0 && (i+1 < argc))
            {
              displayDetails([screen displayWithName:[NSString stringWithCString:argv[++i]]]);
            }
          else if (strcmp(argv[i], "-display") == 0)
            {
              display = [screen displayWithName:[NSString stringWithCString:argv[++i]]];
            }
          else
            {
              fprintf(stderr, "Unknown parameter specified: %s\n", argv[i]);
            }
        }
      else
        {
          fprintf(stderr, "No parameters specified.\n");
        }
    }

  // if (display)
  //   if (showDetails)
  //     displayDetails(display);
  //   else if (setMode)
  //     setMode()
      

  [screen release];
  [pool release];

  return 0;
}
