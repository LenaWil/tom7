signature CPSKNOWN =
sig

  exception Known of string

  (* optimize this CPS expression *)
  val optimize : CPS.cexp -> CPS.cexp

end