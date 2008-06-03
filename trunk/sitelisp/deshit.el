
(defun deshit (a b c)
  (save-excursion
    (save-restriction
      (widen) ;; don't allow shit out of view
      (goto-char (point-min))
      (while (search-forward "shit" nil t)
	(replace-match "" nil t))
      )))

(defun deshit-mode ()
  "In this mode you cannot type shit."
  (interactive "")
  (progn
    (kill-all-local-variables)
    (setq mode-name "Deshit")
    (setq major-mode 'deshit-mode)
    (deshit t t t)
    (add-hook 'after-change-functions 'deshit nil t)
    ))
