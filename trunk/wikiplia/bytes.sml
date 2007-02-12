
structure Bytes =
struct

  datatype prim =
    INSERT
  | HEAD
  | READ
  | ABORT
    (* XXX probably not necessary *)
  | LIST
  | CONS
  | STRING
    (* cond, quoted-true (cond not List nil), quoted-false (cond is List nil) *)
    (* XXX kinda definable, could use xcase *)
  | IF
    (* (let 'sym exp 'body) *)
  | LET
    (* lambda 'x 'body) *)
  | LAMBDA
  (* | CAR | CDR xx definable *)
    (* xcase obj 
       'nil-body
       '(h t list-body)
       '(e quote-body)
       'string-body
       'int-body
       '(s symbol-body)
       
       (nb. no prim or closure body)

       *)
  | XCASE
  | QUOTE

  datatype exp =
    List of exp list
  | String of string
  | Int of IntInf.int
  | Symbol of string
  (* the only lazy expression *)
  | Quote of exp
  (* user can't write these *)
  | Prim of prim
  | Closure of (string * exp) list * string * exp

  val prims =
    [("insert", INSERT),
     ("head", HEAD),
     ("read", READ),
     ("abort", ABORT),
     ("lambda", LAMBDA),
     ("list", LIST),
     ("cons", CONS),
     ("quote", QUOTE),
     ("string", STRING),
     ("xcase", XCASE),
     ("let", LET),
     ("if", IF)]

end
