
signature ELABORATE =
sig

    exception Elaborate of string

    val elaborate : EL.elunit -> IL.ilunit

end