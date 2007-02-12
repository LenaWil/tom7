
structure Eval =
struct
  open Bytes

  exception Abort of string

  fun tostring (String s) = s
    | tostring (Int i) = IntInf.toString i
    | tostring (List l) = String.concat (map tostring l)
    | tostring _ = raise Abort "string/args"

  fun eval G (Quote e) = e
    | eval G (String s) = String s
    | eval G (Int i) = Int i
    | eval G (Prim p) = Prim p
    | eval G (Symbol p) =
    (case ListUtil.Alist.find op= Bytes.prims p of
       NONE =>
         (case ListUtil.Alist.find op= G p of
            NONE => raise Abort ("unknown prim/var " ^ p)
          | SOME v => v)
     | SOME p => Prim p)

    | eval G (List l) =
    (case map (eval G) l of
       (Prim LIST) :: rest => List rest
     | (Prim ABORT) :: _ => raise Abort "prim"
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
     | (Prim LET) :: List (Symbol x :: exp :: nil) :: body :: nil =>
         eval ((x, eval G exp) :: G) body
     | (Prim LET) :: _ => raise Abort "let/args"
     (* | (Prim _) :: _ => raise Abort "unimplemented prim" *)
     | (Quote _) :: _ => raise Abort "eval/quote?"
     | (Symbol _) :: _ => raise Abort "eval/quote?"
     | (String _) :: _ => raise Abort "eval/string?"
     | (Int _) :: _ => raise Abort "eval/int?"
     | (List _) :: _ => raise Abort "eval/list?"
         )

  (* environment is always empty to start *)
  val eval = fn e => eval nil e

end