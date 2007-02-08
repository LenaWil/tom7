
structure Bytes =
struct

  datatype exp =
    List of exp list
  | String of string
  | Int of IntInf.int
  | Prim of prim
  (* the only lazy expression *)
  | Quote of exp list

  (* symbol = HEAD (or READ) of some string *)

  and prim =
    SUBST  (* ? *)
  | INSERT
  | HEAD
  | READ
  | ABORT
  | LIST

end
