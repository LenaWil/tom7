;; slide mode Copyright (c) 2004 Tom Murphy
;; licensed under the GNU public license (see COPYING)

;; XXX need to add growing and shrinking of fonts keys

;; fifty dashes, C-u 50 -
(defvar slide-marker "--------------------------------------------------"
  "*String that separates slides for slide control functions.")

(defun this-slide ()
"Narrow to this slide. Slides are delimited by `slide-marker'."
  (interactive "")
  (progn
    (search-backward slide-marker)
    (search-forward slide-marker)
    (let* ((start (progn
                        (search-backward slide-marker)
                            (search-forward slide-marker)
                                (point)))
              (end   (progn
                           (search-forward slide-marker)
                               (search-backward slide-marker)
                                   (point))))
      (narrow-to-region start end)
      (goto-char (point-min)))))

(defun next-slide ()
  "Go to the next slide. Uses narrow-to-region to hide all of the other text. Slides are delimited by slide-marker."
  (interactive "")
  (progn
    (widen)
    (search-forward slide-marker)
    (this-slide)))

(defun prev-slide ()
  "Go to the previous slide. See `next-slide'."
  (interactive "")
  (progn
    (widen)
    (search-backward slide-marker)
    (forward-char -1)
    (this-slide)))

(defun slide-mode ()
  "Set up key bindings for navigating slides."
  (interactive "")
  (progn
    (local-set-key [prior] 'prev-slide)
    (local-set-key [next] 'next-slide)
    (local-set-key "\M-m" 'sml-mode)
    (local-set-key "\M-e" 'english-mode)
    (message " *** Slide Mode by Tom 7 *** ")))

;; End Tom's Slide Mode
