signature CPSTYPECHECK =
sig

  type ctyp  = CPS.ctyp
  type cexp  = CPS.cexp
  type cval  = CPS.cval
  type var   = CPS.var
  type world = CPS.world

  type context

  exception TypeCheck of string

  (* These are like the functions in CPS, but with added context information. *)
(*
  val checkwiset : (context -> ctyp -> ctyp) -> context -> ctyp -> ctyp
  val checkwisee : (context -> ctyp -> ctyp) -> 
                   (context -> cval -> cval) -> 
                   (context -> cexp -> cexp) -> context -> cexp -> cexp
  val checkwisev : (context -> ctyp -> ctyp) -> 
                   (context -> cval -> cval) -> 
                   (context -> cexp -> cexp) -> context -> cval -> cval
*)

  (* every context has the "current world" *)
  val empty : world -> context

  (* all type variables have kind 0, but some are mobile *)
  val bindtype  : context -> var -> bool -> context
  val bindworld : context -> var -> context
  val bindvar   : context -> var -> ctyp -> world -> context
  val binduvar  : context -> var -> ctyp -> context
  val setworld  : context -> world -> context

  (* or TypeCheck if not bound. *)
  val gettype   : context -> var -> bool
  val getworld  : context -> var -> unit
  val getvar    : context -> var -> ctyp * world
  val getuvar   : context -> var -> ctyp
  val worldfrom : context -> world

end