signature CPSUTIL =
sig

  type ctyp = CPS.ctyp
  type var = Variable.var
  type cval = CPS.cval
  type cexp = CPS.cexp
  type world = CPS.world

  val ctyp' : (var, ctyp, var, world) CPS.ctypfront -> ctyp


  (* utilities *)

  val ptoct : Podata.potype -> ctyp

  (* is the variable free in this type (value; expression)? *)
  (* XXX Expensive; use the ones in CPS *)
  val freet : var -> ctyp -> bool
  val freev : var -> cval -> bool
  val freee : var -> cexp -> bool

  (* apply the function to each immediate subterm (of type ctyp) and
     return the reconstructed type *)
  val pointwiset : (ctyp -> ctyp) -> ctyp -> ctyp
  (* Same, but to subterms that are types, values, expressions *)
  val pointwisee : (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cexp -> cexp
  val pointwisev : (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cval -> cval

  (* with a mapper for worlds as well *)
  val pointwisetw : (world -> world) -> (ctyp -> ctyp) -> ctyp -> ctyp
  val pointwiseew : (world -> world) -> (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cexp -> cexp
  val pointwisevw : (world -> world) -> (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cval -> cval

end
