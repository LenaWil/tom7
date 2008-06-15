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
          items : 'item list,
          itemheight : 'item -> int,
          (* draw an item, x/y/selected *)
          draw : 'item * int * int * bool -> unit,
          (* XXX needs joymap for config.. *)
          
          (* must clear the screen, at least *)
          parent_draw : unit -> unit,
          parent_heartbeat : unit -> unit

          } -> 'item option

    (* When you ask for a listmenu of width w, you get (w - WIDTH_OVERHEAD)
       in width for your items. *)
    val WIDTH_OVERHEAD : int

end
