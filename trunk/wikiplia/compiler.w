;                           -*- lisp -*-
; bootstrapping W compiler

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
; fn construct        (DONE)
; include construct   (DONE)
; handle auto-quoting (DONE)
; cond construct
; lets construct

(include "stdlib"
(fn (prog)

;; XXX to stdlib
(let nth
  (fn (self n l)
      (if (eq n 0) (car l)
        (nth nth (- n 1) (cdr l))))

(let translate
  (fn (self exp)
       ; what kind of expression is it?
       (xcase exp
         exp ; empty list
         (h t  ; nonempty list
               ; need to case analyze which prim this is
               ; in essence 

             (xcase h
                    ; it has to be a symbol, or something's wrong
                    ; (note, this excludes in place lambda application..)
                    no no no no no
                    (theprim 
		     (cond
                      ((eq theprim "defs")
                        ; t: list of pairs
                        (map (fn (d_arg)
                                 (list (car d_arg) (self self (car (cdr d_arg))))) t))

		      ((eq theprim "cond")
 	 	        ; t: list of conditions
			; we do a macro expansion (to chained ifs) 
			; and recurse on that result
			(self self
			     (foldr (fn (c rest) 
					(xcase c
					       (abort "empty condition in cond?")
					       (thecond thiscase
						 (list (parse "if")
						       thecond
						       (car thiscase)
						       rest))
					       ) ; xcase
					)
			              ;; if all fail, then we return nil
			              (parse "nil")
				      t)))

                      ((eq theprim "include")
                        ; t: "page" body
                        (let meta_lib (head (string "w:" (car t)))
                        ; assume it has metadata, and skip it
                        (let lib (xcase (car (cdr (cdr (cdr meta_lib))))
                                   no (_ _ no) (q q))
                        (let bod (self self (car (cdr t)))
                        (let bindlib (fn (bl_self l) 
                                      (xcase l
                                        bod ;; no more bindings...
                                        (thedef rest
                                           (list (parse "let")
                                                 (quote (car thedef))
                                                 (car (cdr thedef))
                                                 (quote (bl_self bl_self rest))
                                            )
                                       )))
                           (bindlib bindlib lib)
                         )))))

                     ((eq theprim "lambda")
                         ; t: arg body
                         (cons h
                               (cons (quote (self self (car t)))
                                     (cons (quote (self self (car (cdr t))))
                                           nil))))

                     ((eq theprim "if")
                         ; t: cond tbod fbod
                         (list h (self self (car t))
                                 (quote (self self (car (cdr t))))
                                 (quote (self self (car (cdr (cdr t)))))))

                     ((eq theprim "handle")
                         ; t: try catch
                         (list h (quote (self self (car t)))
                                 (quote (self self (car (cdr t))))))

                     ((eq theprim "let")
                         ; t: sym value body
                         (list h (quote (car t))
                                 (self self (car (cdr t)))
                                 (quote (self self (car (cdr (cdr t)))))))

                     ;; (fn (arg1 arg2 ... argn) body)
                     ((eq theprim "fn")
                         ; t args body
                         ; XXX need gensym
                         (let argname "fnarg_"
                           (let genargs
                             (fn (ga_self l bod) 
                               (xcase l
                                ; no more args...
                                (self self bod)
                                ; one arg ...
                                (thisarg rest
                                  (list (parse "xcase")
                                     ; argument tail always rebound as the same thing (argname)
                                     (parse argname)
                                     ; no more actual args? oops!
                                     (quote (parse "noarg")) ;; XXX abort?
                                     ; otherwise, bind this arg and recurse
                                     (quote (list thisarg (parse argname) (ga_self ga_self rest bod))))
                                  )
                                 ) ; xcase on remaining arguments
                                )

                            ; XXX could use 'symbol' constructor
                           (list (parse "lambda")
                                 (quote (parse argname))
                                 ;; bind args and then exec body...
                                 (quote (genargs genargs (car t) (car (cdr t))))))))

                      ((eq theprim "xcase")
                         ; t: ob nb lb qb sb ib yb
                         (xcase t
                              (abort "no args to xcase?")
                              (ob cases
                                (cons h (cons (self self ob)
                                  ;; quotes all arguments; allows any number of them
                                  (map (fn (x) (quote (self self x))) cases))))))

		      (1 
                       ;; otherwise, assume it is eager...
                       (cons h
                             (map (fn (x) (self self x)) t)))
		       )
                   ))
             ) ; nonempty list

          (q (abort "quote not allowed in W"))

          exp ; string
          exp ; int
          (s 
            ; some symbols we'll macro-expand
            (if (eq s "nil")
                (quote nil)

              ; the rest we'll leave alone...
              ; could fail on prims that we macro-expand
              ; (let, if, lambda, xcase)
              ; because those cannot be used in a "higher-order"
              ; way now..
              exp))
           ))

  ;; then translate it.
  (translate translate (parse prog))

))))
