signature CPSINLINE =
sig

  exception Inline of string

  (* optimize this CPS expression *)
  val optimize : CPSTypeCheck.context -> CPS.cexp -> CPS.cexp

end