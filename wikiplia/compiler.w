
; compiler from W to B, written in W

; this "compiler" is mostly just desugaring: the
; B language supports most of the features we
; need. (and they both use the same abstract syntax).

; features to implement:
; progn (not needed yet)
; let auto-quoting
; if auto-quoting
; lambda auto-quoting
; xcase auto-quoting

; actually I guess we should completely eliminate quote?
; if we see quote in the source program we pretty much
; don't have any idea if what's under that will ever be
; evaluated, so we don't know how we're supposed to translate
; it.
; better to think of W as being a call-by-name ML-like
; language.

(let nil '()
(let map
  (lambda args
    (let self (car args)
      (let f (car (cdr args))
	(let l (car (cdr (cdr args))))
	; nil list is 'false'
	(if l
	    (cons (f (car l)) (self self f (cdr l)))
	  nil))))

(let translate
  (lambda args
    (let self (car args)
      (let exp (car (cdr args))
	   ; what kind of expression is it?
	   (xcase exp
	      exp ; empty list
	      (h t  ; nonempty list
	            ; need to case analyze which prim this is
	            ; in essence 
		 
		 (xcase h
			; it has to be a symbol, or something's wrong
			no no no no no
			(prim 
			 (if (eq prim "lambda")
			     (cons h
				   (cons (quote (car 

			     (abort) ; o/w
			 )))

	      (q 
	       (quote (self self q))
	       ) ; just go right through quote
	         ; XXX probably should fail, actually; see above
	      exp ; string
	      exp ; int
	      (s exp) ; symbol (nothing special to do)
	              ; could fail on prims that we macro-expand
	              ; (let, if, lambda, xcase)
	              ; because those cannot be used in a higher-order
	              ; way now..
		  ))))
  

;; read from form.source or something...
  
  (abort)
))

