signature CPSOPT =
sig

  exception CPSOpt of string

  (* optimize this CPS expression *)
  val optimize : CPS.cexp -> CPS.cexp

end