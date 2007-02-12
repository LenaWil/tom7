
structure Bytes =
struct

  datatype prim =
    SUBST  (* ? *)
  | INSERT
  | HEAD
  | READ
  | ABORT
  | LIST
  | STRING
    (* cond, quoted-true (cond not List nil), quoted-false (cond is List nil) *)
  | IF

  datatype exp =
    List of exp list
  | String of string
  | Int of IntInf.int
  | Symbol of string
  | Prim of prim
  (* the only lazy expression *)
  | Quote of exp

  val prims =
    [("insert", INSERT),
     ("head", HEAD),
     ("read", READ),
     ("abort", ABORT),
     ("list", LIST),
     ("string", STRING),
     ("if", IF)]

end
