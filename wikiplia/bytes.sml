
structure Bytes =
struct

  datatype exp =
    List of exp list
  | String of string
  | Int of IntInf.int
  | Prim of prim
  (* the only lazy expression *)
  | Quote of exp

  (* symbol = HEAD (or READ) of some string *)

  and prim =
    SUBST  (* ? *)
  | INSERT
  | HEAD
  | READ
  | ABORT
  | LIST
  | STRING
    (* cond, quoted-true (cond not List nil), quoted-false (cond is List nil) *)
  | IF

  val prims =
    [("insert", INSERT),
     ("head", HEAD),
     ("read", READ),
     ("abort", ABORT),
     ("list", LIST),
     ("string", STRING),
     ("if", IF)]

end
