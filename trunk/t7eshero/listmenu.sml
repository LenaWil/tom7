functor ListMenuFn(val screen : SDL.surface) :> LISTMENU =
struct

    structure U = Util
    open SDL

    val SKIP_X = 2
    val SKIP_Y = 2
    val WIDTH_OVERHEAD = SKIP_X * 2
    val TICKS = 0w60

    (* Fill, if color is SOME c *)
    fun ofillrect (s, x, y, w, h, SOME c) = fillrect (s, x, y, w, h, c)
      | ofillrect _ = ()

    fun 'item select { items = nil, ... } = NONE
      | select
        { x : int,
          y : int,
          width : int,
          height : int,
          items : 'item list,
          itemheight : 'item -> int,
          (* draw an item, x/y/selected *)
          drawitem : 'item * int * int * bool -> unit,
          (* XXX needs joymap for config.. *)

          bordercolor : color option,
          bgcolor : color option,
          selcolor : color option,

          (* must clear the screen, at least *)
          parent : Drawable.drawable

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
                  | SOME e =>
                        (case Input.map e of
                             (* XXX in input we should standardize this behavior
                                into "intentions", so that we can use drums and stuff *)
                             SOME (_, Input.ButtonDown 0) => select ()
                           | SOME (_, Input.ButtonDown 1) => raise Abort
                           | SOME (_, Input.StrumUp) => move_up ()
                           | SOME (_, Input.StrumDown) => move_down ()
                           | SOME _ => () (* XXX other standard guitar controls? paging? *)
                           | NONE =>
                                 (case e of
                                      (* If these are unmapped, then they have default behaviors. *)
                                      E_KeyDown { sym = SDLK_UP } => move_up ()
                                    | E_KeyDown { sym = SDLK_DOWN } => move_down ()
                                    | E_KeyDown { sym = SDLK_KP_ENTER } => select ()
                                    | E_KeyDown { sym = SDLK_RETURN } => select ()

                                    | E_KeyDown { sym = SDLK_HOME } => selected := 0
                                    | E_KeyDown { sym = SDLK_END } => selected := Vector.length items - 1

                                    (* XXX TODO:
                                       pageup and pagedown are hard to support because items are variable-sized.
                                       This is an ad hoc hack for now.
                                       *)
                                    | E_KeyDown { sym = SDLK_PAGEDOWN } => U.for 0 7 (move_down o ignore)
                                    | E_KeyDown { sym = SDLK_PAGEUP } => U.for 0 7 (move_up o ignore)

                                    (* might allow you to get to configure with only an unconfigured joystick. *)
                                    | E_JoyDown { button, ... } => select ()
                                    | E_JoyHat { state, ... } =>
                                          if Joystick.hat_up state
                                          then move_up ()
                                          else if Joystick.hat_down state
                                               then move_down()
                                               else ()
                                    | _ => ()))
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
                            else (if !selected = idx
                                  then ofillrect(screen,
                                                 x + SKIP_X, y + SKIP_Y + off,
                                                 width - (SKIP_X * 2), h,
                                                 selcolor)
                                  else ();
                                  drawitem (Vector.sub(items, idx),
                                            x + SKIP_X, y + SKIP_Y + off,
                                            !selected = idx);
                                  draws (off + h, idx + 1))
                        end

                in
                    Drawable.draw parent;
                    (* selector area. always max *)
                    (* XXX alpha is not supported in fillrect. We should use it. *)
                    ofillrect (screen, x, y, width, height, bgcolor);
                    ofillrect (screen, x, y, width, SKIP_X, bordercolor);
                    ofillrect (screen, x, y + height - SKIP_X, width, SKIP_X, bordercolor);
                    ofillrect (screen, x, y, SKIP_X, height, bordercolor);
                    ofillrect (screen, x + width - SKIP_X, y, SKIP_X, height, bordercolor);

                    (* here? *)
                    setscroll ();
                    draws (0, !scroll);

                    flip screen
                end

            fun go next =
                let
                    val () = Drawable.heartbeat parent
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

    val DEFAULT_BGCOLOR = color (0wx26, 0wx26, 0wx26, 0wxAA)
    val DEFAULT_BORDERCOLOR = color (0wx00, 0wx00, 0wx00, 0wxFF)
    val DEFAULT_SELCOLOR = color (0wx44, 0wx44, 0wx77, 0wxFF)
end