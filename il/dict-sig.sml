
signature ILDICT =
sig

  exception ILDict of string

  val transform : IL.ilunit -> IL.ilunit

end
