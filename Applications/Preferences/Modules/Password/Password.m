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

#include <unistd.h>
#include <string.h>
#include <security/pam_appl.h>

#import <Foundation/Foundation.h>

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

static Password         *sharedPassword = nil;
static pam_handle_t     *PAM_handle = NULL;
static char             *PAMInput = NULL;
static BOOL             PAMInputReady = NO;
static dispatch_queue_t pam_q;

int PAMConversation(int num_msg, 
                    const struct pam_message **msg,
                    struct pam_response **resp,
                    void * appdata_ptr)
{
  int count;
  int result = PAM_SUCCESS;
  struct pam_response *reply;
  
  if (num_msg != 1) {
    NSLog(@"PAM: 0 messages was sent to conversation function.");
    return PAM_CONV_ERR;
  }

  reply = (struct pam_response *)calloc(num_msg,
                                        sizeof(struct pam_response));
  if (reply == NULL) {
    NSLog(@"PAM: no memory for responses");
    return PAM_CONV_ERR;
  }

  for (count = 0; count < num_msg; ++count) {
    // NSLog(@"PAM message type %i: %s", msg[count]->msg_style, msg[count]->msg);
    
    switch (msg[count]->msg_style) {
    case PAM_PROMPT_ECHO_OFF:
      // Enter current password
      NSLog(@"PAM ECHO_OFF: %s", msg[count]->msg);
      [sharedPassword
        performSelectorOnMainThread:@selector(setMessage:)
                         withObject:[NSString stringWithCString:msg[count]->msg]
                      waitUntilDone:YES];
      NSLog(@"Waiting...");
      while (PAMInputReady == NO) {
        usleep(500000);
      }
      NSLog(@"Password was entered.\n");
      if (PAMInput == NULL) {
        pam_end(PAM_handle, PAM_ABORT);
        result = PAM_ABORT;
      }
      break;
    case PAM_PROMPT_ECHO_ON:
      NSLog(@"PAM ECHO_ON: %s",msg[count]->msg);
      [sharedPassword
        performSelectorOnMainThread:@selector(setMessage:)
                         withObject:[NSString stringWithCString:msg[count]->msg]
                      waitUntilDone:YES];
      NSLog(@"Waiting...");
      while (PAMInputReady == NO) {
        usleep(500000);
      }
      if (PAMInput == NULL) {
        result = PAM_ABORT;
      }
      break;
    case PAM_ERROR_MSG:
      NSLog(@"PAM error message: %s",msg[count]->msg);
      [sharedPassword
        performSelectorOnMainThread:@selector(setInfo:)
                         withObject:[NSString stringWithCString:msg[count]->msg]
                      waitUntilDone:YES];
      result = PAM_ABORT;
      break;
    case PAM_TEXT_INFO:
      NSLog(@"PAM information: %s",msg[count]->msg);
      [sharedPassword
        performSelectorOnMainThread:@selector(setInfo:)
                         withObject:[NSString stringWithCString:msg[count]->msg]
                      waitUntilDone:YES];
      break;
    case PAM_BINARY_PROMPT:
      // ???
      NSLog(@"PAM binary: %s",msg[count]->msg);
      break;
    default:
      NSLog(@"PAM: erroneous conversation (%d)", msg[count]->msg_style);
      result = PAM_CONV_ERR;
    }
    
    if (PAMInput) {
      /* must add to reply array */
      /* add string to list of responses */
      reply[count].resp_retcode = 0;
      reply[count].resp = PAMInput;
      PAMInput = NULL;
    }

    PAMInputReady = NO;
    *resp = reply;
    reply = NULL;
  }

  return result;
}

@implementation Password

- (void)dealloc
{
  NSLog(@"Password -dealloc");
  sharedPassword = nil;
  [image release];
  [lockImage release];
  [lockOpenImage release];
  [passwordField release];
  [super dealloc];
}

