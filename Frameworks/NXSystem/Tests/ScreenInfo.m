#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>
#include <unistd.h>

NSString *get_monitor_name(unsigned char* edid)
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

  return [NSString stringWithCString:name];
}

NSString *get_vendor_name(unsigned char* edid)
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
  
  return [NSString stringWithCString:v_name];
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

int main(int argc, const char ** argv)
{
  NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
  NXScreen		*sScreen = [NXScreen sharedScreen];
  BOOL			isActive = NO;
  NSSize		dSize;
  
  NSLog(@"Screen:");
  NSLog(@"\tPhysical size: %.0fmm x %.0fmm",
        [sScreen sizeInMilimeters].width,[sScreen sizeInMilimeters].height);
  NSLog(@"\tSize: %.0f x %.0f",
        [sScreen sizeInPixels].width,[sScreen sizeInPixels].height);
  NSLog(@"\tColor depth: %lu", [sScreen colorDepth]);

  for (NXDisplay *display in [sScreen allDisplays])
    {
      if (![display isConnected])
        {
          NSLog(@"Display at output '%@' is not Connected",
                [display outputName]);
          continue;
        }

      isActive = [display isActive];
      if (!isActive)
        {
          NSLog(@"Display at output '%@' (Inactive)",
                [display outputName]);
        }
      else
        {
          NSLog(@"Display at output: %@", [display outputName]);
          if ([display isMain])
            NSLog(@"\tMain Display: YES");
        }
      
      // NSLog(@"\tCRTC: %lu", [display crtcID]);
      
      NSSize size = [display physicalSize];
      NSLog(@"\tSize: %.0fmm x %.0fmm", size.width, size.height);
      
      // NSLog(@"\tResolutions:");
      // for (NSDictionary *res in [display allModes])
      //   {
      //     NSLog(@"\t\t%@", [res objectForKey:@"Name"]);
      //   }
      
      // if (isActive)
        {
          NSDictionary *mode = [display resolution];
          if (mode)
            {
              dSize = NSSizeFromString([mode objectForKey:NXDisplaySizeKey]);
              NSLog(@"\tCurrent resolution: %.0f x %.0f @ %.2f",
                    dSize.width, dSize.height,
                    [[mode objectForKey:NXDisplayRateKey] floatValue]);
            }
          // else
          //   {
          //     NSLog(@"\tCurrent resolution (%.0fx%.0f@%.2f) is not in list of supported by monitor", [display modeSize].width, [display modeSize].height, [display modeRate]);
          //   }
          mode = [display bestResolution];
          dSize = NSSizeFromString([mode objectForKey:NXDisplaySizeKey]);
          NSLog(@"\tPreferred resolution: %.0f x %.0f @ %.2f",
                dSize.width, dSize.height,
                [[mode objectForKey:NXDisplayRateKey] floatValue]);
      
          NSRect frame = [display frame];
          NSLog(@"\tPosition: %.1f, %.1f", frame.origin.x, frame.origin.y);
          NSLog(@"\tSize in pixels: %.1f x %.1f",
                frame.size.width, frame.size.height);
          NSLog(@"\tDots per Inch: %.1f", [display dpi]);
          NSLog(@"\tGamma supported: %@",
                (([display isGammaSupported]) ? @"Yes" : @"No"));

          // Propeties
          {
            NSLog(@"\tProperties:");
            NSDictionary *properties = [display properties];
            NSData *edidData = [properties objectForKey:@"EDID"];
            unsigned char *edid = (unsigned char *)[edidData bytes];

            if ([edidData length] > 0)
              {
                NSLog(@"\t\tEDID: ");
                for (NSUInteger i=0; i < [edidData length]; i++)
                  {
                    fprintf(stderr, "%x", edid[i]);
                  }
                fprintf(stderr, "\n");
                NSLog(@"\t\tMonitor name: %@", get_monitor_name(edid));
                NSLog(@"\t\tVendor name: %@", get_vendor_name(edid));
            
                // Gamma. Divide by 100, add 1.
                // Defaults to 1, so if 0, it'll be 1 anyway.
                if (edid[0x17] != 0xff)
                  {
                    float monitorGamma;
                    monitorGamma = (float)((((float)edid[0x17]) / 100) + 1);
                    NSLog(@"\t\tMonitor Gamma: %.2f\n", monitorGamma);
                  }
              }
          }
        }
    }

  // fprintf(stderr, ">>> Setting default arranged layout of displays...\n");
  // [sScreen applyDisplayLayout:[sScreen defaultLayout:YES]];
  
  // NSArray *layout;
  // layout = [NSArray arrayWithContentsOfFile:
  //                     @"/usr/NextSpace/Preferences/Displays.config"];
  // [sScreen applyDisplayLayout:layout];

  fadeInFadeOutTest(sScreen);

  // [sScreen backgroundColor];

 
  [pool release];

  return 0;
}

