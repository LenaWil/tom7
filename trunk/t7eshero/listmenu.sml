functor ListMenuFn(val screen : SDL.surface) :> LISTMENU =
struct

    open SDL

    val SKIP_X = 2
    val SKIP_Y = 2
    val WIDTH_OVERHEAD = SKIP_X * 2
    val TICKS = 0w60

    fun 'item select
        { x : int,
          y : int,
          width : int,
          height : int,
          items : 'item list,
          itemheight : 'item -> int,
          (* draw an item, x/y/selected *)
          drawitem : 'item * int * int * bool -> unit,
          (* XXX needs joymap for config.. *)
          
          (* must clear the screen, at least *)
          parent_draw : unit -> unit,
          parent_heartbeat : unit -> unit

          } : 'item option =
        let
            exception Abort
            exception Done of 'item

            val items = Vector.fromList items
            val selected = ref 0
            val scroll = ref 0
            fun setscroll () =
                let 
                    val () = if !selected < !scroll
                             then scroll := !selected
                             else ()

                    (* n^2 in rare worst case... *)
                    fun doscroll (off, idx) =
                        (* in case no items can fit, don't loop forever *)
                        if !selected = !scroll then ()
                        else 
                            if idx >= Vector.length items then () else (* possible?? *)
                               (* can we fit more? *)
                               let val h = itemheight (Vector.sub(items, idx))
                               in
                                   if off + h > height
                                   then (scroll := !scroll + 1; doscroll (0, !scroll))
                                   else if idx = !selected then () (* drawing it *)
                                        else (doscroll (off + h, idx + 1))
                               end
                in
                    doscroll (0, !scroll)
                end

            fun fixup () = if !selected < 0 then selected := 0
                           else if !selected >= Vector.length items
                                then selected := Vector.length items - 1
                                else ()
            fun move_up () = (selected := !selected - 1; fixup ())
            fun move_down () = (selected := !selected + 1; fixup ())
            fun select () = raise Done (Vector.sub(items, !selected))

            fun input () =
                case pollevent () of
                    SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Abort
                  | SOME E_Quit => raise Hero.Exit
                  | SOME (E_KeyDown { sym = SDLK_UP }) => move_up ()
                  | SOME (E_KeyDown { sym = SDLK_DOWN }) => move_down ()
                  | SOME (E_KeyDown { sym = SDLK_KP_ENTER }) => select ()
                  | SOME (E_KeyDown { sym = SDLK_RETURN }) => select ()

                  | SOME (E_KeyDown { sym = SDLK_HOME }) => selected := 0
                  | SOME (E_KeyDown { sym = SDLK_END }) => selected := Vector.length items - 1

                  (* XXX TODO: 
                     pageup and pagedown are hard to support because items are variable-sized.
                  | SOME (E_KeyDown { sym = SDLK_PAGEUP }) => 
                    *)

                  | SOME (E_JoyDown { button, ... }) => select ()
                  (* XXX should use joymap for this *)
                  | SOME (E_JoyHat { state, ... }) =>
                    if Joystick.hat_up state
                    then move_up ()
                    else if Joystick.hat_down state
                         then move_down()
                         else ()
                  | _ => ()

            (* nothin' doin' *)
            fun advance () = ()
            fun draw () =
                let
                    fun draws (off, idx) =
                        if idx >= Vector.length items then () else
                        (* can we fit more? *)  
                        let val h = itemheight (Vector.sub(items, idx))
                        in
                            if off + h > height
                            then ()
                            else (drawitem (Vector.sub(items, idx), 
                                            x + SKIP_X, y + SKIP_Y + off, 
                                            !selected = idx);
                                  draws (off + h, idx + 1))
                        end
                in
                    parent_draw ();
                    (* selector area. always max *)
                    (* XXX alpha is not supported in fillrect. We should use it. *)
                    fillrect (screen, x, y, width, height, color (0wx26, 0wx26, 0wx26, 0wxAA));
                    fillrect (screen, x, y, width, SKIP_X, color (0wx00, 0wx00, 0wx00, 0wxFF));
                    fillrect (screen, x, y + height - SKIP_X, width, SKIP_X, color (0wx00, 0wx00, 0wx00, 0wxFF));
                    fillrect (screen, x, y, SKIP_X, height, color (0wx00, 0wx00, 0wx00, 0wxFF));
                    fillrect (screen, x + width - SKIP_X, y, SKIP_X, height, color (0wx00, 0wx00, 0wx00, 0wxFF));

                    (* here? *)
                    setscroll ();
                    draws (0, !scroll);

                    flip screen
                end

            fun go next =
                let 
                    val () = parent_heartbeat ()
                    val () = input ()
                    val now = getticks()
                in
                    if now > next
                    then (advance();
                          draw(); 
                          go (now + TICKS))
                    else go next
                end
        in
            go (getticks())
                handle Abort => NONE
                     | Done i => SOME i
        end


end