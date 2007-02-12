
structure Eval =
struct
  open Bytes

  exception Abort of string

  fun tostring (String s) = s
    | tostring (Int i) = IntInf.toString i
    | tostring (List l) = "(" ^ StringUtil.delimit " " (map tostring l) ^ ")"
    | tostring (Symbol s) = "(symbol:" ^ s ^ ")"
    | tostring (Prim p) = "(prim)"
    | tostring (Closure c) = "(closure)"
    | tostring _ = "?"

  fun eval G (Quote e) = e
    | eval G (String s) = String s
    | eval G (Int i) = Int i
    | eval G (Symbol p) =
    (case ListUtil.Alist.find op= Bytes.prims p of
       NONE =>
         (case ListUtil.Alist.find op= G p of
            NONE => raise Abort ("unknown prim/var " ^ p)
          | SOME v => v)
     | SOME p => Prim p)
    (* re-evaluating these is probably indicative of an error? *)
    | eval G (Prim p) = Prim p
    | eval G (Closure c) = Closure c


    | eval G (List l) =
    (case map (eval G) l of
       (* XXX why?? *)
       (Prim LIST) :: rest => List rest
     | (Prim CONS) :: h :: (List t) :: nil => List (h :: t)
     | (Prim CONS) :: _ => raise Abort "cons/args"
(*
     | (Prim CAR) :: (List (h :: t)) :: nil => h
     | (Prim CAR) :: _ => raise Abort "car/args"
     | (Prim CDR) :: (List (h :: t)) :: nil => List t
     | (Prim CDR) :: _ => raise Abort "cdr/args"
*)
     | (m as (Prim XCASE) :: obj :: _) => 
         (print ("xcase @ " ^ tostring obj ^ "\n");
          case m of
            (Prim XCASE) :: (List nil)      :: nb :: _ => eval G nb
          | (Prim XCASE) :: (List (h :: t)) :: _ :: (List[Symbol xh, Symbol xb, lb]) :: _ => eval ((xh, h) :: (xb, List t) :: G) lb
          | (Prim XCASE) :: (Quote e)       :: _ :: _ :: (List[Symbol x, qb]) :: _ => eval ((x, e) :: G) qb
          | (Prim XCASE) :: (String _)      :: _ :: _ :: _ :: sb :: _ => eval G sb
          | (Prim XCASE) :: (Int _)         :: _ :: _ :: _ :: _ :: ib :: _ => eval G ib
          | (Prim XCASE) :: (Symbol s)      :: _ :: _ :: _ :: _ :: _ :: (List[Symbol x, yb]) :: _ => eval ((x, String s) :: G) yb
         (* XXX maybe allow last resort default.. *)
          | _ => raise Abort "xcase/args1"

              )
     | (Prim XCASE) :: _ => raise Abort "xcase/args"

     | (Prim ABORT) :: _ => raise Abort "abort"
     | (Prim HEAD) :: (String s) :: nil => DB.head s
     | (Prim HEAD) :: _ => raise Abort "head/args"
     | (Prim READ) :: (String s) :: (Int r) :: nil => DB.read s r
     | (Prim READ) :: _ => raise Abort "read/args"
     | (Prim INSERT) :: (String k) :: value :: nil => Int (DB.insert k value)
     | (Prim INSERT) :: _ => raise Abort "insert/args"
     | (Prim STRING) :: l => String (String.concat (map tostring l))
     | (Prim IF) :: (List nil) :: tr :: fa :: nil => eval G fa
     | (Prim IF) :: _ :: tr :: fa :: nil => eval G tr
     | (Prim IF) :: _ => raise Abort "if/args"
     | (Prim LAMBDA) :: (Symbol x) :: body :: nil => Closure(G, x, body)
     | (Prim LAMBDA) :: _ => raise Abort "lambda/args"

     | (Prim LET) :: Symbol x :: va :: body :: nil => 
         let in
           print (x ^ " = ..\n");
           eval ((x, va) :: G) body
         end
     | (Prim LET) :: z => (print (StringUtil.delimit " | " (map tostring z)); raise Abort "let/args")
     (* | (Prim _) :: _ => raise Abort "unimplemented prim" *)

     | (Closure (G, x, bod)) :: args => eval ((x, List args) :: G) bod

     | (Quote _) :: _ => raise Abort "eval/quote?"
     | (Symbol _) :: _ => raise Abort "eval/quote?"
     | (String _) :: _ => raise Abort "eval/string?"
     | (Int _) :: _ => raise Abort "eval/int?"
     | (List _) :: _ => raise Abort "eval/list?"
     | nil => raise Abort "eval/empty"
         )


  (* environment is always empty to start *)
  val eval = fn e => eval nil e

end