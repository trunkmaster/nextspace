" Vim syntax file
" Language:	Objective C NeXT
" Maintainer:	Valentino Kyriakides <1kyriaki@informatik.uni-hamburg.de>
" Last Change:	2001 May 09

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let b:is_objc = "yes"

" Read the C syntax to start with
if version < 600
  source <sfile>:p:h/c.vim
else
  runtime! syntax/c.vim
endif

" Objective C extentions follow below
"
" NOTE: Objective C is abbreviated to ObjC/objc
" and uses *.h, *.m as file extensions!


" ObjC keywords, types, type qualifiers etc.
syn keyword objcStatement	self super _cmd
syn keyword objcType		id Class SEL IMP BOOL nil Nil
"syn match   objcType            "\s*NS[a-zA-Z]*\s*"
syn keyword objcTypeModifier 	bycopy in out inout oneway

" Match the ObjC #import directive (like C's #include)
syn region objcImported contained start=+"+  skip=+\\\\\|\\"+  end=+"+
syn match  objcImported contained "<[^>]*>"
syn match  objcImport  		  "^#\s*import\>\s*["<]" contains=objcImported

" Match the important ObjC directives
syn match  objcScopeDecl 	"@public\|@private\|@protected"
syn match  objcDirective	"@interface\|@implementation"
syn match  objcDirective	"@class\|@end\|@defs"
syn match  objcDirective	"@encode\|@protocol\|@selector"

" Match the ObjC method types
"
" NOTE: here I match only the indicators, this looks
" much nicer and reduces cluttering color highlightings.
" However, if you prefer full method declaration matching
" append .* at the end of the next two patterns!
"
syn match objcInstMethod  "^[\t\s]*-[\s]*"
syn match objcFactMethod  "^[\t\s]*+[\s]*"
"syn match objcMethods  	  "[\ ][a-zA-Z]*:"

"syn region objcImplementationFold start="^@implementation" end="^@end" transparent fold
"syn region objcInterfaceFold start="^@interface" end="@end" transparent fold
syn region objcInstMethodFold start="^-.*\n\(^\s.*\n\)*{" end="^}" transparent fold
syn region cFunctionFold start="^.*[\s]*(.*)\n{" end="^}" transparent fold
syn region objcFactMethodFold start="^+.*\n{" end="^}" transparent fold

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_objc_syntax_inits")
  if version < 508
    let did_objc_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink objcImport		Include
  HiLink objcImported		cString
  HiLink objcTypeModifier	cString
  HiLink objcType		Type
  HiLink objcScopeDecl		Statement
  HiLink objcInstMethod		Function
  HiLink objcFactMethod		Function
  HiLink objcStatement		Statement
  HiLink objcDirective		Statement
  HiLink objcMethods		Statement

  hi objcImport    guifg=#8b008b
  hi objcImported  guifg=#008b00
  hi objcScopeDecl guifg=#8b0000
  hi objcDirective guifg=#8b0000
  hi objcMethods   guifg=NONE
  hi Constant      guifg=DarkRed
  
  delcommand HiLink
endif

let b:current_syntax = "next_objc"

" vim: ts=8
