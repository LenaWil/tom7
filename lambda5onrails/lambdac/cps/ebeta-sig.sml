signature CPSEBETA =
sig

  exception EBeta of string

  (* optimize this CPS expression *)
  val optimize : CPS.cexp -> CPS.cexp

end