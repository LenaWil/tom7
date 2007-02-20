;;                                 -*- lisp -*-
; This is the initial (bootstrapping) program.
; its role is to provide a minimal wiki interface
; that will allow us to develop compilers for
; better languages, that we can then use to
; overwrite this program.

(let 'nil '() '
(let 'car (lambda 'args
            '(xcase args 'noa '(arg u
                                   (xcase arg 'error_car_nil '(h u h))))) '
(let 'cdr (lambda 'args
            '(xcase args 'nob '(arg u 
                                   (xcase arg 'error_cdr_nil '(u t t))))) '
(let 'stdheader "Content-Type: text/html; charset=utf-8\r\n\r\n" '
(let 'redirect (lambda 'target '(string "Location: " (car target) "\r\n\r\n")) '


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

(let 'htmlescape
  ; PERF
  (lambda 'hargs
    '(let 's (car hargs)
         '(let 'hrec (lambda 'args
                       '(let 'self (car args)
                             '(let 'n (car (cdr args))
                                   '(if (eq n (size s))
                                        'nil
                                      '(let 'ch (sub s n)
                                            '(cons
                                              (if (eq ch "<")
                                                  '"&lt;"
                                                '(if (eq ch ">")
                                                     '"&gt;"
                                                   '(if (eq ch "&")
                                                        '"&amp;"
                                                      'ch)))
                                              (self self (+ n 1))))))))
               '(eval (cons string (hrec hrec 0)))))) '

  ; figure out what we're doing based on the URL
  ; (toss off the starting / char
(let 'url (car (cdr (token token "/" request.url 0))) '
(let 'action_target (token token "/" url 0) '
(let 'action (car action_target) '
(let 'fulltarget (car (cdr action_target)) '
  
(let 'tabs (lambda 'args
             '(let 'page (car args) '
                   ; XXX make tabs
                   (string "<a href=\"/view/_/" page "\">view</a> "
                           "<a href=\"/edit/" page "\">edit</a> "
                           "<a href=\"/history/" page "\">history</a> "
                           "<a href=\"/run/" page "\">run</a> "))) '

  (if (eq action "edit")
      ;; need to fetch the source code for this page
      ;; and put it in the textarea
      '(let 'oldcontents (handle '(head fulltarget) '(_ nil)) '
        (string stdheader
                (tabs fulltarget) "<p>"
               (if oldcontents
                   '(string "editing " fulltarget " ... ")
                   '(string "creating new page " fulltarget " ... "))
               "<br/><b>Do not copy text from other websites without permission. It will be deleted.</b>"
               "<form method=\"post\" action=\"/save/" fulltarget "\"><textarea rows=35 cols=120 name=\"contents\">"
               (xcase oldcontents
		   '""
		   '(_ _ "(was list data)")
		   '(_ "(was quoted data)")
		   '(htmlescape oldcontents)
		   '(string "(was int " oldcontents ")")
		   '(_ "(was symbol)")
		   '"(internal data)")
               "</textarea>\n"
               "<input type=submit value=\"save\"></form>"))

    '(if (eq action "save")
       ; might need to compile... 
       ; figure out the language based on the extension.
      '(let 'base_ext (rtoken rtoken "." fulltarget (- (size fulltarget) 1)) '
       (let 'base (car base_ext) '
       (let 'ext (car (cdr base_ext)) '
       (let 'dat form.contents '

       (if (eq base "")
           ;; if there was no . then ext holds the entire name. in this case
           ;; just save.
           '(let '_ (insert fulltarget dat) '
                 ;; XXX goto revision
                 (redirect (string "/view/_/" fulltarget)))

         ;; otherwise we should compile, saving the source and compiled version
         ;; (might do this recursively??  eg. prog.b.w)
         ; get (and run to produce a closure) the compiler, or if there is none, assume the identity (??)
         '(let 'compile (eval (handle '(head (string ext ":compile")) '(_ '(lambda 'x '(car x))))) '
               (let 'exe (handle '(compile dat) '(msg
                                                  ; if compilation fails, then we
                                                  ; return a program that aborts
                                                  (list
                                                   'abort
                                                   (string
                                                    "compilation of " fulltarget
                                                    " failed because " msg)))) '
               ; save source
               (let '_ (insert fulltarget dat) '
               ; save executable
               (let '_ (insert base exe) '
                    ;; XXX should jump directly to the revision we inserted
                    (redirect (string "/view/_/" fulltarget))
                    ; (string stdheader 
                ;           "<p>compiler: " compile
                ;           "<p>compiled: " exe)
                    )))))
       )))) ; action save

       '(if (eq action "history")
            '(string
              stdheader 
              (tabs fulltarget)
              "<p>history for " fulltarget " ...<hr/><p>"
              (string (map map (lambda 'args '(string "<a href=\"/view/" (car args) "/" fulltarget "\">" 
                                                      (car args) "</a> ")) (history fulltarget))))

       '(if (eq action "view")
           '(let 'rev_target (token token "/" fulltarget 0) '
            (let 'rev (car rev_target) '
            (let 'target (car (cdr rev_target)) '     
             (string
              stdheader
              (tabs target)
              "<p>viewing " target (if (eq rev "_") '"" '(string " @ " rev)) " ... <hr/><p>"
              (handle '(string "<pre>\n" (if (eq rev "_") '(head target) '(read target (int rev))) "</pre>\n")
                      '(_
                        (string "There is no symbol called <b>" target "</b>. "
                                "Perhaps you'd like to <a href=\"/edit/" target "\">create it</a>?")))))))

          ;; XXX protect against run main...? (= infinite loop)
         '(if (eq action "run")
            '(string
              stdheader 
              (tabs fulltarget)
              "<p>running " fulltarget " ... <hr/><p>"
              (handle '(let 'prog (head fulltarget)
                          '(handle '(eval prog) '(msg (string "<b>Runtime error</b>: " msg))))
                      '(_
                        (string "There is no symbol called <b>" fulltarget "</b>. "
                                "Perhaps you'd like to <a href=\"/edit/" fulltarget "\">create it</a>?"))))
            

          '(string stdheader "unknown action!")))

       ))) ; action case analysis
      

  ; (string (map map (lambda 'x '(string (car x) "!")) (token token "/" "hello/world" 0)))

))))))))))))))
