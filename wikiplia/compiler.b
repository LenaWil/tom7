;                           -*- lisp -*-
; compiler from W to B, written in W

; this "compiler" is mostly just desugaring: the
; B language supports most of the features we
; need. (and they both use the same abstract syntax).

; features to implement:
; progn (not needed yet)
; let auto-quoting    (DONE)
; if auto-quoting     (DONE)
; lambda auto-quoting (DONE)
; implement nil       (DONE)
; xcase auto-quoting  (DONE)

; actually I guess we should completely eliminate quote?
; if we see quote in the source program we pretty much
; don't have any idea if what's under that will ever be
; evaluated, so we don't know how we're supposed to translate
; it.
; better to think of W as being a call-by-name ML-like
; language.

(lambda 'args '
(let 'prog (parse (car args)) '

(let 'nil '() '
(let 'car (lambda 'args
            '(xcase args 'noa '(arg u
                                   (xcase arg 'error_car_nil '(h u h))))) '
(let 'cdr (lambda 'args
            '(xcase args 'nob '(arg u 
                                   (xcase arg 'error_cdr_nil '(u t t))))) '

(let 'map 
  (lambda 'args
    '(let 'self (car args)
          '(let 'f (car (cdr args))
                '(let 'l (car (cdr (cdr args)))
                      '(if l
                           '(cons (f (car l)) (self self f (cdr l)))
                         'nil))))) '

;; (let 'map (lambda 'args (map (cons map args))) '

(let 'nth
  (lambda 'args
    (let 'self (car args) '
      (let 'n (car (cdr args)) '
	(let 'l (car (cdr (cdr args))) '
	  (if (eq n 0)
	      '(car l)
	    '(nth nth (- n 1) (cdr l))))))) '

;;(let 'nth (lambda 'args (nth (cons nth args))) '

(let 'translate
  (lambda 'args '
    (let 'self (car args) '
      (let 'exp (car (cdr args)) '
	   ; what kind of expression is it?
	   (xcase exp
	     'exp ; empty list
	     '(h t  ; nonempty list
	            ; need to case analyze which prim this is
	            ; in essence 
		 
		 (xcase h
			; it has to be a symbol, or something's wrong
			'no 'no 'no 'no 'no
			'(theprim 
			 (if (eq theprim "lambda") '
			     ; t: arg body
			     (cons h
				   (cons (quote (self self (car t)))
					 (cons (quote (self self (car (cdr t))))
					       nil))) '
			 (if (eq theprim "if") '
			     ; t: cond tbod fbod
			     (list h (self self (car t))
				     (quote (self self (car (cdr t))))
				     (quote (self self (car (cdr (cdr t)))))) '
				   
			 (if (eq theprim "let") '
			     ; t: sym value body
			     (list h (quote (car t))
				     (self self (car (cdr t)))
				     (quote (self self (car (cdr (cdr t)))))) '

			 (if (eq theprim "xcase") '
			     ; t: ob nb lb qb sb ib yb
			     (list h (self self ob)
				   ;; XXX shouldn't require all cases to be present
				     (quote (self self (nth 1 t))) ; nb
				     (quote (self self (nth 2 t))) ; lb
				     (quote (self self (nth 3 t))) ; qb
				     (quote (self self (nth 4 t))) ; sb
				     (quote (self self (nth 5 t))) ; ib
				     (quote (self self (nth 6 t))) ; yb
				     ) '

			   ;; otherwise, assume it is eager...
			   (cons h
				 (map map (lambda 'args '(self self (car args))) t))
			 ))))))
		 ) ; nonempty list

	      '(q (abort "quote not allowed in W"))

	      'exp ; string
	      'exp ; int
	      '(s 
		; some symbols we'll macro-expand
		(if (eq s "nil") '
		    (quote nil) '

		  ; the rest we'll leave alone...
		  ; could fail on prims that we macro-expand
		  ; (let, if, lambda, xcase)
		  ; because those cannot be used in a higher-order
		  ; way now..
		  exp))
	       ))))

  ;; then translate it.
  '(translate translate prog)

)))))
)))
