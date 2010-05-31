;;; aaph.el - Major mode for editing aphasia 2 source
;; Adapted from sml-mode.el and highly damaged by Tom 7.

;; Copyright (C) 1989, Lars Bo Nielsen; 1994,1997, Matthew J. Morley
;; 2003-2004 Tom Murphy VII

;; $Revision: 1.5 $
;; $Date: 2008/04/27 14:28:19 $

;; This file is not part of GNU Emacs, but it is distributed under the
;; same conditions.

;; ====================================================================

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to the
;; Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;; ====================================================================


;;; VERSION STRING

(defconst aaph-mode-version-string
  "aaph-mode, version 3.3(beta)")

(provide 'aaph-mode)

(defun aaph-untabify-buffer ()
  "Untabify the entire buffer, since aphasia counts space characters in indication."
  (interactive "P")
  (save-excursion
    (untabify (point-min) (point-max))
  ))

;;; VARIABLES CONTROLLING INDENTATION

(defvar aaph-indent-level 4
  "*Indentation of blocks in ML (see also `aaph-structure-indent').")

(defvar aaph-structure-indent 0          ; Not currently an option.
  "Indentation of signature/structure/functor declarations.")

(defvar aaph-pipe-indent -2
  "*Extra (usually negative) indentation for lines beginning with |.")

(defvar aaph-case-indent nil
  "*How to indent case-of expressions.
    If t:   case expr                     If nil:   case expr of
              of exp1 => ...                            exp1 => ...
               | exp2 => ...                          | exp2 => ...

The first seems to be the standard in SML/NJ, but the second
seems nicer...")

(defvar aaph-nested-if-indent nil
  "*Determine how nested if-then-else will be formatted:
    If t: if exp1 then exp2               If nil:   if exp1 then exp2
          else if exp3 then exp4                    else if exp3 then exp4
          else if exp5 then exp6                         else if exp5 then exp6
               else exp7                                      else exp7")

(defvar aaph-type-of-indent t
  "*How to indent `let' `struct' etc.
    If t:  fun foo bar = let              If nil:  fun foo bar = let
                             val p = 4                 val p = 4
                         in                        in
                             bar + p                   bar + p
                         end                       end

Will not have any effect if the starting keyword is first on the line.")

(defvar aaph-electric-semi-mode nil
  "*If t, `\;' will self insert, reindent the line, and do a newline.
If nil, just insert a `\;'. (To insert while t, do: C-q \;).")

(defvar aaph-paren-lookback 1000
  "*How far back (in chars) the indentation algorithm should look
for open parenthesis. High value means slow indentation algorithm. A
value of 1000 (being the equivalent of 20-30 lines) should suffice
most uses. (A value of nil, means do not look at all)")

;;; OTHER GENERIC MODE VARIABLES

(defvar aaph-mode-info "aaph-mode"
  "*Where to find Info file for aaph-mode.
The default assumes the info file \"aaph-mode.info\" is on Emacs' info
directory path. If it is not, either put the file on the standard path
or set the variable aaph-mode-info to the exact location of this file
which is part of the aaph-mode 3.2 (and later) distribution. E.g:  

  (setq aaph-mode-info \"/usr/me/lib/info/aaph-mode\") 

in your .emacs file. You can always set it interactively with the
set-variable command.")

(defvar aaph-mode-hook nil
  "*This hook is run when aaph-mode is loaded, or a new aaph-mode buffer created.
This is a good place to put your preferred key bindings.")

(defvar aaph-load-hook nil
  "*This hook is run when aaph-mode (aaph-mode.el) is loaded into Emacs.")

(defvar aaph-mode-abbrev-table nil "*AAPH mode abbrev table (default nil)")

(defvar aaph-error-overlay t
  "*Non-nil means use an overlay to highlight errorful code in the buffer.

This gets set when `aaph-mode' is invoked\; if you don't like/want SML 
source errors to be highlighted in this way, do something like

  \(setq-default aaph-error-overlay nil\)

in your `aaph-load-hook', say.")

(make-variable-buffer-local 'aaph-error-overlay)

;;; CODE FOR AAPH-MODE 

(defun aaph-mode-info ()
  "Command to access the TeXinfo documentation for aaph-mode.
See doc for the variable aaph-mode-info."
  (interactive)
  (require 'info)
  (condition-case nil
      (funcall 'Info-goto-node (concat "(" aaph-mode-info ")"))
    (error (progn
             (describe-variable 'aaph-mode-info)
             (message "Can't find it... set this variable first!")))))

(defun aaph-indent-level (&optional indent)
   "Allow the user to change the block indentation level. Numeric prefix 
accepted in lieu of prompting."
   (interactive "NIndentation level: ")
   (setq aaph-indent-level indent))

(defun aaph-pipe-indent (&optional indent)
  "Allow to change pipe indentation level (usually negative). Numeric prefix
accepted in lieu of prompting."
   (interactive "NPipe Indentation level: ")
   (setq aaph-pipe-indent indent))

(defun aaph-case-indent (&optional of)
  "Toggle aaph-case-indent. Prefix means set it to nil."
  (interactive "P")
  (setq aaph-case-indent (and (not of) (not aaph-case-indent)))
  (if aaph-case-indent (message "%s" "true") (message "%s" nil)))

(defun aaph-nested-if-indent (&optional of)
  "Toggle aaph-nested-if-indent. Prefix means set it to nil."
  (interactive "P")
  (setq aaph-nested-if-indent (and (not of) (not aaph-nested-if-indent)))
  (if aaph-nested-if-indent (message "%s" "true") (message "%s" nil)))

(defun aaph-type-of-indent (&optional of)
  "Toggle aaph-type-of-indent. Prefix means set it to nil."
  (interactive "P")
  (setq aaph-type-of-indent (and (not of) (not aaph-type-of-indent)))
  (if aaph-type-of-indent (message "%s" "true") (message "%s" nil)))

(defun aaph-electric-semi-mode (&optional of)
  "Toggle aaph-electric-semi-mode. Prefix means set it to nil."
  (interactive "P")
  (setq aaph-electric-semi-mode (and (not of) (not aaph-electric-semi-mode)))
  (message "%s" (concat "Electric semi mode is " 
                   (if aaph-electric-semi-mode "on" "off"))))

;;; BINDINGS: these should be common to the source and process modes...

(defun install-aaph-keybindings (map)
  ;; Text-formatting commands:
  (define-key map "\C-c\C-i" 'aaph-mode-info)
  (define-key map "\M-|"     'aaph-electric-pipe)
  (define-key map "\M-q"     'aaph-fill-comment)
  (define-key map "\;"       'aaph-electric-semi)
  (define-key map "\M-*"     'aaph-insert-comment)
  (define-key map "\M-\t"    'aaph-back-to-outer-indent)
  (define-key map "\C-j"     'newline-and-indent)
  (define-key map "\177"     'backward-delete-char-untabify)
  (define-key map "\C-\M-\\" 'aaph-indent-region)
  (define-key map "\t"       'aaph-indent-line) ; ...except this one
  ;; Process commands added to aaph-mode-map -- these should autoload
  (define-key map "\C-c\C-l" 'aaph-load-file)
  (define-key map "\C-c`"    'aaph-next-error))

;;; Autoload functions -- no-doc is another idea cribbed from AucTeX!

(defvar aaph-no-doc
  "This function is part of aaph-proc, and has not yet been loaded.
Full documentation will be available after autoloading the function."
  "Documentation for autoloading functions.")

(autoload 'aaph             "aaph-proc"   aaph-no-doc t)
(autoload 'aaph-load-file   "aaph-proc"   aaph-no-doc t)

(autoload 'switch-to-aaph   "aaph-proc"   aaph-no-doc t)
(autoload 'aaph-send-region "aaph-proc"   aaph-no-doc t)
(autoload 'aaph-send-buffer "aaph-proc"   aaph-no-doc t)
(autoload 'aaph-next-error  "aaph-proc"   aaph-no-doc t)

(defvar aaph-mode-map nil "The keymap used in aaph-mode.")
(cond ((not aaph-mode-map)
       (setq aaph-mode-map (make-sparse-keymap))
       (install-aaph-keybindings aaph-mode-map)
       (define-key aaph-mode-map "\C-c\C-s" 'switch-to-aaph)
       (define-key aaph-mode-map "\C-c\C-r" 'aaph-send-region)
       (define-key aaph-mode-map "\C-c\C-b" 'aaph-send-buffer)))

;;; H A C K   A T T A C K !   X E M A C S   V E R S U S   E M A C S

(cond ((fboundp 'make-extent)
       ;; suppose this is XEmacs

       (defun aaph-make-overlay ()
         "Create a new text overlay (extent) for the AAPH buffer."
         (let ((ex (make-extent 1 1)))
           (set-extent-property ex 'face 'zmacs-region) ex))

       (defalias 'aaph-is-overlay 'extentp)

       (defun aaph-overlay-active-p ()
         "Determine whether the current buffer's error overlay is visible."
         (and (aaph-is-overlay aaph-error-overlay)
              (not (zerop (extent-length aaph-error-overlay)))))

       (defalias 'aaph-move-overlay 'set-extent-endpoints))

      ((fboundp 'make-overlay)
       ;; otherwise assume it's Emacs

       (defun aaph-make-overlay ()
         "Create a new text overlay (extent) for the AAPH buffer."
         (let ((ex (make-overlay 0 0)))
           (overlay-put ex 'face 'region) ex))

       (defalias 'aaph-is-overlay 'overlayp)

       (defun aaph-overlay-active-p ()
         "Determine whether the current buffer's error overlay is visible."
         (and (aaph-is-overlay aaph-error-overlay)
              (not (equal (overlay-start aaph-error-overlay)
                          (overlay-end aaph-error-overlay)))))

       (defalias 'aaph-move-overlay 'move-overlay))
      (t
       ;; what *is* this!?
       (defalias 'aaph-is-overlay 'ignore)
       (defalias 'aaph-overlay-active-p 'ignore)
       (defalias 'aaph-make-overlay 'ignore)
       (defalias 'aaph-move-overlay 'ignore)))

;;; MORE CODE FOR AAPH-MODE

(defun aaph-mode-version ()
  "This file's version number (aaph-mode)."
  (interactive)
  (message aaph-mode-version-string))

(defvar aaph-mode-syntax-table nil "The syntax table used in aaph-mode.")
(if aaph-mode-syntax-table
    ()
  (setq aaph-mode-syntax-table (make-syntax-table))
  ;; Set everything to be "." (punctuation) except for [A-Za-z0-9],
  ;; which will default to "w" (word-constituent).
  (let ((i 0))
    (while (< i ?0)
      (modify-syntax-entry i "." aaph-mode-syntax-table)
      (setq i (1+ i)))
    (setq i (1+ ?9))
    (while (< i ?A)
      (modify-syntax-entry i "." aaph-mode-syntax-table)
      (setq i (1+ i)))
    (setq i (1+ ?Z))
    (while (< i ?a)
      (modify-syntax-entry i "." aaph-mode-syntax-table)
      (setq i (1+ i)))
    (setq i (1+ ?z))
    (while (< i 128)
      (modify-syntax-entry i "." aaph-mode-syntax-table)
      (setq i (1+ i))))

  ;; Now we change the characters that are meaningful to us.
  (modify-syntax-entry ?\(      "()1"   aaph-mode-syntax-table)
  (modify-syntax-entry ?\)      ")(4"   aaph-mode-syntax-table)
  (modify-syntax-entry ?\[      "(]"    aaph-mode-syntax-table)
  (modify-syntax-entry ?\]      ")["    aaph-mode-syntax-table)
  (modify-syntax-entry ?{       "(}"    aaph-mode-syntax-table)
  (modify-syntax-entry ?}       "){"    aaph-mode-syntax-table)
  (modify-syntax-entry ?\*      ". 23"  aaph-mode-syntax-table)
  (modify-syntax-entry ?\"      "\""    aaph-mode-syntax-table)
;; close, but doesn't work. font-lock wants to find matching quotes,
;; not *any* two quotes.
;  (modify-syntax-entry ?\[      "\""    aaph-mode-syntax-table)
;  (modify-syntax-entry ?\]      "\""    aaph-mode-syntax-table)
  (modify-syntax-entry ?-       "w"     aaph-mode-syntax-table)
  (modify-syntax-entry ?        " "     aaph-mode-syntax-table)
  (modify-syntax-entry ?\t      " "     aaph-mode-syntax-table)
  (modify-syntax-entry ?\n      " "     aaph-mode-syntax-table)
  (modify-syntax-entry ?\f      " "     aaph-mode-syntax-table)
  (modify-syntax-entry ?\'      "w"     aaph-mode-syntax-table)
  (modify-syntax-entry ?\_      "w"     aaph-mode-syntax-table))

;;;###Autoload
(defun aaph-mode ()
  "Major mode for editing ML code.
Tab indents for ML code.
Comments are delimited with (* ... *).
Blank lines and form-feeds separate paragraphs.
Delete converts tabs to spaces as it moves back.

For information on running an inferior ML process, see the documentation
for inferior-aaph-mode (set this up with \\[aaph]).

Customisation: Entry to this mode runs the hooks on aaph-mode-hook.

Variables controlling the indentation
=====================================

Seek help (\\[describe-variable]) on individual variables to get current settings.

aaph-indent-level (default 4)
    The indentation of a block of code.

aaph-pipe-indent (default -2)
    Extra indentation of a line starting with \"|\".

aaph-case-indent (default nil)
    Determine the way to indent case-of expression.

aaph-nested-if-indent (default nil)
    Determine how nested if-then-else expressions are formatted.

aaph-type-of-indent (default t)
    How to indent let, struct, local, etc.
    Will not have any effect if the starting keyword is first on the line.

aaph-electric-semi-mode (default nil)
    If t, a `\;' will reindent line, and perform a newline.

aaph-paren-lookback (default 1000)
    Determines how far back (in chars) the indentation algorithm should 
    look to match parenthesis. A value of nil, means do not look at all.

Mode map
========
\\{aaph-mode-map}"

  (interactive)
  (kill-all-local-variables)
  (aaph-mode-variables)
  (use-local-map aaph-mode-map)
  (setq major-mode 'aaph-mode)
  (setq mode-name "AAPH")
  ; need to avoid writing tabs, ever
  (add-hook 'write-contents-hooks 'aaph-untabify-buffer 'yes-do-it-last)
  (run-hooks 'aaph-mode-hook))            ; Run the hook last

(defun aaph-mode-variables ()
  (set-syntax-table aaph-mode-syntax-table)
  (setq local-abbrev-table aaph-mode-abbrev-table)
  ;; A paragraph is separated by blank lines or ^L only.
  (make-local-variable 'paragraph-start)
  (setq paragraph-start (concat "^[\t ]*$\\|" page-delimiter))
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'aaph-indent-line)
  (make-local-variable 'comment-start)
  (setq comment-start "(* ")
  (make-local-variable 'comment-end)
  (setq comment-end " *)")
  (make-local-variable 'comment-column)
  (setq comment-column 40)              
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "(\\*+[ \t]?")
  (make-local-variable 'comment-indent-function)
  (setq comment-indent-function 'aaph-comment-indent)
  (setq aaph-error-overlay (and aaph-error-overlay (aaph-make-overlay))))

  ;; Adding these will fool the matching of parens -- because of a
  ;; bug in Emacs (in scan_lists, i think)... it would be nice to 
  ;; have comments treated as white-space.
  ;;(make-local-variable 'parse-sexp-ignore-comments)
  ;;(setq parse-sexp-ignore-comments t)

(defun aaph-error-overlay (undo &optional beg end buffer)
  "Move `aaph-error-overlay' so it surrounds the text region in the
current buffer. If the buffer-local variable `aaph-error-overlay' is
non-nil it should be an overlay \(or extent, in XEmacs speak\)\; this
function moves the overlay over the current region. If the optional
BUFFER argument is given, move the overlay in that buffer instead of
the current buffer.

Called interactively, the optional prefix argument UNDO indicates that
the overlay should simply be removed: \\[universal-argument] \
\\[aaph-error-overlay]."
  (interactive "P")
  (save-excursion
    (set-buffer (or buffer (current-buffer)))
    (if (aaph-is-overlay aaph-error-overlay)
        (if undo
            (aaph-move-overlay aaph-error-overlay 1 1)
          ;; if active regions, signals mark not active if no region set
          (let ((beg (or beg (region-beginning)))
                (end (or end (region-end))))
            (aaph-move-overlay aaph-error-overlay beg end))))))

(defconst aaph-pipe-matchers-reg
  "\\bcase\\b\\|\\bfn\\b\\|\\bfun\\b\\|\\bhandle\\b\
\\|\\bdatatype\\b\\|\\babstype\\b\\|\\band\\b"
  "The keywords a `|' can follow.")

(defun aaph-electric-pipe ()
  "Insert a \"|\". 
Depending on the context insert the name of function, a \"=>\" etc."
  (interactive)
  (let ((case-fold-search nil)          ; Case sensitive
        (here (point))
        (match (save-excursion
                 (aaph-find-matching-starter aaph-pipe-matchers-reg)
                 (point)))
        (tmp "  => ")
        (case-or-handle-exp t))
    (if (/= (save-excursion (beginning-of-line) (point))
            (save-excursion (skip-chars-backward "\t ") (point)))
        (insert "\n"))
    (insert "|")
    (save-excursion
      (goto-char match)
      (cond
       ;; It was a function, insert the function name
       ((looking-at "fun\\b")
        (setq tmp (concat " " (buffer-substring
                               (progn (forward-char 3)
                                      (skip-chars-forward "\t\n ") (point))
                               (progn (forward-word 1) (point))) " "))
        (setq case-or-handle-exp nil))
       ;; It was a datatype, insert nothing
       ((looking-at "datatype\\b\\|abstype\\b")
        (setq tmp " ") (setq case-or-handle-exp nil))
       ;; If it is an and, then we have to see what it was
       ((looking-at "and\\b")
        (let (isfun)
          (save-excursion
            (condition-case ()
                (progn
                  (re-search-backward "datatype\\b\\|abstype\\b\\|fun\\b")
                  (setq isfun (looking-at "fun\\b")))
              (error (setq isfun nil))))
          (if isfun
              (progn
                (setq tmp
                      (concat " " (buffer-substring
                                   (progn (forward-char 3)
                                          (skip-chars-forward "\t\n ") (point))
                                   (progn (forward-word 1) (point))) " "))
                (setq case-or-handle-exp nil))
            (setq tmp " ") (setq case-or-handle-exp nil))))))
    (insert tmp)
    (aaph-indent-line)
    (beginning-of-line)
    (skip-chars-forward "\t ")
    (forward-char (1+ (length tmp)))
    (if case-or-handle-exp
        (forward-char -4))))

(defun aaph-electric-semi ()
  "Inserts a \;.
If variable aaph-electric-semi-mode is t, indent the current line, insert 
a newline, and indent."
  (interactive)
  (insert "\;")
  (if aaph-electric-semi-mode
      (reindent-then-newline-and-indent)))

;;; INDENTATION !!!

(defun aaph-mark-function ()
  "Synonym for mark-paragraph -- sorry.
If anyone has a good algorithm for this..."
  (interactive)
  (mark-paragraph))

(defun aaph-indent-region (begin end)
  "Indent region of ML code."
  (interactive "r")
  (message "Indenting region...")
  (save-excursion
    (goto-char end) (setq end (point-marker)) (goto-char begin)
    (while (< (point) end)
      (skip-chars-forward "\t\n ")
      (aaph-indent-line)
      (end-of-line))
    (move-marker end nil))
  (message "Indenting region... done"))

(defun aaph-indent-line ()
  "Indent current line of ML code."
  (interactive)
  (let ((indent (aaph-calculate-indentation)))
    (if (/= (current-indentation) indent)
        (save-excursion                 ;; Added 890601 (point now stays)
          (let ((beg (progn (beginning-of-line) (point))))
            (skip-chars-forward "\t ")
            (delete-region beg (point))
            (indent-to indent))))
    ;; If point is before indentation, move point to indentation
    (if (< (current-column) (current-indentation))
        (skip-chars-forward "\t "))))

(defun aaph-back-to-outer-indent ()
  "Unindents to the next outer level of indentation."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward "\t ")
    (let ((start-column (current-column))
          (indent (current-column)))
      (if (> start-column 0)
          (progn
            (save-excursion
              (while (>= indent start-column)
                (if (re-search-backward "^[^\n]" nil t)
                    (setq indent (current-indentation))
                  (setq indent 0))))
            (backward-delete-char-untabify (- start-column indent)))))))


(defconst aaph-indent-starters-reg
  "and\\b\\|case\\b\\|datatype\\b\
\\|else\\b\\|fun\\b\\|do\\b\\|import\\b\
\\|struct\\b\\|type\\b\\|open\\b\\|val\\b\
\\|in\\b\\|infix\\b\\|infixr\\b\\|let\\(cc\\)?\\b\\|if\\b\\|then\\b\\|local\\b\
\\|nonfix\\b\\|of\\b\\|open\\b\\|raise\\b\\|sig\\b\
\\|while\\b\\|with\\b\\|withtype\\b"
  "The indentation starters. The next line will be indented.")

;; ditto abstraction
(defconst aaph-starters-reg
  "\\bdatatype\\b\\|\\bdo\\b\\|\\bimport\\b\
\\|\\bexception\\b\\|\\bfun\\b\\|\\bfunctor\\b\\|\\blocal\\b\
\\|\\binfix\\b\\|\\binfixr\\b\
\\|\\bnonfix\\b\\|\\bsignature\\b\\|\\bstructure\\b\
\\|\\btype\\b\\|\\bopen\\b\\|\\bval\\b\\|\\bwith\\b"
  "The starters of new expressions.")

(defconst aaph-end-starters-reg
  "\\blet\\(cc\\)?\\b\\|\\blocal\\b\\|\\bsig\\b\\|\\bstruct\\b\\|\\bwith\\b"
  "Matching reg-expression for the \"end\" keyword.")

(defconst aaph-starters-indent-after
  "let\\(cc\\)?\\b\\|local\\b\\|struct\\b\\|in\\b\\|sig\\b\\|with\\b"
  "Indent after these.")


;; by tom7.
(defun aaph-insert-comment ()
  "Insert (*  *) and put the point inside.

If `transient-mark-mode' is on, and the mark is active,
then comment out the highlighted region instead. "
  (interactive "*")
  (if (and transient-mark-mode mark-active)
      (save-excursion
        (let* ((rbeg (region-beginning))
               (rend (region-end)))
          (goto-char rbeg)
          (insert "(* ")
          (goto-char (+ 3 rend))
          (insert " *)")
          ;; maybe only if font-lock mode is on? I dunno.
          (font-lock-fontify-region rbeg rend)))
    (progn
      (insert "(*  *)")
      (forward-char -3))))

(defun aaph-calculate-indentation ()
  (save-excursion
    (let ((case-fold-search nil))
      (beginning-of-line)
      (if (bobp)                        ; Beginning of buffer
          0                             ; Indentation = 0
        (skip-chars-forward "\t ")
        (cond
         ;; Indentation for comments alone on a line, matches the
         ;; proper indentation of the next line. Search only for the
         ;; next "*)", not for the matching.
         ((looking-at "(\\*")
          (if (not (search-forward "*)" nil t))
              (error "Comment not ended."))
          (end-of-line)
          (skip-chars-forward "\n\t ")
          ;; If we are at eob, just indent 0
          (if (eobp) 0 (aaph-calculate-indentation)))

         ;; In a block comment? -tom7
         ((aaph-inside-comment-or-string-p)
          (aaph-indent-same))

         ;; Continued string ? (Added 890113 lbn)
         ((looking-at "\\\\")
          (save-excursion
            (if (save-excursion (previous-line 1)
                                (beginning-of-line)
                                (looking-at "[\t ]*\\\\"))
                (progn (previous-line 1) (current-indentation))
            (if (re-search-backward "[^\\\\]\"" nil t)
                (1+ (current-indentation))
              0))))
         ;; XXX tom7: this is dumb when there is no expression following =>. 
         ;;           Can I do better?
         ;; Are we looking at a case expression ?
         ((looking-at "|.*=>")

          ;; XXX this is the culprit, it seems.
          ;; what I really want to do is skip over any parenthesized expressions
          ;; (possibly zero) until I get to a =>. Only parenthesized expressions
          ;; can have => within them .. uh, maybe let..in..end can too, hmm.

          (aaph-skip-block)
          (aaph-re-search-backward "=>")
          ;; Dont get fooled by fn _ => in case statements (890726)
          ;; Changed the regexp a bit, so fn has to be first on line,
          ;; in order to let the loop continue (Used to be ".*\bfn....")
          ;; (900430).
          (let ((loop t))
            (while (and loop (save-excursion
                               (beginning-of-line)
                               (looking-at "[^ \t]+\\bfn\\b.*=>")))
              (setq loop (aaph-re-search-backward "=>"))))
          (beginning-of-line)
          (skip-chars-forward "\t ")
          (cond
           ((looking-at "|") (current-indentation))
           ((and aaph-case-indent (looking-at "of\\b"))
            (1+ (current-indentation)))
           ((looking-at "fn\\b") (1+ (current-indentation)))
           ((looking-at "handle\\b") (+ (current-indentation) 5))
           (t (+ (current-indentation) aaph-pipe-indent))))

         ((looking-at "and\\b")
          (if (or (aaph-find-matching-starter aaph-starters-reg)
                  ;; (aaph-inside-comment-or-string-p)
                  )
              (current-column)
            0))

         ((looking-at "in\\b")          ; Match the beginning let/local
          (aaph-find-match-indent "in" "\\bin\\b" "\\blocal\\b\\|\\blet\\(cc\\)?\\b"))

         ((looking-at "end\\b")         ; Match the beginning
          (aaph-find-match-indent "end" "\\bend\\b" aaph-end-starters-reg))

         ((and aaph-nested-if-indent (looking-at "else[\t ]*if\\b"))
          (aaph-re-search-backward "\\bif\\b\\|\\belse\\b")
          (current-indentation))

         ((looking-at "else\\b")        ; Match the if
          (aaph-find-match-indent "else" "\\belse\\b" "\\bif\\b" t))

         ((looking-at "then\\b")        ; Match the if + extra indentation
                                        ; tom7 removed the extra indentation!
          (aaph-find-match-indent "then" "\\bthen\\b" "\\bif\\b" t))

         ((and aaph-case-indent (looking-at "of\\b"))
          (aaph-re-search-backward "\\bcase\\b")
          (+ (current-column) 2))

         ((looking-at aaph-starters-reg)
          (let ((start (point)))
            (aaph-backward-sexp)
            (if (and (looking-at aaph-starters-indent-after)
                     (/= start (point)))
                (+ (if aaph-type-of-indent
                       (current-column)
                     (if (progn (beginning-of-line)
                                (skip-chars-forward "\t ")
                                (looking-at "|"))
                         (- (current-indentation) aaph-pipe-indent)
                       (current-indentation)))
                   aaph-indent-level)
              (beginning-of-line)
              (skip-chars-forward "\t ")
              (if (and (looking-at aaph-starters-indent-after)
                       (/= start (point)))
                  (+ (if aaph-type-of-indent
                         (current-column)
                       (current-indentation))
                     aaph-indent-level)
                (goto-char start)
                (if (aaph-find-matching-starter aaph-starters-reg)
                    (current-column)
                  0)))))
         (t
          (let ((indent (aaph-get-indent)))
            (cond
             ((looking-at "|")
              ;; Lets see if it is the follower of a function definition
              (if (aaph-find-matching-starter
                   "\\bfun\\b\\|\\bfn\\b\\|\\band\\b\\|\\bhandle\\b")
                  (cond
                   ((looking-at "fun\\b") (- (current-column) aaph-pipe-indent))
                   ((looking-at "fn\\b") (1+ (current-column)))
                   ((looking-at "and\\b") (1+ (1+ (current-column))))
                   ((looking-at "handle\\b") (+ (current-column) 5)))
                (+ indent aaph-pipe-indent)))
             (t
              (if aaph-paren-lookback    ; Look for open parenthesis ?
                  (max indent (aaph-get-paren-indent))
                indent))))))))))

;; special hacked version of get-indent that ignores keywords,
;; used for indenting within a comment. Could use some major
;; simplification. -tom7
(defun aaph-indent-same ()
  (save-excursion
    (let ((case-fold-search nil))
      (beginning-of-line)
      (skip-chars-backward "\t\n ")
      (while (/= (current-column) (current-indentation))
        (aaph-backward-sexp))
      (skip-chars-forward "\t |")
      (let ((indent (current-column)))
        (skip-chars-forward "\t (")
        (cond
         ;; tom7 added this, for his personal comment indentation pref.
         ;; (on 011207)
         ((looking-at "\\* ")
          (+ (current-column) 2))
         ;; else keep the same indentation as previous line
         (t indent))))))

(defun aaph-get-indent ()
  (save-excursion
    (let ((case-fold-search nil))
      (beginning-of-line)
      (skip-chars-backward "\t\n; ")
      (if (looking-at ";") (aaph-backward-sexp))
      (cond
       ((save-excursion (aaph-backward-sexp) (looking-at "end\\b"))
        (- (current-indentation) aaph-indent-level))
       (t
        (while (/= (current-column) (current-indentation))
          (aaph-backward-sexp))
        (skip-chars-forward "\t |")
        (let ((indent (current-column)))
          (skip-chars-forward "\t (")
          (cond
           ;; tom7 added this, for his personal comment indentation pref.
           ;; (on 011207)
           ;; XXX - this is probably dead code now because of aaph-indent-same
           ((looking-at "\\* ")
            (+ (current-column) 2))
           ;; Started val/fun/structure...
           
           ;; tom 7 added this; if indent is skewed otherwise (29 Apr 2003)
           ((looking-at "if")
            (+ (current-column) 3))

           ((looking-at aaph-indent-starters-reg)
            (+ (current-column) aaph-indent-level))
           ;; Indent after "=>" pattern, but only if its not an fn _ =>
           ;; (890726)
           ((looking-at ".*=>")
            (if (looking-at ".*\\bfn\\b.*=>")
                indent
              (+ indent aaph-indent-level)))
           ;; else keep the same indentation as previous line
           (t indent))))))))


;; tom7 changed this so that { (with following space)
;; induces two spaces, as in:
;; type t = { openness : bool,
;;            free : var list }
;; The way I do this is pretty nasty, but oh well.
(defun aaph-get-paren-indent ()
  (save-excursion
    (let ((levelpar 0)                  ; Level of "()"
          (levelcurl 0)                 ; Level of "{}"
          (levelsqr 0)                  ; Level of "[]"
          (ilevel 0)                    ; 1 or 2? -- tom7
          (backpoint (max (- (point) aaph-paren-lookback) (point-min))))
      (catch 'loop
        (while (and (/= levelpar 1) (/= levelsqr 1) (/= levelcurl 1))
          (if (re-search-backward "[][{}()]" backpoint t)
              (if (not (aaph-inside-comment-or-string-p))
                  (cond
                   ((looking-at "(") (progn (setq levelpar (1+ levelpar)) (setq ilevel 1)))
                   ((looking-at ")") (setq levelpar (1- levelpar)))
                   ((looking-at "\\[") (progn (setq levelsqr (1+ levelsqr)) (setq ilevel 1)))
                   ((looking-at "\\]") (setq levelsqr (1- levelsqr)))
                   ((looking-at "{") (progn 
                                       (setq levelcurl (1+ levelcurl)) 
                                       (setq ilevel (save-excursion
                                                     (forward-char 1)
                                                     (if (looking-at " ") 2 1)))))
                   ((looking-at "}") (setq levelcurl (1- levelcurl)))))
            (throw 'loop 0)))           ; Exit with value 0
        (if (save-excursion
              (forward-char 1)
              (looking-at aaph-indent-starters-reg))
            (+ ilevel (current-column) aaph-indent-level)
          (+ ilevel (current-column)))))))

(defun aaph-inside-comment-or-string-p ()
  (let ((start (point)))
    (if (save-excursion
          (condition-case ()
              (progn
                (search-backward "(*")
                (search-forward "*)")
                (forward-char -1)       ; A "*)" is not inside the comment
                (> (point) start))
            (error nil)))
        t
      (let ((numb 0))
        (save-excursion
          (save-restriction
            (narrow-to-region (progn (beginning-of-line) (point)) start)
            (condition-case ()
                (while t
                  (search-forward "\"")
                  (setq numb (1+ numb)))
              (error (if (and (not (zerop numb))
                              (not (zerop (% numb 2))))
                         t nil)))))))))

;; - better than the default M-q, but could be improved...
;;    -- tom7, sep 2002
(defun aaph-fill-comment ()
  "Fill a paragraph comment like fill-paragraph."
  (interactive)
  (cond ((aaph-inside-comment-or-string-p)
         (save-excursion
           (save-restriction
             (let* ((pp  (point))
                    (beg (search-backward "(*"))
                    (end (search-forward "*)")))
               (narrow-to-region beg end)
               (goto-char pp)
               (fill-paragraph nil)))))

        (t (error "Can only fill inside a comment block."))))

(defun aaph-skip-block ()
  (let ((case-fold-search nil))
    (aaph-backward-sexp)
    (if (looking-at "end\\b")
        (progn
          (goto-char (aaph-find-match-backward "end" "\\bend\\b"
                                              aaph-end-starters-reg))
          (skip-chars-backward "\n\t "))
      ;; Here we will need to skip backward past if-then-else
      ;; and case-of expression. Please - tell me how !!
      )))

(defun aaph-find-match-backward (unquoted-this this match &optional start)
  (save-excursion
    (let ((case-fold-search nil)
          (level 1)
          (pattern (concat this "\\|" match)))
      (if start (goto-char start))
      (while (not (zerop level))
        (if (aaph-re-search-backward pattern)
            (setq level (cond
                         ((looking-at this) (1+ level))
                         ((looking-at match) (1- level))))
          ;; The right match couldn't be found
          (error (concat "Unbalanced: " unquoted-this))))
      (point))))

(defun aaph-find-match-indent (unquoted-this this match &optional indented)
  (save-excursion
    (goto-char (aaph-find-match-backward unquoted-this this match))
    (if (or aaph-type-of-indent indented)
        (current-column)
      (if (progn
            (beginning-of-line)
            (skip-chars-forward "\t ")
            (looking-at "|"))
          (- (current-indentation) aaph-pipe-indent)
        (current-indentation)))))

(defun aaph-find-matching-starter (regexp)
  (let ((case-fold-search nil)
        (start-let-point (aaph-point-inside-let-etc))
        (start-up-list (aaph-up-list))
        (found t))
    (if (aaph-re-search-backward regexp)
        (progn
          (condition-case ()
              (while (or (/= start-up-list (aaph-up-list))
                         (/= start-let-point (aaph-point-inside-let-etc)))
                (re-search-backward regexp))
            (error (setq found nil)))
          found)
      nil)))

(defun aaph-point-inside-let-etc ()
  (let ((case-fold-search nil) (last nil) (loop t) (found t) (start (point)))
    (save-excursion
      (while loop
        (condition-case ()
            (progn
              (re-search-forward "\\bend\\b")
              (while (aaph-inside-comment-or-string-p)
                (re-search-forward "\\bend\\b"))
              (forward-char -3)
              (setq last (aaph-find-match-backward "end" "\\bend\\b"
                                                  aaph-end-starters-reg last))
              (if (< last start)
                  (setq loop nil)
                (forward-char 3)))
          (error (progn (setq found nil) (setq loop nil)))))
      (if found
          last
        0))))

(defun aaph-re-search-backward (regexpr)
  (let ((case-fold-search nil) (found t))
    (if (re-search-backward regexpr nil t)
        (progn
          (condition-case ()
              (while (aaph-inside-comment-or-string-p)
                (re-search-backward regexpr))
            (error (setq found nil)))
          found)
      nil)))

(defun aaph-up-list ()
  (save-excursion
    (condition-case ()
        (progn
          (up-list 1)
          (point))
      (error 0))))

(defun aaph-backward-sexp ()
  (condition-case ()
      (progn
        (let ((start (point)))
          (backward-sexp 1)
          (while (and (/= start (point)) (looking-at "(\\*"))
            (setq start (point))
            (backward-sexp 1))))
    (error (forward-char -1))))

(defun aaph-comment-indent ()
  (if (looking-at "^(\\*")              ; Existing comment at beginning
      0                                 ; of line stays there.
    (save-excursion
      (skip-chars-backward " \t")
      (max (1+ (current-column))        ; Else indent at comment column
           comment-column))))           ; except leave at least one space.

(font-lock-add-keywords 'aaph-mode '(
(
;; regexp for all aphasia 2 keywords:
"\\<\\(if\\|then\\|else\\|do\\|fun\\|and\\(also\\|then\\)?\\|or\\(else\\)?\\|otherwise\\|op\\(en\\)?\\|val\\|fn\\|let\\|in\\|end\\|case\\|of\\|sig\\(nature\\)?\\|raise\\|type\\|data\\(type\\|base\\)\\|exception\\|nonfix\\|local\\|handle1?\\|as\\|infixr?\\|abstype\\|import\\|select\\|from\\|delete\\|insert\\|into\\|[sg]et\\|where\\|\\(distinct\\)\\|\\(order +by\\)\\|limit\\)\\>" 
. font-lock-keyword-face)
(
;; regexp for aaph constants -- adapted from sml, should be trimmed
"\\<\\(nil\\|true\\|false\\|0[wWxX]+[0-9A-Fa-f]+\\|~?[0-9]+\\.[0-9]+\\|~?[0-9]+\\)\\>"
. font-lock-constant-face
)
;; for the type part of a datat/with/eq type decl.
("\\<\\(data\\)?type *\\( \\|[A-Za-z'_]*\\|( *\\([A-Za-z'_]* *,? *\\)+)\\) *\\([A-Za-z][A-Za-z0-9_']*\\)"
4 font-lock-type-face)

;; punctuation should be subtle 
("\\(\\]\\|\\[\\|[();=`<>|{}^#.,:]\\)" . tom7-subtle-text-face)

;; semicolon or period before end or closeparen
("\\([.;]\\)[ \t\n\m]*end\\>" 1 font-lock-warning-face prepend)

;; typos I make from too much sml/c on the brain
("\\<include\\>" . font-lock-warning-face)

;; ConStructors SIGNATURENAMES and StructureNames
("\\<\\([A-Z][A-Za-z0-9'_]+\\)\\>" . font-lock-variable-name-face)

("[?]\\(.\\)" 1 font-lock-string-face)

;; either bracket followed by stuff that isn't brackets, followed
;; by either bracket: color as a string.
;("[\\[\\]]\\([^\\[\\]]*\\)[\\[\\]]" 1 font-lock-warning-face prepend)
("[][]\\([^][]*\\)[][]" 1 font-lock-string-face prepend)

(
;; regexp for aphasia types (just builtin):
"\\<\\(unit\\|int\\|bool\\|float\\|ref\\|char\\|string\\|list\\|option\\|key\\|blob\\)\\>"
. font-lock-type-face)

))

;; always have font-lock turned on
(add-hook 'aaph-mode-hook 'turn-on-font-lock)


;;; & do the user's customisation

(add-hook 'aaph-load-hook 'aaph-mode-version t)

(run-hooks 'aaph-load-hook)

;;; aaph-mode.el has just finished.
