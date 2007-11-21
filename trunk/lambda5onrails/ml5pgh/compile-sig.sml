
(* Interface to the ML5/pgh compiler. *)

signature COMPILE =
sig

    (* compile source

       takes path to source file and produces compiled output(s)
       in that same location. *)
    val compile : string -> unit


    (* Set by command-line parameters, but useful for
       interactive use. *)
    val showil : bool ref
    val showcps : bool ref
    val writecps : bool ref

end

