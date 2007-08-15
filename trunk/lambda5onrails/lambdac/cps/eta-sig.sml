signature CPSETA =
sig

  exception Eta of string

  (* optimize this CPS expression *)
  val optimize : CPS.cexp -> CPS.cexp

end