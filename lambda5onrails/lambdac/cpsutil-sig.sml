signature CPSUTIL =
sig

  type ctyp = CPS.ctyp
  type var = Variable.var
  type cval = CPS.cval
  type cexp = CPS.cexp
  type world = CPS.world

  (* utilities *)

  val ptoct : Podata.potype -> ctyp

  (* is the variable free in this type (value; expression)? *)
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

  (* get the free value vars and value uvars in a value (expression) *)
  val freevarsv : cval -> Variable.Set.set * Variable.Set.set
  val freevarse : cexp -> Variable.Set.set * Variable.Set.set

  (* get the free type vars and world vars in a type (value; expression; world) *)
  val freesvarst : ctyp  -> { t : Variable.Set.set, w : Variable.Set.set }
  val freesvarsv : cval  -> { t : Variable.Set.set, w : Variable.Set.set }
  val freesvarse : cexp  -> { t : Variable.Set.set, w : Variable.Set.set }
  (* note, t will always be empty *)
  val freesvarsw : world -> { t : Variable.Set.set, w : Variable.Set.set }

  val isvfreeinv : var -> cval -> bool
  val isvfreeine : var -> cexp -> bool
  val isufreeinv : var -> cval -> bool
  val isufreeine : var -> cexp -> bool

end
