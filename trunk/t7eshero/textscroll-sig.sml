(* A textscroll is a list of lines of text, which can be appended to.
   It's used for console output from processes like self-update.

   It can have a parent, which gets periodic heartbeat calls, and can
   draw itself beneath the scrolling area. *)
signature TEXTSCROLL =
sig

    type textscroll
    val make :
        { x : int,
          y : int,
          width : int,
          height : int,

          (* If not supplied, then don't draw these *)
          bordercolor : SDL.color option,
          bgcolor : SDL.color option

          } -> textscroll

    val DEFAULT_BORDERCOLOR : SDL.color
    val DEFAULT_BGCOLOR : SDL.color

    val clear : textscroll -> unit
    (* Add a line to the bottom. *)
    val write : textscroll -> string -> unit
    (* Replace the line at the bottom *)
    val rewrite : textscroll -> string -> unit
    val draw : SDL.surface -> textscroll -> unit

end
