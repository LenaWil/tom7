
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

  fun eval G e =
    let
      val ctr = ref 0
      fun UP () = ctr := !ctr + 1


      fun evaluate G e = (UP (); evaluate' G e)

      and evaluate' G (Quote e) = e
        | evaluate' G (String s) = String s
        | evaluate' G (Int i) = Int i
        | evaluate' G (Symbol p) =
        (case ListUtil.Alist.find op= Bytes.prims p of
           NONE =>
             (case ListUtil.Alist.find op= G p of
                NONE => raise Abort ("unknown prim/var " ^ p)
              | SOME v => v)
         | SOME p => Prim p)
        (* re-evaluateuating these is probably indicative of an error? *)
        | evaluate' G (Prim p) = Prim p
        | evaluate' G (Closure c) = Closure c


        | evaluate' G (List l) =
        (case map (evaluate G) l of
           (Prim LIST) :: rest => List rest
         | (Prim CONS) :: h :: (List t) :: nil => List (h :: t)
         | (Prim CONS) :: _ => raise Abort "cons/args"
         | (m as (Prim XCASE) :: obj :: _) => 
             ((*print ("xcase @ " ^ tostring obj ^ "\n"); *)
              case m of
                (Prim XCASE) :: (List nil)      :: nb :: _ => evaluate G nb
              | (Prim XCASE) :: (List (h :: t)) :: _ :: (List[Symbol xh, Symbol xb, lb]) :: _ => evaluate ((xh, h) :: (xb, List t) :: G) lb
              | (Prim XCASE) :: (Quote e)       :: _ :: _ :: (List[Symbol x, qb]) :: _ => evaluate ((x, e) :: G) qb
              | (Prim XCASE) :: (String _)      :: _ :: _ :: _ :: sb :: _ => evaluate G sb
              | (Prim XCASE) :: (Int _)         :: _ :: _ :: _ :: _ :: ib :: _ => evaluate G ib
              | (Prim XCASE) :: (Symbol s)      :: _ :: _ :: _ :: _ :: _ :: (List[Symbol x, yb]) :: _ => evaluate ((x, String s) :: G) yb
              | (Prim XCASE) :: _               :: _ :: _ :: _ :: _ :: _ :: _ :: no :: _ => evaluate G no
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

         | (Prim HANDLE) :: e1 :: (List [Symbol x, e2]) :: _ => ((evaluate G e1) handle Abort s
                                                                   => evaluate ((x, String s) :: G) e2)
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
         | (Prim IF) :: (List nil) :: tr :: fa :: nil => evaluate G fa
         | (Prim IF) :: _ :: tr :: fa :: nil => evaluate G tr
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

         (* XXX could be a derived form, I think? Lots of stuff evaluates a list... *)
         | (Prim EVAL) :: l :: nil => evaluate G l
         | (Prim EVAL) :: _ => raise Abort "evaluate/args"

         | (Prim LET) :: Symbol x :: va :: body :: nil => 
             let in
               (* print (x ^ " = ..\n"); *)
               evaluate ((x, va) :: G) body
             end
         | (Prim LET) :: z => (print (StringUtil.delimit " | " (map tostring z)); raise Abort "let/args")
         (* | (Prim _) :: _ => raise Abort "unimplemented prim" *)

         | (Closure (G, x, bod)) :: args => evaluate ((x, List args) :: G) bod

         | (Quote _) :: _ => raise Abort "evaluate/quote?"
         | (Symbol _) :: _ => raise Abort "evaluate/quote?"
         | (String _) :: _ => raise Abort "evaluate/string?"
         | (Int _) :: _ => raise Abort "evaluate/int?"
         | (List _) :: _ => raise Abort "evaluate/list?"
         | nil => raise Abort "evaluate/empty"
             )
    in
      (evaluate G e, !ctr)
    end


  (* environment is always empty to start *)
  (* val eval = fn e => eval nil e *)

end
