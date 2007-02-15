;;                                 -*- lisp -*-
; This is the initial (bootstrapping) program.
; its role is to provide an implementation (interpreter) of
; W that can run the W compiler (which itself is written in W).

(let 'nil '() '
(let 'stdheader "Content-Type: text/html; charset=utf-8\r\n\r\n" '
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
			 'nil))))) '

; chop up to the first instance of the char given
(let 'token
  (lambda 'args
    '(let 'self (car args)
	  '(let 'sep (car (cdr args))
		'(let 's (car (cdr (cdr args)))
		      '(let 'n (car (cdr (cdr (cdr args))))
			    '(if (eq n (size s)) '(list s "")
			       '(let 'ch (sub s n)
				     '(if (eq ch sep)
					  '(list (substr s 0 n) (substr s (+ n 1) (- (size s) (+ n 1))))
					  '(self self sep s (+ n 1)))
				     ))))))) '

; same, but last instance		      
(let 'rtoken
  (lambda 'args
    '(let 'self (car args)
	  '(let 'sep (car (cdr args))
		'(let 's (car (cdr (cdr args)))
		      '(let 'n (car (cdr (cdr (cdr args))))
			    '(if (eq n (- 0 1)) '(list "" s)
			       '(let 'ch (sub s n)
				     '(if (eq ch sep)
					  '(list (substr s 0 n) (substr s (+ n 1) (- (size s) (+ n 1))))
					  '(self self sep s (- n 1)))
				     ))))))) '

  ; figure out what we're doing based on the URL
  ; (toss off the starting / char
(let 'url (car (cdr (token token "/" (head "request.url") 0))) '
(let 'action_target (token token "/" url 0) '
(let 'action (car action_target) '
(let 'fulltarget (car (cdr action_target)) '
  
  (if (eq action "edit")
      ;; need to fetch the source code for this page
      ;; and put it in the textarea
      '(string stdheader
	       "editing " target " ... "
	       "<form method=\"post\" action=\"/save/" target "\"><textarea rows=20 cols=80 name=\"contents\">XXX</textarea>\n"
	       "<input type=submit value=\"save\"></form>")

    '(if (eq action "save")
       ; might need to compile... 
       ; figure out the language based on the extension.
       (let 'base_ext (rtoken rtoken "." fulltarget (- (size fulltarget) 1)) '
       (let 'base (car base_ext) '
       (let 'ext (car (cdr base_ext)) '
       
       ; get the compiler, or if there is none, assume the identity
       (let 'compile (handle '(head "compile") '(lambda 'x 'x)) '



	'(string
	  stdheader
	  "oops, saving not supported yet")
      '(string stdheader "unknown action!")))
      

  ; (string (map map (lambda 'x '(string (car x) "!")) (token token "/" "hello/world" 0)))

)))))))))))))