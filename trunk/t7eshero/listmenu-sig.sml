(* A list menu displays a vertically scrollable list of arbitrary items.
   It can have a parent, which gets periodic heartbeat calls, and can
   draw itself beneath the scrolling menu. *)
signature LISTMENU =
sig

    val (* 'item *) select :
        { x : int,
          y : int,
          width : int,
          height : int,
          (* If there are no items, returns NONE immediately. *)
          items : 'item list,
          itemheight : 'item -> int,
          (* draw an item, x/y/selected *)
          drawitem : 'item * int * int * bool -> unit,
          (* XXX needs joymap for config.. *)

          (* If not supplied, then don't draw these *)
          bordercolor : SDL.color option,
          bgcolor : SDL.color option,
          selcolor : SDL.color option,

          (* must clear the screen, at least *)
          parent : Drawable.drawable

          } -> 'item option

    val DEFAULT_BORDERCOLOR : SDL.color
    val DEFAULT_BGCOLOR : SDL.color
    val DEFAULT_SELCOLOR : SDL.color

    (* When you ask for a listmenu of width w, you get (w - WIDTH_OVERHEAD)
       in width for your items. *)
    val WIDTH_OVERHEAD : int

end
