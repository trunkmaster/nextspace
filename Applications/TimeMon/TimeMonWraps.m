// translated from the pswraps for GNUstep/MOSX by Gregory John Casamento

#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSGeometry.h>
#import <AppKit/NSBezierPath.h>
#import "NSColorExtensions.h"

#import "TimeMonWraps.h"

void drawArc2(double radius, double bdeg, double ddeg, double ldeg,
	      double mdeg)
{
  NSBezierPath   *bp = nil;
  NSPoint        point = NSMakePoint(24,24);
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSColor *idleColor = [NSColor colorFromStringRepresentation: 
                                       [defaults stringForKey:@"IdleColor"]];
  NSColor *niceColor = [NSColor colorFromStringRepresentation: 
                                       [defaults stringForKey:@"NiceColor"]];
  NSColor *userColor = [NSColor colorFromStringRepresentation: 
                                       [defaults stringForKey:@"UserColor"]];
  NSColor *systemColor = [NSColor colorFromStringRepresentation: 
                                         [defaults stringForKey:@"SystemColor"]];
  NSColor *ioWaitColor = [NSColor colorFromStringRepresentation:
                                         [defaults stringForKey:@"IOWaitColor"]];

  [idleColor set];
  bp = [NSBezierPath bezierPath];
  [bp moveToPoint: point];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:radius
                             startAngle:0
                               endAngle:360
                              clockwise:NO];
  [bp fill];

  [systemColor set]; 
  bp = [NSBezierPath bezierPath];
  [bp moveToPoint:point];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:radius
                             startAngle:90
                               endAngle:bdeg
                              clockwise:YES];
  [bp fill];

  [userColor set];
  bp = [NSBezierPath bezierPath];
  [bp moveToPoint: point];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:radius
                             startAngle:bdeg
                               endAngle:
                         ddeg clockwise:YES];
  [bp fill];

  [niceColor set];
  bp = [NSBezierPath bezierPath];
  [bp moveToPoint: point];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:radius
                             startAngle:ddeg
                               endAngle:ldeg
                              clockwise:YES];
  [bp fill];

  [ioWaitColor set];
  bp = [NSBezierPath bezierPath];
  [bp moveToPoint:point];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:radius
                             startAngle:ldeg
                               endAngle:mdeg
                              clockwise:YES];
  [bp fill];
}
