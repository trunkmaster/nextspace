;;; rtf-mode.el --- Emacs major mode for viewing/editing RTF source

;; Copyright (C) 2006 Sean M. Burke (but released under GPL)

;; Time-stamp: <2006-10-23 21:23:45 AKDT>
;; Author:     Sean M. Burke <sburke@cpan.org>
;; Maintainer: Sean M. Burke <sburke@cpan.org>
;; Keywords: wp, rtf, languages
;; Version: 1.1
;; X-URL: http://interglacial.com/rtf/emacs/

;;; Commentary:

;; Major mode for viewing/editing RTF source.  I wrote this mostly for
;; the sake of syntax-highlighting, and for the {}-matching.  It offers
;; little else in the way of conveniences (like key shortcuts.)
;; (If are interested in such conveniences, email me.)
;;
;; I maintain a homepage for this mode, at http://interglacial.com/rtf/emacs/
;;
;; Note that this mode doesn't (yet?) specially handle Help-RTF constructs.
;;
;; Also note that at time of writing (Oct 2006), Xemacs doesn't seem to
;; support some of the functions that this mode requires.  Sorry, Xemacs users!
;;
;; As with many programming modes, the default wrapping mechinisms
;; (whether via auto-fill-mode, or via fill-paragraph etc commands) do
;; not behave at all well.  So I've disabled wrapping as best I can,
;; so you don't end up corrupting documents.  Moreover, implementing
;; wrapping in RTF seems fairly difficult because of how spaces are
;; sometimes a significant token in RTF whereas newlines are not.
;;
;; For more on RTF, see http://interglacial.com/rtf/ and also be a chum and
;; go get this little book I wrote:  http://www.amazon.com/dp/0596004753
;;

;;; Boilerplate

;; This file is not part of GNU Emacs.
;;
;; This is free software; you can redistribute it and/or modify it under the
;; terms of the GNU General Public License as published by the Free Software
;; Foundation, version 2.
;;
;; This is distributed in the hope that it will be useful, but without any
;; warranty without even the implied warranty of merchantability or fitness for
;; a particular purpose.  See the GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License along with
;; GNU Emacs; see the file COPYING.  If not, write to the Free Software
;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

;;; Change log:

;; 2006-10-23 version 1.1
;;  Public release.  Just a minor internal optimization.
;;  (We new use regexp-opt to build our regexp from rtf-loudcmds.)

;; 2006-10-22 version 1.0
;;  Public release.

;;; Code:

