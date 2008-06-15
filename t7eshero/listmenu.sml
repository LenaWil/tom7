functor ListMenuFn(val screen : SDL.surface) :> LISTMENU =
struct

    open SDL

    val WIDTH_OVERHEAD = 4
    val TICKS = 0w60

    fun 'item select
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

          } : 'item option =
        let
            exception Abort

            fun move_up () = ()
            fun move_down () = ()
            fun select () = ()

            fun input () =
                case pollevent () of
                    SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Abort
                  | SOME E_Quit => raise Hero.Exit
                  | SOME (E_KeyDown { sym = SDLK_UP }) => move_up ()
                  | SOME (E_KeyDown { sym = SDLK_DOWN }) => move_down ()
                  | SOME (E_KeyDown { sym = SDLK_ENTER }) => select ()
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
                in
                    parent_draw ();
                    (* selector area. always max *)
                    fillrect (screen, x, y, width, height, color (0wx26, 0wx26, 0wx26, 0wxAA));
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
                     (* | FinishConfigure => Hero.messagebox "hehe, not saving config yet" *)
        end


end