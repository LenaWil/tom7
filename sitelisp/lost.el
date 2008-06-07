;;; lost.el --- every 108 minutes the button must be pressed
;;;
;;; Author: Tom Murphy 7  (http://tom7.org/)
;;; Some tricks from type-break.el by Noah Friedman, GPL
;;;              and timeclock.el  by John Wiegley, GPL
;;;
;;; Licensed under the GNU GPL version 2 or later.
;;; (See the file COPYING for details.)
;;;
;;; To employ this useful mode, simply add:
;;;  
;;;   (load "c:\\code\\sitelisp\\lost.el")
;;;   (setq lost-no-beep nil)  ; optional, if you want beeping
;;;   
;;; or the equivalent for your platform to your .emacs file.
;;; The mode is activated on startup and cannot be disabled.

(defun nth (n l)
  (cond ((= n 0) (car l))
        (t (nth (1- n) (cdr l)))))

(defvar lost-seconds (* 60 108))
(defvar lost-dangertime (* 60 4))
(defvar lost-no-beep t)

(defun lost-insist-swan-settings ()
  (interactive)
  (local-set-key [13] 'lost-execute)
  (let* ((cu (assq 'cursor-color (frame-parameters)))
	 (bg (assq 'background-color (frame-parameters)))
	 (fg (assq 'foreground-color (frame-parameters))))
    (if (not (and bg fg (string= (cdr bg) "black") (string= (cdr fg) "green")))
	(progn
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
	  (set-cursor-color "green")
	  ))))

;; assumes they were changed and saved by lost-insist-swan-settings
(defun lost-restore-settings ()
  ;; don't need to reset enter key because it's killed with swan buffer
  (set-foreground-color lost-old-foreground)
  (set-background-color lost-old-background)
  (set-cursor-color lost-old-cursor)
  (blink-cursor-mode lost-old-blink)
)

; Used for animation loops faster than 1 second
(defvar lost-fast-timer nil)
; Run reset loop this many times
(defvar lost-resetting-n 0)

(defun lost-rand-min ()
  (propertize (format "%d" (random 9)) 'face 'lost-min-face))

(defun lost-rand-sec ()
  (propertize (format "%d" (random 9)) 'face 'lost-sec-face))

(defun lost-rand-display ()
  (list (lost-rand-min) (lost-rand-min) (lost-rand-min) " "
	(lost-rand-sec) (lost-rand-sec)))

; given two lists of equal length, take the first n of a
; followed by the remainder from b.
(defun lost-tween (n a b)
  (cond ((= n 0) b)
	(t (cons (car a) (lost-tween (1- n) (cdr a) (cdr b))))))

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

   ;; phase change
   ((= lost-resetting-n (* 6 lost-reset-time-per-digit))
    (setq lost-seconds (* 60 108)))

   ;; phase 2
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
	   (setq lost-system-failure "")
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

(set-face-foreground 'lost-min-face "#FFFFFF")
(set-face-background 'lost-min-face "#000000")
(set-face-foreground 'lost-sec-face "#000000")
(set-face-background 'lost-sec-face "#FFFFFF")
(set-face-attribute  'lost-min-face nil :strike-through "#444455")
(set-face-attribute  'lost-sec-face nil :strike-through "#444455")

(set-face-foreground 'lost-hmin-face "#FF0000")
(set-face-background 'lost-hmin-face "#000000")
(set-face-foreground 'lost-hsec-face "#000000")
(set-face-background 'lost-hsec-face "#FF0000")
(set-face-attribute  'lost-hmin-face nil :strike-through "#554444")
(set-face-attribute  'lost-hsec-face nil :strike-through "#554444")


(defvar lost-system-failure "")
;; return a list of six propertized strings, one for
;; each of the five flippy characters and the separator.
(defun lost-cur-display ()
  (cond ((< lost-seconds 0)
	 (lost-hieroglyphics-freakout)
	 ;; system doesn't fail for another 10 seconds after hitting 0

	 (list
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

(defvar lost-mod14-n 0)
(defun lost-mod14 ()
  (setq lost-mod14-n (mod (1+ lost-mod14-n) 14))
  lost-mod14-n)

(defun lost-periodic ()
  ; always go there
  (setq lost-seconds (- lost-seconds 1))

  ; always update modeline clock
  (let ((ms (lost-cur-display)))
    (setq lost-mode-string (concat (nth 0 ms) (nth 1 ms) (nth 2 ms)
				   (nth 3 ms) (nth 4 ms) (nth 5 ms)
				   )))
  (force-mode-line-update)

  ;; speed up in hieroglyphics mode. we don't see the seconds
  ;; anyway.
  (and (= lost-seconds 0)
       (progn (cancel-timer lost-slow-timer)
	      (setq lost-slow-timer (run-at-time 0 .2 'lost-periodic))))

  (cond
   ; allow input after 4 minute mark
   ((< lost-seconds lost-dangertime)

    ;; Beeping is supposed to increase in severity at the 1 minute
    ;; mark, but emacs doesn't have an easy way to do this.
    (or lost-no-beep (beep 'no-terminate-macro))
    (switch-to-buffer "*swan*")
    (lost-insist-swan-settings)

    ;; When we're really dead...
    ;; (note timescale has increased by 5 at this point)
    (cond 
     ((and (<= lost-seconds (- 0 50)) (= 0 (mod (- 0 lost-seconds) 2)))
      ;; chop so as not to grow forever
      (and (> (length lost-system-failure) 900)
	   (setq lost-system-failure 
		 (substring lost-system-failure
			    (+ (lost-mod14) (- (length lost-system-failure) 900)) nil)))
      (setq lost-system-failure
	    ;; lack of separating spaces intentional
	    (concat lost-system-failure "System Failure"))
      (message lost-system-failure)))

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
;; Properties of strings in modeline are ignored in emacs 22+ 
;; unless the variable is risky.
(put 'lost-mode-string 'risky-local-variable t)

;; Sets lost-mode-string to appear in the modeline, using
;; global-mode-string. This seems volatile between emacs
;; versions; if you know a stable way, please tell me.
(defun lost-set-modeline ()
  ;; global-mode string has to start with a list or string
  ;; if the contents are to be evaluated and treated as mode
  ;; line formats.
  (or global-mode-string (setq global-mode-string '("")))
  (setq global-mode-string
	(append global-mode-string '(lost-mode-string)))
  (force-mode-line-update))

;; go
(lost-set-modeline)
(lost-start-timer)
