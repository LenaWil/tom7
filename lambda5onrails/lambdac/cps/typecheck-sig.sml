signature CPSTYPECHECK =
sig

  type ctyp  = CPS.ctyp
  type cexp  = CPS.cexp
  type cval  = CPS.cval
  type var   = CPS.var
  type world = CPS.world

  type context

  exception Absent of var

  (* These are like the functions in CPS, but with added context information. *)
  val checkwiset : (context -> ctyp -> ctyp) -> context -> ctyp -> ctyp
  val checkwisee : (context -> ctyp -> ctyp) -> 
                   (context -> cval -> cval) -> 
                   (context -> cexp -> cexp) -> context -> cexp -> cexp
  val checkwisev : (context -> ctyp -> ctyp) -> 
                   (context -> cval -> cval) -> 
                   (context -> cexp -> cexp) -> context -> cval -> cval

  (* all type variables have kind 0 *)
  val bindtype  : context -> var -> context
  val bindworld : context -> var -> context
  val bindvar   : context -> var -> ctyp -> world -> context
  val binduvar  : context -> var -> ctyp -> context

  (* or Absent if not bound. *)
  val gettype  : context -> var -> unit
  val getworld : context -> var -> unit
  val getvar   : context -> var -> ctyp * world
  val getuvar  : context -> var -> ctyp

end