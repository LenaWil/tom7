; This is the initial (bootstrapping) program.
; its role is to provide an implementation (interpreter) of
; W that can run the W compiler (which itself is written in W).

; (there's nothing here yet, obviously)

(let 'nil '() '
(let 'car (lambda 'args
	    '(xcase args 'noa '(arg u
				   (xcase arg 'noc '(h u h))))) '
(let 'cdr (lambda 'args
	    '(xcase args 'nob '(arg u 
				   (xcase arg 'nod '(u t t))))) '

(let 'map 
  (lambda 'args
    '(let 'self (car args)
	  '(let 'f (car (cdr args))
		'(let 'l (car (cdr (cdr args)))
		      '(if l
			   '(cons (f (car l)) (self self f (cdr l)))
			 'nil)))))
 
  '(string (map map (lambda 'x '(string (car x) "!")) '("hello" " world")))

;  '(car '("hello" "world"))
))))
