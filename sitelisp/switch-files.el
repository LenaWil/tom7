;; swich-files.el: a method of switching between matched pairs of
;; files and for following include directives.
;;
;; Copyright (C) 2002-2004  Wes Hardaker <elisp@hardakers.net>
;;
;; Modified by Tom 7, 19 Dec 2009.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; A copy of the GNU General Public License can be obtained from this
;; program's author (send electronic mail to psmith@BayNetworks.com) or
;; from the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA
;; 02139, USA.
;;
;; $Revision: 1.8 $

(defvar switch-files-paths '("." "/usr/include" "/usr/local/include")
  "the list of paths to look through for matching files.")

;; XXX there need to be multiple possible destinations for
;; certain suffixes, for example .h (.c, .cc, .cpp, etc.).
;; just return a list below.
(defvar switch-files-list '(
			    ("\\.cc" ".h")
			    ("\\.h" ".cc")

                            ("\\.c" ".h")
			    ("\\.h" ".c")

			    ("\\.C" ".H")
			    ("\\.H" ".C")

			    ("\\.cpp" ".h")
			    ("\\.h" ".cpp")

			    ("-sig\\.sml" ".sml")
			    ("\\.sml" "-sig.sml")

			    )
  "A list of file regexp matches and replacements switch between.")

(defvar switch-file-backto nil
  "A buffer local variable containing a buffer to jump back to for switch-file.")

(require 'cl)

(defun switch-files ()
  (interactive)
  (let* ((curbuffer (current-buffer))
	 (buffername (buffer-file-name))
	 (list switch-files-list)
	 (pathlist switch-files-paths)

	 ; the name of the file to go look for.  Used for (message)s only.
	 (startfile
	  (or
	   ; are we staring at an include directive.
	   (and
	    (looking-at
	     "#include [<\\\"]\\([^/>\\\"]*\\|.*/[^/>\\\"]*\\)[>\\\"]")
	    (buffer-substring (match-beginning 1) (match-end 1)))
	   ; are we in a buffer that we know where to go back to already?
	   switch-file-backto
	   ; can we guess at a file name from the current buffer name?
	   (let ((it
		  (assoc-if (function (lambda (key) 
					(message "regex %s" key)
					(string-match
					 (concat "\\(.*\\)" key)
					 buffername)))
		  switch-files-list)))
	     (if it
		 (file-name-nondirectory
		  (concat (substring buffername (match-beginning 1)
				     (match-end 1))
			  (cadr it)))))))
	 done thefile)
    
    (if (not startfile)
	(message "Can't switch. Buffer '%s' name '%s' startfile '%s'" 
		 curbuffer buffername startfile)
      (progn
	(if (bufferp startfile)
	    (switch-to-buffer startfile)
	  (setq done nil)
	  (while (and (not done) pathlist)
	    (setq thefile (expand-file-name startfile (car pathlist)))
	    (if (file-exists-p thefile)
		(setq done t)
	      (setq pathlist (cdr pathlist))))

	  (if done
	      (progn
		(find-file thefile)
		(make-local-variable 'switch-file-backto)
		(setq switch-file-backto curbuffer))
	    (message "Can't find file: %s" startfile)
	    ))))
    )
  )

(global-set-key "\C-x\M-f" 'switch-files)

; (switch-files)

(provide 'switch-files)
