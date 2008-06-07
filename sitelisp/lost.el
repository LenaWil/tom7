;;; lost.el --- every 108 minutes the button must be pressed

; (load "c:\\code\\sitelisp\\lost.el")
; (autoload 'lost-mode "lost.el" "Lost mode" t)

;;; Author: Tom Murphy 7
;;; Based on type-break.el by Noah Friedman, GPL

;;; Licensed under the GNU GPL version 2 or later.
;;; (See the file COPYING for details.)

;; (sit-for 2)

;; a periodic (once per second?) timer should:
;;; - update the modeline with the current timeout.
;;; - if the timeout is less than 4 minutes:
;;;    - insist that the buffer *swan* exists
;;;     - (if it doesn't, make it with a prompt)
;;;    - insist that it is displayed
;;;    - if it has the correct numbers entered, then
;;;      erase it and reset the count
;;; - beep every few seconds with increasing annoyance

;; (blink-cursor-mode 0)
;; (setq lost-seconds 1)

(defun nth (n l)
  (cond ((= n 0) (car l))
        (t (nth (1- n) (cdr l)))))

(defvar lost-seconds (* 60 108))
(defvar lost-dangertime (* 60 4))

(defun lost-insist-swan-settings ()
  (interactive)
  (local-set-key [13] 'lost-execute)
  (let* ((cu (assq 'cursor-color (frame-parameters)))
	 (bg (assq 'background-color (frame-parameters)))
	 (fg (assq 'foreground-color (frame-parameters))))
    (if (not (and bg fg (string= (cdr bg) "black") (string= (cdr fg) "green")))
	(progn
	  ; (insert (cdr bg))
	  ; (insert (cdr fg))
	  ; (insert "YESSS")
	  (setq lost-old-background (cdr bg))
	  (setq lost-old-foreground (cdr fg))
	  (setq lost-old-cursor (cdr cu))
	  ;; if blinking, then blink-cursor-idle-timer will be set
	  ;; (this is sort of a hack, but emacs does not seem to supply
	  ;;  a first-class way of getting this information.)
	  (setq lost-old-blink (cond (blink-cursor-idle-timer 1) (t 0)))
	  (blink-cursor-mode 1)
	  (set-background-color "black")
	  (set-foreground-color "green")
	  ;(custom-set-faces '(cursor ((t (:background "green" :foreground "black")))))
	  (set-cursor-color "green")

	  ))))


;; assumes they were changed by lost-insist-swan-settings
(defun lost-restore-settings ()
  ;; don't need to reset enter key because it's killed with swan buffer
  (set-foreground-color lost-old-foreground)
  (set-background-color lost-old-background)
  (set-cursor-color lost-old-cursor)
  ;; XXX restore blink state of cursor
  (blink-cursor-mode lost-old-blink)
; (assq 'background-color (frame-parameters))
)

; Used for animation loops faster than 1 second
(defvar lost-fast-timer nil)
; Run reset loop this many times
(defvar lost-resetting-n 0)

(defun lost-rand-min ()
  (propertize (format "%d" (random 9)) 'face 'lost-min-face)
)

(defun lost-rand-sec ()
  (propertize (format "%d" (random 9)) 'face 'lost-sec-face)
)

(defun lost-rand-display ()
  (list (lost-rand-min) (lost-rand-min) (lost-rand-min)
	" "
	(lost-rand-sec) (lost-rand-sec)))

; given two lists of equal length, take the first n of a
; followed by the remainder from b.
(defun lost-tween (n a b)
  (cond ((= n 0) b)
	(t (cons (car a) (lost-tween (1- n) (cdr a) (cdr b))))))

; (lost-tween 3 (list "A" "B" "C" "D") (list "X" "Y" "Z" "W"))

(defun lost-start-timer ()
  (setq lost-slow-timer (run-at-time 0 1 'lost-periodic)))

;; in ticks
(defvar lost-reset-time-per-digit 3)
;; Timer-reset animation. There are two distinct phases.
;; In the first phase, we keep the current display and
;; fill the digits up from left to right with random flipping.
;; In the second phase, we reset the timer to 108 minutes, and
;; then replace flipping digits with new stable reset digits.
(defun lost-resetting-timer ()
  ; increment first.
  (setq lost-resetting-n (+ lost-resetting-n 1))
  (cond 
   ((= lost-resetting-n (* 2 6 lost-reset-time-per-digit))
    (cancel-timer lost-fast-timer)
    (lost-start-timer)
    )
   ;; phase 1
   ((< lost-resetting-n (* 6 lost-reset-time-per-digit))
    (let ((a (lost-cur-display))
	  (b (lost-rand-display)))
      (setq lost-mode-string
	    (lost-tween (/ lost-resetting-n lost-reset-time-per-digit) b a)))
    (force-mode-line-update))

   ((= lost-resetting-n (* 6 lost-reset-time-per-digit))
    (setq lost-seconds (* 60 108)))

   ((> lost-resetting-n (* 6 lost-reset-time-per-digit))
    (let ((a (lost-cur-display))
	  (b (lost-rand-display)))
      (setq lost-mode-string
	    (lost-tween (/ (- lost-resetting-n (* 6 lost-reset-time-per-digit))
			   lost-reset-time-per-digit) a b)))
    (force-mode-line-update))
))

(defun lost-execute ()
  (interactive "")
  (let ((numbers-ok (save-excursion
		      (goto-char (point-min))
		      (looking-at ">: 4 8 15 16 23 42"))))
    (cond (numbers-ok
	   (lost-restore-settings)
	   ;; should animate this?
	   (kill-buffer "*swan*")

	   (and lost-fast-timer (cancel-timer lost-fast-timer))
	   (setq lost-resetting-n 0)
	   (setq lost-fast-timer (run-at-time 0 0.05 'lost-resetting-timer))
	   (cancel-timer lost-slow-timer)
	   (message "Every 108 minutes the button must be pressed.")
	   )
	  (t (message "??")
	     (lost-make-prompt)))
    ))

(defun lost-twodig (n)
  (cond ((< n 10) (format "0%d" n))
	(t (format "%d" n))))

(defun lost-threedig (n)
  (cond ((< n 100) (format "0%s" (lost-twodig n)))
	(t (format "%d" n))))

; during good times
(make-empty-face 'lost-min-face)
(make-empty-face 'lost-sec-face)

; for hieroglyphics
(make-empty-face 'lost-hmin-face)
(make-empty-face 'lost-hsec-face)

(defvar lost-hieroglyphics (string 2209 2210 2211 2212 2246 2247 2245 2271 2229 2225))

(defvar lost-h-a "?")
(defvar lost-h-b "?")
(defvar lost-h-c "?")
(defvar lost-h-d "?")
(defvar lost-h-e "?")

(defun lost-hieroglyph ()
  (aref lost-hieroglyphics (random (length lost-hieroglyphics))))
(defun lost-hieroglyphics-freakout ()
  (setq lost-h-a (string (lost-hieroglyph)))
  (setq lost-h-b (string (lost-hieroglyph)))
  (setq lost-h-c (string (lost-hieroglyph)))
  (setq lost-h-d (string (lost-hieroglyph)))
  (setq lost-h-e (string (lost-hieroglyph))))

; (lost-hieroglyphics-freakout)
; don't even allow customization of the faces..
(set-face-foreground 'lost-min-face "#FFFFFF")
(set-face-background 'lost-min-face "#000000")
(set-face-foreground 'lost-sec-face "#000000")
(set-face-background 'lost-sec-face "#FFFFFF")
(set-face-attribute 'lost-min-face nil :strike-through "#444455")
(set-face-attribute 'lost-sec-face nil :strike-through "#444455")

(set-face-foreground 'lost-hmin-face "#FF0000")
(set-face-background 'lost-hmin-face "#000000")
(set-face-foreground 'lost-hsec-face "#000000")
(set-face-background 'lost-hsec-face "#FF0000")
(set-face-attribute 'lost-min-face nil :strike-through "#554444")
(set-face-attribute 'lost-sec-face nil :strike-through "#554444")


;; return a list of six propertized strings, one for
;; each of the five flippy characters and the separator.
(defun lost-cur-display ()
  (cond ((< lost-seconds 0)
	 (lost-hieroglyphics-freakout)
	 (list
	  ;; good if I could get actual hieroglyphs,
	  ;; maybe blinking?
	     (propertize lost-h-a 'face 'lost-hmin-face)
	     (propertize lost-h-b 'face 'lost-hmin-face)
	     (propertize lost-h-c 'face 'lost-hmin-face)
	     " "
	     (propertize lost-h-d 'face 'lost-hsec-face)
	     (propertize lost-h-e 'face 'lost-hsec-face)))
	
	  (t
	   (let* ((mm (/ lost-seconds 60))
		  (ss (mod lost-seconds 60)))

	     (list
	      (propertize (format "%d" (/ mm 100)) 'face 'lost-min-face)
	      (propertize (format "%d" (mod (/ mm 10) 10)) 'face 'lost-min-face)
	      (propertize (format "%d" (mod mm 10)) 'face 'lost-min-face)
	      " "
	      (propertize (format "%d" (/ ss 10)) 'face 'lost-sec-face)
	      (propertize (format "%d" (mod ss 10)) 'face 'lost-sec-face))
	     ))))


(defun lost-periodic ()
  ; always go there
  (setq lost-seconds (- lost-seconds 1))

  ; always update modeline clock
  (let ((ms (lost-cur-display)))
    (setq lost-mode-string (concat (nth 0 ms) (nth 1 ms) (nth 2 ms)
				   (nth 3 ms) (nth 4 ms) (nth 5 ms)
				   )))
  (force-mode-line-update)

  (cond

   ; allow input
   ((< lost-seconds lost-dangertime)
    
    ; (beep 'no-terminate-macro)
    (switch-to-buffer "*swan*")
    ;; should prevent this from happening if it's already done; flickers.
    (lost-insist-swan-settings)
    ;; does the buffer start with the prompt?
    (let ((prompt-ok
	   (save-excursion
	     (goto-char (point-min))
	     (looking-at ">: ")
	     )))
      (cond ((not prompt-ok)
	     (lost-make-prompt)))
      ))) ; entry mode
)

(defun lost-make-prompt ()
  (erase-buffer)
  (insert ">: ")
  (goto-char (point-max)))

(setq lost-mode-string "LOST")
;; Properties are ignored in emacs 22+ unless variable is risky.
(put 'lost-mode-string 'risky-local-variable t)

;; from timeclock. find the global-mode-string symbol in the
;; modeline format. 
(defun lost-set-modeline ()
  ;; global-mode string has to start with a list or string
  ;; if the contents are to be evaluated and treated as mode
  ;; line formats.
  (or global-mode-string (setq global-mode-string '("")))
;  (let ((list-entry (memq 'global-mode-string
;			  mode-line-format)))
;    (unless (or (null list-entry)
;		(memq 'lost-mode-string mode-line-format))
;      (setcdr list-entry
;	      (cons 'lost-mode-string
;		    (cdr list-entry))))
;    )
  ;; have to put this at the end, or else it's interpreted
  ;; as a condition.
  (setq global-mode-string
	(append global-mode-string '(lost-mode-string)))
  (force-mode-line-update)
  )

(lost-set-modeline)

; (setq mode-line-format (cons (propertize "awesome" 'face 'lost-hhour-face) mode-line-format))
; (setq mode-line-format 'awesome)
; (setq awesome (propertize "awesome" 'face 'lost-hhour-face))
; (put 'awesome 'risky-local-variable t)


; (setq lost-set-modeline (lambda ()))
; (setq lost-periodic (lambda ()))

; (assq 'global-mode-string mode-line-format)
; (memq 'global-mode-string mode-line-modes)

; (mapcar (lambda (x) (progn
; 		      (insert " ")
; 		      (cond ((stringp x) (insert x))
; 			  ((symbolp x) (insert (symbol-name x)))
; 			  (t (insert "?"))))) mode-line-format)
; 
; (setq global-mode-string "awesome")

; symbol

; mode-line-format

; (goto-char (point-min))
; (insert ">: ")
; (looking-at ">: ")
; (lost-periodic)

; (setq lost-seconds (* 60 108))
; (setq lost-seconds (* 60 5))
; (setq lost-seconds 5)

;;;;
(lost-start-timer)

;; emacs-version

;; 
;; 
;; 
;; 
;; (defgroup lost nil
;;   "Every 108 minutes the button must be pressed."
;;   :prefix "lost"
;;   :group 'keyboard)
;; 
;; ;;;###autoload
;; (defcustom lost-mode nil
;;   "Toggle lost-mode."
;;   :set (lambda (symbol value)
;; 	 (type-break-mode (if value 1 -1)))
;;   :initialize 'custom-initialize-default
;;   :type 'boolean
;;   :group 'type-break
;;   :require 'type-break)
;; 
;; ;;;###autoload
;; (defvar lost-interval (* 60 108))
;; 
;; ;; XXX uhhh...?
;; (defvar lost-post-command-hook '(lost-check)
;;   "Hook run indirectly by post-command-hook for typing break functions.
;; This is not really intended to be set by the user, but it's probably
;; harmless to do so.  Mainly it is used by various parts of the typing break
;; program to delay actions until after the user has completed some command.
;; It exists because `post-command-hook' itself is inaccessible while its
;; functions are being run, and some type-break--related functions want to
;; remove themselves after running.")
;; 
;; (provide 'type-break)
;; 
;; (if type-break-mode
;;     (type-break-mode 1))
;; 
;; ;;; type-break.el ends here
