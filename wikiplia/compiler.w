
; compiler from W to B, written in W

; this "compiler" is mostly just desugaring: the
; B language supports most of the features we
; need. (and they both use the same abstract syntax).

; features to implement:
; progn
; let auto-quoting
; if auto-quoting
; lambda auto-quoting

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
	   (if (list? exp)
	       (
	       (if (
		  
		  ))))
  

;; read from form.source or something...


))

