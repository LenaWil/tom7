(* Menu for selecting one's outfit. *)
structure Wardrobe =
struct

    open SDL
    structure FontSmall = Sprites.FontSmall
    structure Font = Sprites.Font
    structure FontMax = Sprites.FontMax
    structure FontHuge = Sprites.FontHuge
    structure SmallFont3x = Sprites.SmallFont3x
    structure SmallFont = Sprites.SmallFont

    val background = Sprites.requireimage "testgraphics/wardrobe.png"
    val screen = Sprites.screen

    val BGMIDI = "postmortem.mid" (* XXXX *)
    val PRECURSOR = 180
    val SLOWFACTOR = 5
    val MENUTICKS = 0w60

    exception Done
    fun loop () =
        let
            val () = Sound.all_off ()

            val (divi, thetracks) = Game.fromfile BGMIDI
            val tracks = Game.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            val nexta = ref 0w0
            val start = SDL.getticks()
            fun exit () = raise Done

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

            (* XXX will be using listmenu, right? *)
            and input () =
                case pollevent () of
                    SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Done
                  | SOME E_Quit => raise Hero.Exit
                  | SOME (E_KeyDown { sym = SDLK_ENTER }) => exit()
                  | SOME e => 
                        (case Input.map e of
                             SOME (_, Input.ButtonDown b) => exit()
                           | SOME (_, Input.ButtonUp b) => ()
                           | SOME (_, Input.StrumUp) => ()
                           | SOME (_, Input.StrumDown) => ()
                           | _ => ())
                  | NONE => ()

            and draw () =
                let
                    val X_ROBOT = 68
                    val Y_ROBOT = 333
                in
                    blitall(background, screen, 0, 0);

                    FontHuge.draw(screen, X_PERCENT, Y_PERCENT,
                                  "^3" ^ 
                                  Real.fmt (StringCvt.FIX (SOME 1)) (real hit * 100.0 / real total) ^ "^0%");
                    FontSmall.draw(screen, X_COUNT, Y_COUNT,
                                   "^1(^5" ^ Int.toString hit ^ "^1/^5" ^ Int.toString total ^ "^1) notes");
                    (* XXX extraneous, max streak, average latency, etc. *)
                    FontSmall.draw(screen, X_DANCE, Y_DANCE,
                                   "Danced: ^5" ^ Real.fmt (StringCvt.FIX (SOME 2)) totaldist ^ "^0m (^5" ^
                                   Real.fmt (StringCvt.FIX (SOME 3)) (totaldist / totaltime)
                                   ^ "^0m/s)");
                    FontSmall.draw(screen, X_STRUM, Y_STRUM,
                                   "Strum: ^5" ^ Int.toString upstrums ^ "^0 up, ^5" ^
                                   Int.toString downstrums ^ "^0 down");
                    ()
                end

            and heartbeat () = 
                let 
                    val () = Song.update ()
                    val () = loopplay ()
                    val now = getticks ()
                in
                    if now > !nexta
                    then ((* advance(); *)
                          nexta := now + MENUTICKS)
                    else ()
                end

            val nextd = ref 0w0
            fun go () =
                let 
                    val () = heartbeat ()
                    val () = input ()
                    val now = getticks ()
                in
                    (if now > !nextd
                     then (draw (); 
                           nextd := now + MENUTICKS;
                           flip screen)
                     else ());
                     go ()
                end
        in
            go () handle Done => Sound.all_off ()
        end

end
