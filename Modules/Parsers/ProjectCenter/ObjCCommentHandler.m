/*
**  ObjCCommentHandler.m
**
**  Copyright (c) 2003-2016
**
**  Author: Yen-Ju  <yjchenx@hotmail.com>
**          Riccardo Mottola
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import <Foundation/Foundation.h>

#import "ObjCCommentHandler.h"

@implementation ObjCCommentHandler

- (void)string:(NSString *)element
{
}

- (void)number:(NSString *)element 
{
}

- (void)spaceAndNewLine:(unichar)element 
{
  if (_commentType == SingleLineComment)
    {
      if ((element == 0x0A) || (element == 0x0D) || (element == 0x04))
        {
          _commentType = NoComment;
        }
    }
}

- (void)symbol:(unichar)element 
{
  if (!_stringBegin)
    {
      if (_preChar == '/')
	{
	  if (element == '*')
	    _commentType = MultipleLineComment;
	  else if (element == '/')
	    _commentType = SingleLineComment;
	  
	}
      else if ((element == '/') && (_preChar == '*'))
	{
	  _commentType = NoComment;
	}
    }

  if (_commentType == NoComment)
    {
      if ((element == '\"') && (_preChar != '\\'))
        {
          if ((_stringBegin) && (_stringSymbol == '\"')) 
            {
              _stringBegin = NO;
              _stringSymbol = 0;
            }
          else if (!_stringBegin)
            {
              _stringBegin = YES;
              _stringSymbol = element;
            }
        }
      else if ((element == '\'') && (_preChar != '\\'))
        {
          if ((_stringBegin) && (_stringSymbol == '\''))  
            {
              _stringBegin = NO;
              _stringSymbol = 0;
            }
          else if (!_stringBegin)  
            {
              _stringBegin = YES;
              _stringSymbol = element;
            }
        }
    }
}

- (void)invisible:(unichar)element
{
}

- (id)init
{
  self = [super init];
  _commentType = NoComment;
  _stringBegin = NO;
  _stringSymbol = 0;
  return self;
}

@end

