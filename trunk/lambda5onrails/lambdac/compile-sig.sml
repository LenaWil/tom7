
(* Interface to the Lambdac compiler. *)

signature COMPILE =
sig

    (* compile source

       takes path to source file and produces compiled output(s)
       in that same location. *)
    val compile : string -> unit

end

