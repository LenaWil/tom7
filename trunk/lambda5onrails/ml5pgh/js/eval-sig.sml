signature JSEVAL =
sig

    exception JSEval of string

    val execute : Javascript.Program.t -> unit

end
