
structure Eval =
struct
  open Bytes

  exception Abort of string

  fun tostring (String s) = s
    | tostring (Int i) = IntInf.toString i
    | tostring (List l) = String.concat (map tostring l)
    | tostring _ = raise Abort "string/args"

  fun eval (Quote e) = e
    | eval (String s) = String s
    | eval (Int i) = Int i
    | eval (Prim p) = Prim p
    | eval (List l) =
    (case map eval l of
       (Prim LIST) :: rest => List rest
     | (Prim ABORT) :: _ => raise Abort "prim"
     | (Prim HEAD) :: (String s) :: nil => DB.head s
     | (Prim HEAD) :: _ => raise Abort "head/args"
     | (Prim READ) :: (String s) :: (Int r) :: nil => DB.read s r
     | (Prim READ) :: _ => raise Abort "read/args"
     | (Prim INSERT) :: (String k) :: value :: nil => Int (DB.insert k value)
     | (Prim INSERT) :: _ => raise Abort "insert/args"
     | (Prim STRING) :: l => String (String.concat (map tostring l))
     | (Prim IF) :: (List nil) :: tr :: fa :: nil => eval fa
     | (Prim IF) :: _ :: tr :: fa :: nil => eval tr
     | (Prim IF) :: _ => raise Abort "if/args"

     (* | (Prim _) :: _ => raise Abort "unimplemented prim" *)
     | (Quote _) :: _ => raise Abort "eval/quote?"
     | (String _) :: _ => raise Abort "eval/string?"
     | (Int _) :: _ => raise Abort "eval/int?"
     | (List _) :: _ => raise Abort "eval/list?"
         )


end