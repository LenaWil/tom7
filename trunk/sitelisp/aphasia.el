
(defvar aphasia-mode-hook nil
  "*List of functions to call when entering aphasia mode")

;(defvar aphasia-mode-map nil
;  "Keymap for aphasia major mode")

;(if aphasia-mode-map 
;    nil
;  (setq aphasia-mode-map (make-keymap))

;(define-key aphasia-mode-map ... ...)

(defvar aphasia-mode-syntax-table nil 
  "Syntax table used while in aphasia mode.")

(if aphasia-mode-syntax-table
    ()              ; Do not change the table if it is already set up.
  (setq aphasia-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?\*      ". 23" aphasia-mode-syntax-table)
  (modify-syntax-entry ?\(      "()"  aphasia-mode-syntax-table)
  (modify-syntax-entry ?\)      ")("  aphasia-mode-syntax-table)
  (modify-syntax-entry ?/       ". 14"  aphasia-mode-syntax-table)
  (modify-syntax-entry ?\[      "(]"   aphasia-mode-syntax-table)
  (modify-syntax-entry ?\]      ")["   aphasia-mode-syntax-table)
  (modify-syntax-entry ?{       "(}"   aphasia-mode-syntax-table)
  (modify-syntax-entry ?}       "){"   aphasia-mode-syntax-table))

(defun aphasia-mode ()
  "Major mode for editing aphasia source code."
  (interactive)
  (kill-all-local-variables)
  (setq major-mode 'aphasia-mode)
  (setq mode-name "Aphasia")
  (run-hooks 'aphasia-mode-hook)
  (setq tab-width 4)
  (setq indent-tabs-mode nil)
  (setq comment-start-skip "/\\*+ *")
  (setq comment-start "/* ")
  (setq comment-end " */")
  (set-syntax-table aphasia-mode-syntax-table)
)

(font-lock-add-keywords 'aphasia-mode '(
(
"\\<\\(if\\|then\\|else\\|[ls]et\\|select\\|op\\(tional\\)?\\|from\\|where\\|database\\|table\\|insert\\|into\\|delete\\|exception\\|raise\\|handle\\)\\>"
. font-lock-keyword-face)

(
"\\<\\(I\\|nil\\|aye\\|nay\\|[0-9]+\\|0[XxBbOo][0-9]+\\|[0-9]+\\.[0-9]+\\)\\>"
. font-lock-constant-face)

(
"\\<\\(int\\|key\\|float\\|string\\|ptr\\|bool\\|blob\\)\\>"
. font-lock-type-face)

("\\<\\(val\\)\\>" . font-lock-warning-face)

("\\<\\(orelse\\|andalso\\|andthen\\|o\\(therwise\\)?\\|div\\|mod\\)\\>"
. font-lock-variable-name-face)

("$ *\\([A-Za-z][A-Za-z0-9'-_]*\\) *;" 1 font-lock-variable-name-face)

("\\<\\(print\\|app\\|filter\\|foldl\\|foldr\\|head\\|tail\\|cgigetstring\\|cgigetnum\\|time\\|datefmt\\|die\\)\\>"
. font-lock-variable-name-face)

("\\<\\(INCLUDE\\|DEFINE\\|MACRO\\|ENDM\\)\\>"
 . font-lock-function-name-face) ; why doesn't preprocessor work?

)) ;; end of aphasia keywords

(font-lock-fontify-buffer)

(provide 'aphasia)

