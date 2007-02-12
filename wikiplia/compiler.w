
; compiler from W to B, written in W

; this "compiler" is mostly just desugaring: the
; B language supports most of the features we
; need. (and they both use the same abstract syntax).
; the implementation of variable binding
; is perhaps the most interesting.

(progn

; translate

; define symbol body.
; symbol and body are automatically quoted.
(define translate
  ;; G = translation environment.
  ;; e = expression to translate.
   (lambda (G e)
     ;; which kind of expression is it?
     (if (list? e) 
	 (abort)
	 (if (sym? e)
	     ;; look up in translation environment...
	     (abort)

	   (if (quote? e)
	       ;; translate inner, requote
	       (abort)
	     ;; leaves are untranslated
	     e)



) ; progn