(require 'generic)

(defmacro rtf-mkface (name basis desc)
  `(defface
     ,name
     (list (list t :inherit ,basis))
     ,(concat "Face used to highlight rtf-mode " desc ".")
     :group 'rtf))

(rtf-mkface rtf-brace-face 'font-lock-string-face "braces")
(rtf-mkface rtf-charescape-face 'font-lock-function-name-face "numeric escapes")
(rtf-mkface rtf-loud-cword-face 'font-lock-warning-face "important commands")
(rtf-mkface rtf-cword-face 'font-lock-keyword-face "commands")
(rtf-mkface rtf-cword-param-face 'font-lock-builtin-face "command-parameters")
(rtf-mkface rtf-cword-endingspace-face 'font-lock-comment-face "command-ending spaces")
(rtf-mkface rtf-star-face 'font-lock-doc-face "\\* commands")
(rtf-mkface rtf-escnewline-face 'font-lock-constant-face "\\ [Newline] sequences")
(rtf-mkface rtf-esctab-face 'font-lock-warning-face "\\ [Tab] sequences")
(rtf-mkface rtf-escother-face 'font-lock-type-face "\\ [other] sequences")
(rtf-mkface rtf-trailing-whitespace-face 'highlight "trailing space")

(defvar rtf-loudcmds
  '(
    rtf1 page pard par line sectd sect footnote 
    cell row trowd 
    fonttbl info colortbl stylesheet
    )
  "A few structurally super-important (and parameterless) RTF commands.")

;======================================================================

(defun rtf-make-loudcmd-re (cmdlist)
  (concat "\\(\\\\\\)\\("
	  (regexp-opt (mapcar 'symbol-name cmdlist))
	  "\\)\\b\\( ?\\)"))

(define-generic-mode 'rtf-mode
  nil ; the comment syntax list -- nil because RTF has no comments!
  nil ; keyword-list -- nil because we do everything below

  (list   ; the font lock list...

    ; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ; * Control words, \foo123, \foo-123, \foo

    ; A few structurally super-important (and parameterless) control words:
    (list (rtf-make-loudcmd-re rtf-loudcmds)
     '(1					'rtf-cword-face)
     '(2 					'rtf-loud-cword-face)
     '(3					'rtf-cword-endingspace-face)
     )
    
    '("\\(\\\\u-?[0-9]+ ?\\)" ; a unicodey escape
     1						'rtf-charescape-face)

    '("\\(\\\\[a-zA-Z]+\\)\\(-?[0-9]+\\)\\( ?\\)" ; with a num-param
     (1						'rtf-cword-face)
     (2						'rtf-cword-param-face)
     (3						'rtf-cword-endingspace-face)
     )

    '("\\(\\\\[a-zA-Z]+\\)\\( ?\\)" ; no param
     (1 					'rtf-cword-face)
     (2						'rtf-cword-endingspace-face)
     )
    ; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ; * Control symbols
    ;  ~  the fancy \* thing...
    '("\\(\\\\\\*\\)" 1 'rtf-star-face)

    ;  ~  \'xx escape
    '("\\(\\\\'[a-fA-F0-9][a-fA-F0-9]\\)"  	1 'rtf-charescape-face)

    ;  ~ \[NEWLINE] which means \par
    '("\\(\\\\\012\\)" 				1 'rtf-escnewline-face)

    ;  ~ \[TAB]     which means \tab
    '("\\(\\\\\011\\)" 				1 'rtf-esctab-face)

    ;  ~  \_ where _ is anything else, but probably one of ' - : \ _ { | } ~
    '("\\(\\\\[^a-zA-Z'\011\012]\\)"		1 'rtf-escother-face)

    ; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ; * '{' and '}' (unescaped, that is)
    '("\\({\\|}\\)" 				1 'rtf-brace-face)

    ; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ; And, incidentally:
    ;  ~ trailing whitespace -- not an error, but which is /significant/!
    '("\\([ \011]+\\)$" 1			'rtf-trailing-whitespace-face)

    ;; You COULD highlight /all/ significant spaces in the document with this:
    ;("\\([ \011]+\\)" 1			'rtf-trailing-whitespace-face)
    ;; but that would probably be more confusing than useful.

    )

  (list ".rtf\\'" )  ; auto-mode list -- our extensions

  (list 'rtf-mode-setup-function)
  "A major mode for editing/viewing RTF source.")

; TODO: support for blobs?  Seems tricky.
;======================================================================

(defun rtf-mode-stultify-character (str)
  "Mark this one-character string as nonmagical in the syntax table."
  (modify-syntax-entry (string-to-char str) "."))

(defun rtf-mode-fill-paragraph (arg)
  (message "rtf-mode doesn't currently support filling paragraphs")
  ; This is just to inhibit the actual normal filler, because
  ; that's usually a really bad idea for RTF.  (I will have
  ; to write a replacement for it eventually, but it'll be
  ; quite tricky.)
  t)

(defun rtf-mode-setup-function ()
  (dolist (s (split-string "\"()[]\\" ""))
    (rtf-mode-stultify-character s))

  (set (make-local-variable 'require-final-newline) nil)
  ; Many RTF files end on a "}" without a newline after it

  (set (make-local-variable 'fill-paragraph-function) 'rtf-mode-fill-paragraph)

  ;(set (make-local-variable 'fill-prefix) " ")
  ; ^^ That'd be good for entering text content, but it inserts
  ;    significant spaces when you're entering commands!

  t
)

(provide 'rtf-mode)

;;; rtf-mode.el ends here
