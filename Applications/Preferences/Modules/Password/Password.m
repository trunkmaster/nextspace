/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#define _XOPEN_SOURCE
#pragma push_macro("__block")
#undef __block
#define __block my__block
#include <unistd.h>
#pragma pop_macro("__block")

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSSecureTextField.h>
#import <AppKit/NSEvent.h>

#import "Password.h"

static NSBundle *bundle = nil;
/*
 * Size of the biggest passwd:
 *   $6$	3
 *   rounds=	7
 *   999999999	9
 *   $		1
 *   salt	16
 *   $		1
 *   SHA512	123
 *   nul	1
 *
 *   total	161
 */
static char crypt_passwd[256];
static struct passwd *pw;

@implementation Password

- (void)dealloc
{
  NSLog(@"Password -dealloc");
  [image release];
  [lockImage release];
  [lockOpenImage release];
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  bundle = [NSBundle bundleForClass:[self class]];
  image = [[NSImage alloc]
            initWithContentsOfFile:[bundle pathForResource:@"Password"
                                                    ofType:@"tiff"]];
  lockImage = [[NSImage alloc]
                initWithContentsOfFile:[bundle pathForResource:@"Password"
                                                        ofType:@"tiff"]];
  lockOpenImage = [[NSImage alloc]
                     initWithContentsOfFile:[bundle pathForResource:@"Password"
                                                             ofType:@"tiff"]];
  return self;
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [messageField setStringValue:@""];
  [passwordField setStringValue:@"Password Secure"];
  [passwordField setEnabled:YES];
  [passwordField sendActionOn:NSLeftMouseDownMask];

  secureField = [[NSSecureTextField alloc]
                  initWithFrame:[passwordField frame]];
  [secureField setEchosBullets:NO];
  [secureField setDelegate:self];
  [infoField retain];
  [infoField removeFromSuperview];

  [okButton setRefusesFirstResponder:YES];
  [cancelButton setRefusesFirstResponder:YES];
  [lockView setRefusesFirstResponder:YES];
}

- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Password" owner:self]) {
      NSLog (@"Password.preferences: Could not load NIB, aborting.");
      return nil;
    }
  }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Password Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
char *pw_encrypt(const char *clear, const char *salt)
{
  static char cipher[128];
  char *cp;

  cp = crypt(clear, salt);
  if (NULL == cp) {
    return NULL;
  }

  /* Some crypt() do not return NULL if the algorithm is not
   * supported, and return a DES encrypted password. */
  if ((NULL != salt) && (salt[0] == '$') && (strlen(cp) <= 13)) {
    const char *method;
    switch (salt[1])
      {
      case '1':
        method = "MD5";
        break;
      case '5':
        method = "SHA256";
        break;
      case '6':
        method = "SHA512";
        break;
      default:
        {
          static char nummethod[4] = "$x$";
          nummethod[1] = salt[1];
          method = &nummethod[0];
        }
      }
    NSLog(@"crypt method not supported by libcrypt? (%s)", method);
    return NULL;
  }

  if (strlen(cp) != 13) {
    return cp;	/* nonstandard crypt() in libc, better bail out */
  }

  strcpy(cipher, cp);

  return cipher;
}

- (BOOL)authenticate:(NSString *)clearText
{
  char *cipher;
  const char *clear;
  
  if (clearText == nil || [clearText length] == 0) {
    return NO;
  }
  clear = [clearText cString];
  cipher = pw_encrypt(clear, crypt_passwd);

  if (NULL == cipher) {
    memset((void *)clear, 0, strlen(clear));
    NSLog(@"Failed to crypt password with previous salt: %s", strerror(errno));
    return NO;
  }

  if (strcmp(cipher, crypt_passwd) != 0) {
    memset((void *)clear, 0, strlen(clear));
    memset((void *)cipher, 0, strlen(cipher));
    // NSLog(@"Incorrect password for %s.", pw->pw_name);
    return NO;
  }
  // STRFCPY (orig, clear);
  memset((void *)clear, 0, strlen(clear));
  memset((void *)cipher, 0, strlen(cipher));
  return NO;
}

- (IBAction)changePassword:(id)sender
{
  switch (state) {
  case EnterOld:
    [passwordField retain];
    [passwordBox replaceSubview:passwordField with:secureField];
    [[view window] makeFirstResponder:secureField];
    // Please type your old password.
    [messageField setStringValue:@"Please type your old password."];
    [okButton setTitle:@"Ok"];
    [cancelButton setEnabled:YES];
    state++;
    break;
  case EnterNew:
    // Please type your new password.
    if ([self authenticate:[passwordField stringValue]] == NO) {
      [self cancel:okButton];
      [messageField setStringValue:@"Entered password is incorrect."];
    }
    [messageField setStringValue:@"Please type your new password."];
    [secureField setStringValue:@""];
    [passwordBox addSubview:infoField];
    state++;
    break;
  case ConfirmNew:
    // Please type your new password again.
    [secureField setStringValue:@""];
    [messageField setStringValue:@"Please type your new password again."];
    [infoField removeFromSuperview];
    state++;
    break;
  default:
    [self cancel:okButton];
  }
}

- (IBAction)cancel:(id)sender
{
  // Password field
  [passwordBox replaceSubview:secureField with:passwordField];
  [passwordField release];
  [infoField removeFromSuperview];
  //
  [messageField setStringValue:@""];
  [okButton setTitle:@"Change"];
  [cancelButton setEnabled:NO];
  state = EnterOld;
}

@end

@implementation Password (PAM)



@end
