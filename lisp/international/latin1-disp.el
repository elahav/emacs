;;; latin1-disp.el --- display tables for other ISO 8859 on Latin-1 terminals -*- coding: emacs-mule -*-

;; Copyright (C) 2000, 2001 Free Software Foundation, Inc.

;; Author: Dave Love <fx@gnu.org>
;; Keywords: i18n

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This package sets up display of ISO 8859-n for n>1 by substituting
;; Latin-1 characters and sequences of them for characters which can't
;; be displayed, either because we're on a tty or because we don't
;; have the relevant window system fonts available.  For instance,
;; Latin-9 is very similar to Latin-1, so we can display most Latin-9
;; characters using the Latin-1 characters at the same code point and
;; fall back on more-or-less mnemonic ASCII sequences for the rest.

;; For the Latin charsets the ASCII sequences are mostly consistent
;; with the Quail prefix input sequences.  Latin-4 uses the Quail
;; postfix sequences since a prefix method isn't defined for Latin-4.

;; [A different approach is taken in the DOS display tables in
;; term/internal.el, and the relevant ASCII sequences from there are
;; available as an alternative; see `latin1-display-mnemonic'.  Only
;; these sequences are used for Arabic, Cyrillic, Greek and Hebrew.]

;; If you don't even have Latin-1, see iso-ascii.el and use the
;; complete tables from internal.el.  The ASCII sequences used here
;; are mostly in the same style as iso-ascii.

;;; Code:

;; Ensure `standard-display-table' is set up:
(require 'disp-table)
(require 'ucs-tables)

(defconst latin1-display-sets '(latin-2 latin-3 latin-4 latin-5 latin-8
		                latin-9 arabic cyrillic greek hebrew)
  "The ISO8859 character sets with defined Latin-1 display sequences.
These are the nicknames for the sets and correspond to Emacs language
environments.")

(defgroup latin1-display ()
  "Set up display tables for ISO8859 characters using Latin-1."
  :version "21.1"
  :link '(emacs-commentary-link "latin1-disp")
  :group 'i18n)

(defcustom latin1-display-format "{%s}"
  "A format string used to display the ASCII sequences.
The default encloses the sequence in braces, but you could just use
\"%s\" to avoid the braces."
  :group 'latin1-display
  :type 'string)

;;;###autoload
(defcustom latin1-display nil
  "Set up Latin-1/ASCII display for ISO8859 character sets.
This is done for each character set in the list `latin1-display-sets',
if no font is available to display it.  Characters are displayed using
the corresponding Latin-1 characters where they match.  Otherwise
ASCII sequences are used, mostly following the Latin prefix input
methods.  Some different ASCII sequences are used if
`latin1-display-mnemonic' is non-nil.

This option also treats some characters in the `mule-unicode-...'
charsets if you don't have a Unicode font with which to display them.

Setting this variable directly does not take effect;
use either M-x customize of the function `latin1-display'."
  :group 'latin1-display
  :type 'boolean
  :require 'latin1-disp
  :initialize 'custom-initialize-default
  :set (lambda (symbol value)
	 (if value
	     (apply #'latin1-display latin1-display-sets)
	   (latin1-display))))

;;;###autoload
(defun latin1-display (&rest sets)
  "Set up Latin-1/ASCII display for the arguments character SETS.
See option `latin1-display' for the method.  The members of the list
must be in `latin1-display-sets'.  With no arguments, reset the
display for all of `latin1-display-sets'. See also
`latin1-display-setup'.  As well as iso-8859 characters, this treats
some characters in the `mule-unicode-...' charsets if you don't have
a Unicode font with which to display them."
  (if sets
      (progn
	(mapc #'latin1-display-setup sets)
	(unless (latin1-char-displayable-p
		 (make-char 'mule-unicode-0100-24ff 32 33))
	  ;; It doesn't look as though we have a Unicode font.
	  (map-char-table
	   (lambda (c uc)
	     (when (and (char-valid-p c)
			(char-valid-p uc)
			(not (aref standard-display-table uc)))
	       (aset standard-display-table uc
		     (or (aref standard-display-table c)
			 (vector c)))))
	   ucs-mule-8859-to-mule-unicode)
	  ;; Extra stuff for windows-1252, in particular.
	  (mapc
	   (lambda (l)
	     (apply 'latin1-display-char l))
	   '((?\ôōú ",") ;; SINGLE LOW-9 QUOTATION MARK
	     (?\ôōū ",,") ;; DOUBLE LOW-9 QUOTATION MARK
	     (?\ôķĻ "...") ;; HORIZONTAL ELLIPSIS
	     (?\ôķ° "o/oo") ;; PER MILLE SIGN
	     (?\ôķš "<") ;; SINGLE LEFT-POINTING ANGLE QUOTATION MARK
	     (?\ôōü "``") ;; LEFT DOUBLE QUOTATION MARK
	     (?\ôōũ "''") ;; RIGHT DOUBLE QUOTATION MARK
	     (?\ôōķ "-") ;; EN DASH
	     (?\ôōô "--") ;; EM DASH
	     (?\ôõâ "TM") ;; TRADE MARK SIGN
	     (?\ôķē ">") ;; SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
	     )))
	  (setq latin1-display t))
    (mapc #'latin1-display-reset latin1-display-sets)
    (aset standard-display-table
	  (make-char 'mule-unicode-0100-24ff) nil)
    (aset standard-display-table
	  (make-char 'mule-unicode-2500-33ff) nil)
    (aset standard-display-table
	  (make-char 'mule-unicode-e000-ffff) nil)
    (setq latin1-display nil)
    (redraw-display)))

(defcustom latin1-display-mnemonic nil
  "Non-nil means to display potentially more mnemonic sequences.
These are taken from the tables in `internal.el' rather than the Quail
input sequences."
  :type 'boolean
  :group 'latin1-display)

(defun latin1-display-char (char display &optional alt-display)
  "Make an entry in `standard-display-table' for CHAR using string DISPLAY.
If ALT-DISPLAY is provided, use that instead if
`latin1-display-mnemonic' is non-nil.  The actual string displayed is
formatted using `latin1-display-format'."
  (if (and (stringp alt-display)
	   latin1-display-mnemonic)
      (setq display alt-display))
  (if (stringp display)
      (standard-display-ascii char (format latin1-display-format display))
    (aset standard-display-table char display)))

(defun latin1-display-identities (charset)
  "Display each character in CHARSET as the corresponding Latin-1 character.
CHARSET is a symbol which is the nickname of a language environment
using an ISO8859 character set."
  (if (eq charset 'cyrillic)
      (setq charset 'cyrillic-iso))
  (let ((i 32)
	(set (car (remq 'ascii (get-language-info charset 'charset)))))
    (while (<= i 127)
      (aset standard-display-table
	    (make-char set i)
	    (vector (make-char 'latin-iso8859-1 i)))
      (setq i (1+ i)))))

(defun latin1-display-reset (language)
  "Set up the default display for each character of LANGUAGE's charset.
LANGUAGE is a symbol naming a language environment using an ISO8859
character set."
  (if (eq language 'cyrillic)
      (setq language 'cyrillic-iso))
  (let ((charset (if (eq language 'arabic)
		     'arabic-iso8859-6
		   (car (remq 'ascii (get-language-info language
							'charset))))))
    (standard-display-default (make-char charset 32)
			      (make-char charset 127)))
  (sit-for 0))

(defun latin1-display-check-font (language)
  "Return non-nil if we have a font with an encoding for LANGUAGE.
LANGUAGE is a symbol naming a language environment using an ISO8859
character set: `latin-2', `hebrew' etc."
  (if (eq language 'cyrillic)
      (setq language 'cyrillic-iso))
  (let* ((info (get-language-info language 'charset))
	 (char (and info (make-char (car (remq 'ascii info)) ?\ ))))
    (and char (latin1-char-displayable-p char))))

;; This should be moved into mule-utils or somewhere after 21.1.
(defun latin1-char-displayable-p (char)
  (cond ((< char 256)
	 ;; Single byte characters are always displayable.
	 t)
	((display-multi-font-p)
	 ;; On a window system, a character is displayable if we have
	 ;; a font for that character in the default face of the
	 ;; currently selected frame.
	 (let ((fontset (frame-parameter (selected-frame) 'font))
	       font-pattern)
	   (if (query-fontset fontset)
	       (setq font-pattern (fontset-font fontset char)))
	   (or font-pattern
	       (setq font-pattern (fontset-font "fontset-default" char)))
	   (if font-pattern
	       (progn
		 ;; Now FONT-PATTERN is a string or a cons of family
		 ;; field pattern and registry field pattern.
		 (or (stringp font-pattern)
		     (setq font-pattern (concat "-"
						(or (car font-pattern) "*")
						"-*-"
						(cdr font-pattern))))
		 (x-list-fonts font-pattern 'default (selected-frame) 1)))))
	(t
	 (let ((coding (terminal-coding-system)))
	   (if coding
	       (let ((safe-chars (coding-system-get coding 'safe-chars))
		     (safe-charsets (coding-system-get coding 'safe-charsets)))
		 (or (and safe-chars
			  (aref safe-chars char))
		     (and safe-charsets
			  (memq (char-charset char) safe-charsets)))))))))

(defun latin1-display-setup (set &optional force)
  "Set up Latin-1 display for characters in the given SET.
SET must be a member of `latin1-display-sets'.  Normally, check
whether a font for SET is available and don't set the display if it
is.  If FORCE is non-nil, set up the display regardless."
  (cond
   ((eq set 'latin-2)
    (when (or force
	      (not (latin1-display-check-font set)))
      (latin1-display-identities set)
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?Æ "'C" "C'")
	 (?Đ "'D" "/D")
	 (?Ļ "'S" "S'")
	 (?æ "'c" "c'")
	 (?đ "'d" "/d")
	 (?Å "'L" "L'")
	 (?ņ "'n" "n'")
	 (?Ņ "'N" "N'")
	 (?ā "'r" "r'")
	 (?Ā "'R" "R'")
	 (?ļ "'s" "s'")
	 (?ŧ "'z" "z'")
	 (?Ŧ "'Z" "Z'")
	 (?Ą "`A" "A;")
	 (?Ę "`E" "E;")
	 (?Ŗ "`L" "/L")
	 (?Ē "`S" ",S")
	 (?Ū "`T" ",T")
	 (?¯ "`Z" "Z^.")
	 (?ą "`a" "a;")
	 (?ŗ "`l" "/l")
	 (?ę "`e" "e;")
	 (?ē "`s" ",s")
	 (?ū "`t" ",t")
	 (?ŋ "`z" "z^.")
	 (?˙ "`." "'.")
	 (?Ã "~A" "A(")
	 (?Č "~C" "C<")
	 (?Ī "~D" "D<")
	 (?Ė "~E" "E<")
	 (?ė "~e" "e<")
	 (?Ĩ "~L" "L<")
	 (?Ō "~N" "N<")
	 (?Õ "~O" "O''")
	 (?Ø "~R" "R<")
	 (?Š "~S" "S<")
	 (?Ģ "~T" "T<")
	 (?Û "~U" "U''")
	 (?Ž "~Z" "Z<")
	 (?ã "~a" "a(}")
	 (?č "~c" "c<")
	 (?ī "~d" "d<")
	 (?ĩ "~l" "l<")
	 (?ō "~n" "n<")
	 (?õ "~o" "o''")
	 (?ø "~r" "r<")
	 (?š "~s" "s<")
	 (?ģ "~t" "t<")
	 (?û "~u" "u''")
	 (?ž "~z" "z<")
	 (?ˇ "~v" "'<")			; ?ĸ in latin-pre
	 (?ĸ "~~" "'(")
	 (?ų "uu" "u^0")
	 (?Ų "UU" "U^0")
	 (?Ä "\"A")
	 (?ä "\"a")
	 (?Ë "\"E" "E:")
	 (?ë "\"e")
	 (?Ŋ "''" "'")
	 (?ˇ "'<")			; Lynx's rendering of caron
	 ))))

   ((eq set 'latin-3)
    (when (or force
	      (not (latin1-display-check-font set)))
      (latin1-display-identities set)
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?Ą "/H")
	 (?ĸ "~`" "'(")
	 (?Ļ "^H" "H^")
	 (?ļ "^h" "h^")
	 (?Š ".I" "I^.")
	 (?Ē ",S")
	 (?Ģ "~G" "G(")
	 (?Ŧ "^J" "J^")
	 (?¯ ".Z" "Z^.")
	 (?ą "/h")
	 (?š ".i" "i^.")
	 (?ē ",s")
	 (?ģ "~g" "g(")
	 (?ŧ "^j" "j^")
	 (?ŋ ".Z" "z^.")
	 (?Å ".c" "C^.")
	 (?Æ "^C" "C^")
	 (?Õ ".G" "G^.")
	 (?Ø "^G" "G^")
	 (?Ũ "~U" "U(")
	 (?Ū "^S" "S^")
	 (?å ".C" "c^.")
	 (?æ "^c" "c^")
	 (?õ ".g" "g^.")
	 (?ø "^g" "g^")
	 (?ũ "~u" "u(")
	 (?ū "^s" "s^")
	 (?˙ "/." "^.")))))

   ((eq set 'latin-4)
    (when (or force
	      (not (latin1-display-check-font set)))
      (latin1-display-identities set)
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?Ą "A," "A;")
	 (?ĸ "k/" "kk")
	 (?Ŗ "R," ",R")
	 (?Ĩ "I~" "?I")
	 (?Ļ "L," ",L")
	 (?Š "S~" "S<")
	 (?Ē "E-")
	 (?Ģ "G," ",G")
	 (?Ŧ "T/" "/T")
	 (?Ž "Z~" "Z<")
	 (?ą "a," "a;")
	 (?˛ "';")
	 (?ŗ "r," ",r")
	 (?ĩ "i~" "~i")
	 (?ļ "l," ",l")
	 (?ˇ "'<")
	 (?š "s~" "s<")
	 (?ē "e-")
	 (?ģ "g," ",g")
	 (?ŧ "t/" "/t")
	 (?Ŋ "N/" "NG")
	 (?ž "z~" "z<")
	 (?ŋ "n/" "ng")
	 (?Ā "A-")
	 (?Į "I," "I;")
	 (?Č "C~" "C<")
	 (?Ę "E," "E;")
	 (?Ė "E." "E^.")
	 (?Ī "I-")
	 (?Ņ "N," ",N")
	 (?Ō "O-")
	 (?Ķ "K," ",K")
	 (?Ų "U," "U;")
	 (?Ũ "U~" "~U")
	 (?Ū "U-")
	 (?ā "a-")
	 (?į "i," "i;")
	 (?č "c~" "c<")
	 (?ę "e," "e;")
	 (?ė "e." "e^.")
	 (?ī "i-")
	 (?đ "d/" "/d")
	 (?ņ "n," ",n")
	 (?ō "o-")
	 (?ķ "k," ",k")
	 (?ų "u," "u;")
	 (?ũ "u~" "~u")
	 (?ū "u-")
	 (?˙ "^.")))))

   ((eq set 'latin-5)
    (when (or force
	      (not (latin1-display-check-font set)))
      (latin1-display-identities set)
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?đ "~g" "g(")
	 (?Đ "~G" "G(")
	 (?Ũ ".I" "I^.")
	 (?ū ",s")
	 (?Ū ",S")
	 (?ę "^e" "e<")			; from latin-post
	 (?ė ".e" "e^.")
	 (?ī "\"i" "i-")		; from latin-post
	 (?ũ ".i" "i.")))))

   ((eq set 'latin-8)
    (when (or force
	      (not (latin1-display-check-font set)))
      (latin1-display-identities set)
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?Ą ".B" "B`")
	 (?ĸ ".b" "b`")
	 (?Ĩ ".c" "c`")
	 (?¤ ".C" "C`")
	 (?Ļ ".D" "D`")
	 (?Ģ ".d" "d`")
	 (?¸ "`w")
	 (?¨ "`W")
	 (?ē "'w" "w'")
	 (?Ē "'W" "W'")
	 (?ŧ "`y")
	 (?Ŧ "`Y")
	 (?ą ".f" "f`")
	 (?° ".F" "F`")
	 (?ŗ ".g" "g`")
	 (?˛ ".G" "G`")
	 (?ĩ ".m" "m`")
	 (?´ ".M" "M`")
	 (?š ".p" "p`")
	 (?ˇ ".P" "P`")
	 (?ŋ ".s" "s`")
	 (?ģ ".S" "S`")
	 (?ž "\"w")
	 (?Ŋ "\"W")
	 (?đ "^w" "w^")
	 (?Đ "^W" "W^")
	 (?÷ ".t" "t`")
	 (?× ".T" "T`")
	 (?ū "^y" "y^")
	 (?Ū "^Y" "Y^")
	 (?¯ "\"Y")))))

   ((eq set 'latin-9)
    (when (or force
	      (not (latin1-display-check-font set)))
      (latin1-display-identities set)
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?¨ "~s" "s<")
	 (?Ļ "~S" "S<")
	 (?¤ "Euro" "E=")
	 (?¸ "~z" "z<")
	 (?´ "~Z" "Z<")
	 (?ž "\"Y")
	 (?Ŋ "oe")
	 (?ŧ "OE")))))

   ((eq set 'greek)
    (when (or force
	      (not (latin1-display-check-font set)))
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?Ą "9'")
	 (?ĸ "'9")
	 (?¯ "-M")
	 (?ĩ "'%")
	 (?ļ "'A")
	 (?¸ "'E")
	 (?š "'H")
	 (?ē "'I")
	 (?ŧ "'O")
	 (?ž "'Y")
	 (?ŋ "W%")
	 (?Ā "i3")
	 (?Ã "G*")
	 (?Ä "D*")
	 (?Č "TH")
	 (?Ë "L*")
	 (?Î "C*")
	 (?Đ "P*")
	 (?Ķ "S*")
	 (?Ö "F*")
	 (?Ø "Q*")
	 (?Ų "W*")
	 (?Ú "\"I")
	 (?Û "\"Y")
	 (?Ü "a%")
	 (?Ũ "e%")
	 (?Ū "y%")
	 (?ß "i%")
	 (?ā "u3")
	 (?á "a*")
	 (?â "b*")
	 (?ã "g*")
	 (?ä "d*")
	 (?å "e*")
	 (?æ "z*")
	 (?į "y*")
	 (?č "h*")
	 (?é "i*")
	 (?ę "k")
	 (?ë "l*")
	 (?ė "m*")
	 (?í "n*")
	 (?î "c*")
	 (?đ "p*")
	 (?ņ "r*")
	 (?ō "*s")
	 (?ķ "s*")
	 (?ô "t*")
	 (?õ "u")
	 (?ö "f*")
	 (?÷ "x*")
	 (?ø "q*")
	 (?ų "w*")
	 (?ú "\"i")
	 (?û "\"u")
	 (?ü "'o")
	 (?ũ "'u")
	 (?ū "'w")))
      (mapc
       (lambda (l)
	 (aset standard-display-table (car l) (string-to-vector (cadr l))))
       '((?Á "A")
	 (?Â "B")
	 (?Å "E")
	 (?Æ "Z")
	 (?Į "H")
	 (?É "I")
	 (?Ę "J")
	 (?Ė "M")
	 (?Í "N")
	 (?Ī "O")
	 (?Ņ "P")
	 (?Ô "T")
	 (?Õ "Y")
	 (?× "X")
	 (?ī "o")))))

   ((eq set 'hebrew)
    (when (or force
	      (not (latin1-display-check-font set)))
      ;; Don't start with identities, since we don't have definitions
      ;; for a lot of Hebrew in internal.el.  (Intlfonts is also
      ;; missing some glyphs.)
      (let ((i 34))
	(while (<= i 62)
	  (aset standard-display-table
		(make-char 'hebrew-iso8859-8 i)
		(vector (make-char 'latin-iso8859-1 i)))
	  (setq i (1+ i))))
      (mapc
       (lambda (l)
	 (aset standard-display-table (car l) (string-to-vector (cadr l))))
       '((?ß "=2")
	 (?ā "A+")
	 (?á "B+")
	 (?â "G+")
	 (?ã "D+")
	 (?ä "H+")
	 (?å "W+")
	 (?æ "Z+")
	 (?į "X+")
	 (?č "Tj")
	 (?é "J+")
	 (?ę "K%")
	 (?ë "K+")
	 (?ė "L+")
	 (?í "M%")
	 (?î "M+")
	 (?ī "N%")
	 (?đ "N+")
	 (?ņ "S+")
	 (?ō "E+")
	 (?ķ "P%")
	 (?ô "P+")
	 (?õ "Zj")
	 (?ö "ZJ")
	 (?÷ "Q+")
	 (?ø "R+")
	 (?ų "Sh")
	 (?ú "T+")))))

   ;; Arabic probably isn't so useful in the absence of Arabic
   ;; language support...
   ((eq set 'arabic)
    (setq set 'arabic)
    (when (or force
	      (not (latin1-display-check-font set)))
      (aset standard-display-table ?  " ")
      (aset standard-display-table ?¤ "¤")
      (aset standard-display-table ?­ "­")
      (mapc (lambda (l)
	      (apply  'latin1-display-char l))
	    '((?Ŧ ",+")
	      (?ģ ";+")
	      (?ŋ "?+")
	      (?Á "H'")
	      (?Â "aM")
	      (?Ã "aH")
	      (?Ä "wH")
	      (?Å "ah")
	      (?Æ "yH")
	      (?Į "a+")
	      (?Č "b+")
	      (?É "tm")
	      (?Ę "t+")
	      (?Ë "tk")
	      (?Ė "g+")
	      (?Í "hk")
	      (?Î "x+")
	      (?Ī "d+")
	      (?Đ "dk")
	      (?Ņ "r+")
	      (?Ō "z+")
	      (?Ķ "s+")
	      (?Ô "sn")
	      (?Õ "c+")
	      (?Ö "dd")
	      (?× "tj")
	      (?Ø "zH")
	      (?Ų "e+")
	      (?Ú "i+")
	      (?ā "++")
	      (?á "f+")
	      (?â "q+")
	      (?ã "k+")
	      (?ä "l+")
	      (?å "m+")
	      (?æ "n+")
	      (?į "h+")
	      (?č "w+")
	      (?é "j+")
	      (?ę "y+")
	      (?ë ":+")
	      (?ė "\"+")
	      (?í "=+")
	      (?î "/+")
	      (?ī "'+")
	      (?đ "1+")
	      (?ņ "3+")
	      (?ō "0+")))))

   ((eq set 'cyrillic)
    (setq set 'cyrillic-iso)
    (when (or force
	      (not (latin1-display-check-font set)))
      (mapc
       (lambda (l)
	 (apply 'latin1-display-char l))
       '((?ĸ "Dj")
	 (?Ŗ "Gj")
	 (?¤ "IE")
	 (?Š "Lj")
	 (?Ē "Nj")
	 (?Ģ "Ts")
	 (?Ŧ "Kj")
	 (?Ž "V%")
	 (?¯ "Dzh")
	 (?ą "B=")
	 (?ŗ "â")
	 (?´ "D")
	 (?ļ "Z%")
	 (?ˇ "3")
	 (?¸ "U")
	 (?š "J=")
	 (?ģ "L=")
	 (?ŋ "P=")
	 (?Ã "Y")
	 (?Ä "č")
	 (?Æ "C=")
	 (?Į "C%")
	 (?Č "S%")
	 (?É "Sc")
	 (?Ę "=\"")
	 (?Ë "Y=")
	 (?Ė "%\"")
	 (?Í "Ee")
	 (?Î "Yu")
	 (?Ī "Ya")
	 (?Ņ "b")
	 (?Ō "v=")
	 (?Ķ "g=")
	 (?Ô "g")
	 (?Ö "z%")
	 (?× "z=")
	 (?Ø "u")
	 (?Ų "j=")
	 (?Ú "k")
	 (?Û "l=")
	 (?Ü "m=")
	 (?Ũ "n=")
	 (?ß "n")
	 (?ā "p")
	 (?â "t=")
	 (?ä "f=")
	 (?æ "c=")
	 (?į "c%")
	 (?č "s%")
	 (?é "sc")
	 (?ę "='")
	 (?ë "y=")
	 (?ė "%'")
	 (?í "ee")
	 (?î "yu")
	 (?ī "ya")
	 (?đ "N0")
	 (?ō "dj")
	 (?ķ "gj")
	 (?ô "ie")
	 (?ų "lj")
	 (?ú "nj")
	 (?û "ts")
	 (?ü "kj")
	 (?ū "v%")
	 (?˙ "dzh")))
      (mapc
       (lambda (l)
	 (aset standard-display-table (car l) (string-to-vector (cadr l))))
       '((?Ą "Ë")
	 (?Ĩ "S")
	 (?Ļ "I")
	 (?§ "Ī")
	 (?¨ "J")
	 (?ņ "ë")
	 (?ũ "§")
	 (?­ "-")
	 (?° "A")
	 (?˛ "B")
	 (?ĩ "E")
	 (?ē "K")
	 (?ŧ "M")
	 (?Ŋ "H")
	 (?ž "O")
	 (?Ā "P")
	 (?Á "C")
	 (?Â "T")
	 (?Å "X")
	 (?Đ "a")
	 (?Õ "e")
	 (?Ū "o")
	 (?á "c")
	 (?ã "y")
	 (?å "x")
	 (?õ "s")
	 (?ö "i")
	 (?÷ "ī")
	 (?ø "j")))))

   (t (error "Unsupported character set: %S" set)))
   
  (sit-for 0))

(provide 'latin1-disp)

;;; latin1-disp.el ends here
