signature CPSREDUCE =
sig

  exception Reduce of string

  (* optimize this CPS expression *)
  val optimize : CPSTypeCheck.context -> CPS.cexp -> CPS.cexp

end