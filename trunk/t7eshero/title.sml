functor TitleFn(val screen : SDL.surface) :> TITLE =
struct

    open SDL
    structure FontMax = Sprites.FontMax
    structure FontHuge = Sprites.FontHuge

    (* XXX where? Config? Input? *)
    datatype rawevent =
        Key of SDL.sdlk
      | JButton of { which : int, button : int }
      | JHat of { which : int, hat : int, state : SDL.Joystick.hatstate }
    (* ... more, if we support them *)

    type config = { joymap : int -> int }
    val joymap : config -> int -> int = #joymap

    datatype selection = Play | Configure

    exception Selected

    fun dummy_joymap 0 = 0
      | dummy_joymap 1 = 1
      | dummy_joymap 3 = 2
      | dummy_joymap 2 = 3
      | dummy_joymap 4 = 4
      | dummy_joymap _ = 999 (* XXX *)

    val dummy = { midi = "medleyscore.mid",
                  difficulty = Hero.Real,
                  slowfactor = 5,
                  config = { joymap = dummy_joymap } }

    val TITLEMIDI = "title.mid"
    val PRECURSOR = 180
    val SLOWFACTOR = 5
        
    local val seed = ref (0wxDEADBEEF : Word32.word)
    in
        fun random () =
            let
                val () = seed := Word32.xorb(!seed, 0wxF13844F5)
                val () = seed := Word32.*(!seed, 0wx7773137)
                val () = seed := Word32.+(!seed, 0wx7654321)
            in
                seed := !seed + 0w1;
                !seed
            end
        fun random_int () =
            Word32.toInt (Word32.andb(random (), 0wx7FFFFFFF))
    end

    fun fancy s =
        String.concat (map (fn c =>
                            implode [#"^", chr (ord #"0" + (random_int() mod 6)), c])
                       (explode s))

    fun loop () =
        let
            (* from 0..(humplen-1) *)
            val humpframe = ref 0
            val humprev = ref false
            val selected = ref Play

            val (divi, thetracks) = Game.fromfile TITLEMIDI
            val tracks = Game.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            fun move_up () =
                selected :=
                (case !selected of
                     Play => Configure
                   | Configure => Play)

            val move_down = move_up

            val playstring = ref "^1Play"
            val confstring = ref "^1Configure"

            fun loopplay () =
                let
                    val nows = Song.nowevents cursor
                in
                    List.app 
                    (fn (label, evt) =>
                     (case label of
                          Match.Music (inst, _) =>
                     (case evt of
                          MIDI.NOTEON(ch, note, 0) => Sound.noteoff (ch, note)
                        | MIDI.NOTEON(ch, note, vel) => Sound.noteon (ch, note, 
                                                                      90 * vel, 
                                                                      inst) 
                        | MIDI.NOTEOFF(ch, note, _) => Sound.noteoff (ch, note)
                        | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
                          | _ => ()))
                    nows
                end

            fun advance () =
                let
                in
                    (* XXX should pause on first, last frames a bit *)
                    (if !humprev
                     then humpframe := !humpframe - 1
                     else humpframe := !humpframe + 1);
                    (if !humpframe < 0
                     then (humpframe := 0; humprev := false)
                     else ());
                    (if !humpframe >= (Vector.length Sprites.humps)
                     then (humpframe := (Vector.length Sprites.humps - 1); 
                           humprev := true)
                     else ());
                        
                    playstring := "^1Play";
                    confstring := "^1Configure";

                    (case !selected of
                         Play => playstring := fancy "Play"
                       | Configure => confstring := fancy "Configure")
                end

            val Y_PLAY = 148
            val Y_CONF = 148 + FontHuge.height + 12
            val MENUTICKS = 0w60

            (* configure sub-menu *)
            val NINPUTS = 7 (* GRYBO, strum-up, strum-down, ... *)
            fun configure () =
                let
                    exception AbortConfigure and FinishConfigure
                    val done = ref 0
                    val values = Array.array(NINPUTS, NONE : rawevent option)

                    val Y_GUITAR = 300
                    val Y_PRESS = Y_GUITAR - (57 * 2)
                    val Y_OK = Y_GUITAR + (81 * 2)
                    val PRESS_OFFSET = 104
                    fun buttonpos x = 
                        (if x <= 4 
                         then x * 28
                         else if x = 5 orelse x = 6 then (180 * 2)
                              else raise Hero.Hero "??")

                    fun accept e =
                        let in
                            Array.update(values, !done, SOME e);
                            done := !done + 1;
                            if !done = NINPUTS
                            then raise FinishConfigure
                            else ()
                        end

                    fun input () =
                        case pollevent () of
                            SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise AbortConfigure
                          | SOME E_Quit => raise Hero.Exit
                          (* any other key is interpreted as a guitar key *)
                          | SOME (E_KeyDown { sym }) => accept (Key sym)
                          | SOME (E_JoyDown jb) => accept (JButton jb)
                          | SOME (E_JoyHat jh) => accept (JHat jh)
                          | _ => ()

                    (* nothin' doin' *)
                    fun advance () = ()
                    fun draw () =
                        let
                        in
                            (* XXX should have configure bg *)
                            blitall(Sprites.title, screen, 0, 0);
                            (* blitall(Vector.sub(Sprites.humps, !humpframe), screen, 128, 333); *)
                            blitall(Sprites.guitar, screen, 0 - buttonpos (!done), Y_GUITAR);
                            blitall(Sprites.press, screen, PRESS_OFFSET, Y_PRESS);
                            Util.for 0 (!done - 1)
                            (fn x =>
                             blitall(Sprites.press_ok, screen, 
                                     (0 - buttonpos (!done))
                                     + PRESS_OFFSET
                                     + buttonpos x, Y_OK));
                            flip screen
                        end

                    fun go next =
                        let 
                            val () = Song.update ()
                            val () = loopplay ()
                            val () = input ()
                            val now = getticks()
                        in
                            if now > next
                            then (advance();
                                  draw(); 
                                  go (now + MENUTICKS))
                            else (go next)
                        end
                in
                    go (getticks())
                        handle AbortConfigure => ()
                             | FinishConfigure => Hero.messagebox "hehe, not saving config yet"
                end


            fun draw () =
                let
                in
                    blitall(Sprites.title, screen, 0, 0);
                    blitall(Vector.sub(Sprites.humps, !humpframe), screen, 128, 333);
                    FontHuge.draw(screen, 36, Y_PLAY, !playstring);
                    FontHuge.draw(screen, 36, Y_CONF, !confstring);
                    (case !selected of
                         Play => FontHuge.draw(screen, 4, Y_PLAY, Chars.HEART)
                       | Configure => FontHuge.draw(screen, 4, Y_CONF, Chars.HEART));
                    flip screen
                end

            fun select () =
                case !selected of
                    Play => raise Selected
                  | Configure => 
                        let in
                            configure ()
                            (*
                            blitall(Sprites.guitar, screen, 3, 300);
                            blitall(Sprites.press, screen, 25, 200);
                            flip screen;
                            Hero.messagebox "Sorry, can't configure yet"
                            *)
                        end

            fun input () =
                case pollevent () of
                    SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Hero.Exit
                  | SOME E_Quit => raise Hero.Exit
                  | SOME (E_KeyDown { sym = SDLK_UP }) => move_up ()
                  | SOME (E_KeyDown { sym = SDLK_DOWN }) => move_down ()
                  | SOME (E_KeyDown { sym = SDLK_ENTER }) => select ()
                  | SOME (E_JoyDown { button, ... }) => select ()
                  | SOME (E_JoyHat { state, ... }) =>
                    if Joystick.hat_up state
                    then move_up ()
                    else if Joystick.hat_down state
                         then move_down()
                         else ()
                  | _ => ()

            fun go next =
                let 
                    val () = Song.update ()
                    val () = loopplay ()
                    val () = input ()
                    val now = getticks()
                in
                    if now > next
                    then (advance();
                          draw(); 
                          go (now + MENUTICKS))
                    else (go next)
                end

        in
            go 0w0 handle Selected => 
                let in
                    Sound.all_off ();
                    dummy
                end
        end


end
