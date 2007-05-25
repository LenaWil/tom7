
(* XXX this seems to duplicate some of the info in ../podata.sml   *)

signature PRIMTYPES =
sig

    exception PrimTypes of string

    (* If a primop exists, it is a polymorphic n-argument function. 
       Currently, it will never be polymorphic in worlds. *)
    val typeof : string -> (Primop.primop * (IL.typ list * IL.typ) IL.poly) option

end