- (id)init
{
  NSBundle *bundle;
  
  self = [super init];
  
  bundle = [NSBundle bundleForClass:[self class]];
  image = [[NSImage alloc]
            initWithContentsOfFile:[bundle pathForResource:@"Password"
                                                    ofType:@"tiff"]];
  lockImage = [[NSImage alloc]
                initWithContentsOfFile:[bundle pathForResource:@"Lock"
                                                        ofType:@"tiff"]];
  lockOpenImage = [[NSImage alloc]
                     initWithContentsOfFile:[bundle pathForResource:@"LockOpen"
                                                             ofType:@"tiff"]];
  sharedPassword = self;
  return self;
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [messageField setStringValue:@""];
  [infoField setStringValue:@""];

  [passwordField retain];
  [passwordField setStringValue:@"Password Secure"];
  [passwordField setEnabled:NO];
  [passwordField sendActionOn:NSLeftMouseDownMask];

  secureField = [[NSSecureTextField alloc]
                  initWithFrame:[passwordField frame]];
  [secureField setEchosBullets:NO];
  [secureField setDelegate:self];
  
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

- (NSString *)password
{
  NSLog(@"Password requested: %@", [secureField stringValue]);
  return [secureField stringValue];
}

- (void)setMessage:(NSString *)text
{
  // NSLog(@"setMessage: `%@`", text);
  if ([text isEqualToString:@"(current) UNIX password: "] != NO) {
    state = PAMEnterOld;
    [messageField setStringValue:@"Please type your current password."];
  }
  else if ([text isEqualToString:@"New password: "] != NO) {
    state = PAMEnterNew;
    [lockView setImage:lockOpenImage];
    [messageField setStringValue:@"Please type your new password."];
  }
  else if ([text isEqualToString:@"Retype new password: "] != NO) {
    state = PAMConfirmNew;
    [messageField setStringValue:@"Please type your new password again."];
  }
  else {
    [messageField setStringValue:text];
  }

  if ([secureField superview] == nil) {
    [passwordBox replaceSubview:passwordField with:secureField];
    [secureField setDelegate:self];
  }
  
  [okButton setEnabled:YES];
  [cancelButton setEnabled:YES];
  [secureField setEnabled:YES];
  [[view window] makeFirstResponder:secureField];
}
- (void)setInfo:(NSString *)text
{
  [infoField setStringValue:text];
}

//
// Action methods
//
- (BOOL)changePasswordWithPAM
{
  struct pam_conv conv;
  int             ret;
  NSString        *infoMessage;

  conv.conv = PAMConversation;
  ret = pam_start("passwd", [NSUserName() cString], &conv, &PAM_handle);
  if (ret == PAM_SUCCESS) {
    ret = pam_chauthtok(PAM_handle, ret);
    pam_end(PAM_handle, ret);
    if (ret != PAM_SUCCESS) {
      NSLog(@"PAM failed: %s\n", pam_strerror(PAM_handle, ret));
    }
  }
  else {
    NSLog(@"Failed to initialize PAM");
  }
  
  if (ret != PAM_SUCCESS) {
    infoMessage = @"Password change failed.";
  }
  else {
    infoMessage = @"Password was successfully changed.";
  }
  
  [self performSelectorOnMainThread:@selector(setInfo:)
                         withObject:infoMessage
                           waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(cancel:)
                         withObject:self
                      waitUntilDone:YES];

  return (ret == PAM_SUCCESS) ? YES : NO;
}

- (IBAction)changePassword:(id)sender
{
  if (state == PAMStart) {
    if (fieldTimer != nil && [fieldTimer isValid] != NO) {
      [fieldTimer fire];
    }
    [secureField setDelegate:self];
    [passwordBox replaceSubview:passwordField with:secureField];
    [[view window] makeFirstResponder:secureField];
    
    [infoField setStringValue:@""];
    [okButton setTitle:@"Ok"];
    [cancelButton setEnabled:YES];
 
    pam_q = dispatch_queue_create("ns.preferences.pam", NULL);  
    dispatch_async(pam_q, ^{[self changePasswordWithPAM];});
  }
  else {
    PAMInput = strdup([[secureField stringValue] cString]);
    PAMInputReady = YES;
    
    [passwordField setStringValue:@"Checking..."];
    if ([passwordField superview] == nil) {
      [secureField setDelegate:nil];
      [passwordBox replaceSubview:secureField with:passwordField];
    }
    [secureField setEnabled:NO];
    [secureField setStringValue:@""];
    [messageField setStringValue:@""];
    [infoField setStringValue:@""];
    
    [okButton setEnabled:NO];
    [cancelButton setEnabled:NO];
    
  }
}

- (IBAction)cancel:(id)sender
{
  NSLog(@"Cancel");

  PAMInput = NULL;
  PAMInputReady = YES;
  [lockView setImage:lockImage];
  // Password field
  if ([secureField superview] != nil) {
    [secureField setDelegate:nil];
    [passwordBox replaceSubview:secureField with:passwordField];
  }
  [passwordField setStringValue:@"Password Secure"];
  //
  [messageField setStringValue:@""];
  if (sender == cancelButton) {
    [infoField setStringValue:@""];
  }
  else if (fieldTimer == nil || [fieldTimer isValid] == NO) {
    fieldTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                  target:self
                                                selector:@selector(emptyFields:)
                                                userInfo:nil
                                                 repeats:NO];
  }
  [okButton setTitle:@"Change"];
  [cancelButton setEnabled:NO];
  [okButton setEnabled:YES];
  state = PAMStart;
}

- (void)emptyFields:(NSTimer *)timer
{
  [infoField setStringValue:@""];
  [fieldTimer invalidate];
  fieldTimer = nil;
}

- (BOOL)      control:(NSControl *)control
 textShouldEndEditing:(NSText *)fieldEditor
{
  NSLog(@"control:textShouldEndEditing");
  [okButton performClick:okButton];
  return YES;
}

@end
