
signature ILDICT =
sig

  exception ILDict of string

  val transform : IL.exp -> IL.exp

end
