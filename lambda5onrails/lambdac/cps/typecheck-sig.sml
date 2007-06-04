signature CPSTYPECHECK =
sig

  type ctyp  = CPS.ctyp
  type cexp  = CPS.cexp
  type cval  = CPS.cval
  type var   = CPS.var
  type world = CPS.world

  type context

  exception TypeCheck of string

  (* every context has the "current world" *)
  val empty : world -> context

  (* all type variables have kind 0, but some are mobile *)
  val bindtype  : context -> var -> bool -> context
  val bindworld : context -> var -> context
  val bindvar   : context -> var -> ctyp -> world -> context
  val binduvar  : context -> var -> ctyp -> context
  val setworld  : context -> world -> context
    
  (* we can also know about some world constants *)
  val bindworldlab : context -> string -> context

  (* or TypeCheck if not bound. *)
  val gettype   : context -> var -> bool
  val getworld  : context -> world -> unit
  val getvar    : context -> var -> ctyp * world
  val getuvar   : context -> var -> ctyp
  val worldfrom : context -> world

  (* when the dictionary invariant is in place, get the dictionary (as uvar)
     for a type variable *)
  val getdict   : context -> var -> var

  (* computes the unrolling of a mu *)
  val unroll    : int * (var * ctyp) list -> ctyp

  (* validate the expression e in the empty context at the supplied world *)
  val check : world -> cexp -> unit

  val checkprog : CPS.program -> unit

end