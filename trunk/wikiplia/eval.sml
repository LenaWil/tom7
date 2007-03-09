
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
    | tostring (Quote q) = "'" ^ tostring q
    (* | tostring _ = "?" *)

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
         ((*print ("xcase @ " ^ tostring obj ^ "\n"); *)
          case m of
            (Prim XCASE) :: (List nil)      :: nb :: _ => eval G nb
          | (Prim XCASE) :: (List (h :: t)) :: _ :: (List[Symbol xh, Symbol xb, lb]) :: _ => eval ((xh, h) :: (xb, List t) :: G) lb
          | (Prim XCASE) :: (Quote e)       :: _ :: _ :: (List[Symbol x, qb]) :: _ => eval ((x, e) :: G) qb
          | (Prim XCASE) :: (String _)      :: _ :: _ :: _ :: sb :: _ => eval G sb
          | (Prim XCASE) :: (Int _)         :: _ :: _ :: _ :: _ :: ib :: _ => eval G ib
          | (Prim XCASE) :: (Symbol s)      :: _ :: _ :: _ :: _ :: _ :: (List[Symbol x, yb]) :: _ => eval ((x, String s) :: G) yb
          | (Prim XCASE) :: _               :: _ :: _ :: _ :: _ :: _ :: _ :: no :: _ => eval G no
          | z => (print (StringUtil.delimit " | " (map tostring z)); raise Abort "xcase/args1")

              )
     | (Prim XCASE) :: _ => raise Abort "xcase/args"

     | (Prim STRING_LEN) :: (String s) :: nil => Int (IntInf.fromInt (size s))
     (* XXX could support size of arrays *)
     | (Prim STRING_LEN) :: _ => raise Abort ("size/args")
     | (Prim STRING_SUB) :: (String s) :: (Int i) :: nil => (String (implode [String.sub(s, IntInf.toInt i)]) handle _ => raise Abort ("sub/oob"))
     | (Prim STRING_SUB) :: _ => raise Abort "sub/args"

     | (Prim SUBSTR) :: (String s) :: Int start :: Int len :: nil => (String (String.substring(s, IntInf.toInt start,
                                                                                               IntInf.toInt len)) handle _ => raise Abort ("substr/oob"))
     | (Prim SUBSTR) :: _ => raise Abort "substr/args"

     | (Prim HANDLE) :: e1 :: (List [Symbol x, e2]) :: _ => ((eval G e1) handle Abort s
                                                               => eval ((x, String s) :: G) e2)
     | (Prim HANDLE) :: z => (print (StringUtil.delimit " | " (map tostring z)); raise Abort "handle/args")


     | (Prim ABORT) :: (String s) :: _ => raise Abort ("abort: " ^ s)
     | (Prim ABORT) :: _ => raise Abort "abort"
     | (Prim HEAD) :: (String s) :: nil => ((DB.head s) handle DB.NotFound => raise Abort ("head/key [" ^ s ^ "] not found"))
     | (Prim HEAD) :: _ => raise Abort "head/args"
     | (Prim READ) :: (String s) :: (Int r) :: nil => ((DB.read s r) handle DB.NotFound => raise Abort ("read/key [" ^ s ^ "] not found"))
     | (Prim READ) :: _ => raise Abort "read/args"
     | (Prim INSERT) :: (String k) :: value :: nil => Int (DB.insert k value) (* can't fail *)
     | (Prim INSERT) :: _ => raise Abort "insert/args"
     | (Prim STRING) :: l => String (String.concat (map tostring l))
     | (Prim IF) :: (List nil) :: tr :: fa :: nil => eval G fa
     | (Prim IF) :: _ :: tr :: fa :: nil => eval G tr
     | (Prim IF) :: _ => raise Abort "if/args"
     | (Prim LAMBDA) :: (Symbol x) :: body :: nil => Closure(G, x, body)
     | (Prim LAMBDA) :: _ => raise Abort "lambda/args"
     | (Prim QUOTE) :: va :: nil => Quote va
     | (Prim QUOTE) :: _ => raise Abort "quote/args"
     | (Prim PLUS) :: l => Int (foldl (fn (Int x, y) => x + y | _ => raise Abort "+/args") 0 l)
     | (Prim MINUS) :: Int x :: Int y :: nil => Int (x - y)
     | (Prim MINUS) :: _ => raise Abort "-/args"
     | (Prim EQ) :: Int x :: Int y :: nil => if x = y then Int 1 else List nil
     | (Prim EQ) :: String x :: String y :: nil => if x = y then Int 1 else List nil
     | (Prim EQ) :: _ => raise Abort "eq/args"
     | (Prim INT) :: String s :: nil => (case IntInf.fromString s of
                                           NONE => raise Abort "int/args"
                                         | SOME i => Int i)
     | (Prim INT) :: _ => raise Abort "int/args"

     | (Prim HISTORY) :: (String k) :: nil => (List(map Int (DB.history k)) 
                                               handle DB.NotFound => raise Abort ("history/key [" ^ k ^ "] not found"))
     | (Prim HISTORY) :: _ => raise Abort "history/args"

     | (Prim PARSE) :: String x :: nil => ((Parse.parse x) handle Parse.Parse s => raise Abort ("parse: " ^ s))
     | (Prim PARSE) :: l => raise Abort ("parse/args: (got " ^ tostring (List l) ^ ")")

     (* XXX could be a derived form, I think? Lots of stuff evals a list... *)
     | (Prim EVAL) :: l :: nil => eval G l
     | (Prim EVAL) :: _ => raise Abort "eval/args"

     | (Prim LET) :: Symbol x :: va :: body :: nil => 
         let in
           (* print (x ^ " = ..\n"); *)
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
  (* val eval = fn e => eval nil e *)

end