
(* For the creation of overlapping, resiable, movable windows with
   arbitrary contents. *)

signature WINDOW =
sig

    type window

    (* for each of these event handlers, return true if
       the event was successfully handled (and should not
       be passed to any other windows/etc.) *)
    val handleevent : window -> SDL.event -> bool

    (* is the window active right now? *)
    (* val active : window -> bool *)

    val draw : window -> SDL.surface -> unit

    val make :
        { (* clicks within the window are are assumed handled *)
          click : int * int -> unit,
          (* but not all keys *)
          keydown : SDL.sdlk -> bool,
          keyup   : SDL.sdlk -> bool,
          
          (* how to draw the contents
             x, y, w, h *)
          draw : SDL.surface * int * int * int * int -> unit,

          border : int,
          border_color : SDL.color,

          (* border > 0 if resiable *)
          resizable : bool,
          x : int, y : int,
          w : int, h : int,
          
          title_height : int,
          drawtitle : SDL.surface * int * int -> unit } -> window

end
