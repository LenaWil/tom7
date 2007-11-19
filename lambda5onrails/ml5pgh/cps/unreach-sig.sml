signature CPSUNREACH =
sig

  exception Unreach of string

  (* optimize this CPS expression *)
  val optimize : CPSTypeCheck.context -> CPS.cexp -> CPS.cexp

end