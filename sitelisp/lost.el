;;; lost.el --- every 108 minutes the button must be pressed


;;; Author: Tom Murphy 7
;;; Based on type-break.el by Noah Friedman, GPL

;;; Licensed under the GNU GPL version 2 or later.
;;; (See the file COPYING for details.)

;; (sit-for 2)

;; a periodic (once a second?) timer should:
;;; - update the modeline with the current timeout.
;;; - if the timeout is less than 4 minutes:
;;;    - insist that the buffer *swan* exists
;;;     - (if it doesn't, make it with a prompt)
;;;    - insist that it is displayed
;;;    - if it has the correct numbers entered, then
;;;      erase it and reset the count
;;; - beep every few seconds with increasing annoyance

(defvar lost-seconds (* 60 108))
(defvar lost-dangertime (* 60 4))

(defun lost-insist-swan-settings ()
  (interactive)
  (blink-cursor-mode 1)
  (let* ((bg (assq 'background-color (frame-parameters)))
	 (fg (assq 'foreground-color (frame-parameters))))
    (if (not (and bg fg (string= (cdr bg) "black") (string= (cdr fg) "green")))
	(progn
	  (insert (cdr bg))
	  (insert (cdr fg))
	  (insert "YESSS")
	  (set-background-color "black")
	  (set-foreground-color "green")
	  (custom-set-faces '(cursor ((t (:background "green" :foreground "black")))))))))


; (assq 'background-color (frame-parameters))


(defun lost-twodig (n)
  (cond ((< n 10) (format "0%d" n))
	(t (format "%d" n))))

; during good times
(make-empty-face 'lost-hour-face)
(make-empty-face 'lost-minsec-face)

; for hieroglyphics
(make-empty-face 'lost-hhour-face)
(make-empty-face 'lost-hminsec-face)

; don't even allow customization of the faces..
(set-face-foreground 'lost-hour-face "#FFFFFF")
(set-face-background 'lost-hour-face "#000000")
(set-face-foreground 'lost-minsec-face "#000000")
(set-face-background 'lost-minsec-face "#FFFFFF")

(set-face-foreground 'lost-hhour-face "#FF0000")
(set-face-background 'lost-hhour-face "#000000")
(set-face-foreground 'lost-hminsec-face "#000000")
(set-face-background 'lost-hminsec-face "#FF0000")

(defun lost-periodic ()
  ; always go there
  (setq lost-seconds (- lost-seconds 1))

  ; always update modeline clock
  (let ((ms
	(cond ((< lost-seconds 0)
	       
	       (format "%s:%s:%s"
		   ;; good if I could get actual hieroglyphs,
		   ;; maybe blinking?
		   (propertize "?" 'face 'lost-hhour-face)
		   (propertize "??" 'face 'lost-hminsec-face)
		   (propertize "??" 'face 'lost-hminsec-face))
	       )

	      (t
	       (let* ((hh (/ lost-seconds (* 60 60)))
		      (rem (mod lost-seconds (* 60 60)))
		      (mm (/ rem 60))
		      (ss (mod rem 60))) 
		 
		; XXX 2digit always
		 (format "%s:%s:%s" 
			 ; is it two digit hour?
			 (propertize (format "%d" hh) 'face 'lost-hour-face)
			 (propertize (lost-twodig mm) 'face 'lost-minsec-face)
			 (propertize (lost-twodig ss) 'face 'lost-minsec-face)))
		 ))))
    (setq lost-mode-string ms)
    (force-mode-line-update)
    )

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
	     (erase-buffer)
	     (insert ">: ")
	     (goto-char (point-max)))
	    (prompt-ok 
	     (message "ok")
	     (sit-for 1)
	     ))

      ))) ; entry mode
)

(setq lost-mode-string "LOST")

;; from timeclock. find the global-mode-string symbol in the
;; modeline format. 
(defun lost-set-modeline ()
  (let ((list-entry (memq 'global-mode-string
			  mode-line-format)))
    (unless (or (null list-entry)
		(memq 'lost-mode-string mode-line-format))
      (setcdr list-entry
	      (cons 'lost-mode-string
		    (cdr list-entry))))
    ))

(lost-set-modeline)

; mode-line-format

; (goto-char (point-min))
; (insert ">: ")
; (looking-at ">: ")
; (lost-periodic)

; (setq lost-seconds (* 60 108))
; (setq lost-seconds (* 60 5))
; (setq lost-seconds 5)
(run-at-time 0 1 'lost-periodic)


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
