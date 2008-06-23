
structure Postmortem =
struct

    open SDL
    structure FontSmall = Sprites.FontSmall
    structure Font = Sprites.Font
    structure FontMax = Sprites.FontMax
    structure FontHuge = Sprites.FontHuge
    structure SmallFont3x = Sprites.SmallFont3x
    structure SmallFont = Sprites.SmallFont

    val background = Sprites.requireimage "testgraphics/postmortem.png"    
    val screen = Sprites.screen

    val BGMIDI = "postmortem.mid"
    val PRECURSOR = 180
    val SLOWFACTOR = 5
    val MENUTICKS = 0w60
    val MINIMUM_TIME = 0w2000

    (* It's hard to calibrate the cutoffs for dancing awards. Here are
       some measurements with the 360 X-Plorer, configured correctly:

       0.056m/s was my normal standing posture for Goog. 
       0.1 when I was rocking out.
       0.016 when I was trying to stay as still as possible and still play.
       (But on other songs I can get 0.0...)
       I can get 0.0 if I just sit there and don't play anything. *)
        

    (* To earn a medal, you have to get at least 90% on the song. *)
    datatype medal = 
        (* Got 100% *)
        PerfectMatch
        (* Averaged at least 0.25 m/s dancing *)
      | Snakes
        (* Less than 0.02 m/s (?) average dancing *)
      | Stoic
        (* Only strummed upward. *)
      | Plucky
        (* Only strummed downward. *)
      | Pokey

    exception Done
    fun loop tracks =
        let
            val () = Sound.all_off ()

            val { misses, percent = (hit, total), ... } = Match.stats tracks
            val () = print ("At end: " ^ Int.toString misses ^ " misses\n");
            val () = if total > 0
                     then print ("At end: " ^ Int.toString hit ^ "/" ^ Int.toString total ^
                                 " (" ^ Real.fmt (StringCvt.FIX (SOME 1)) (real hit * 100.0 / real total) ^ 
                                 "%) of notes hit\n")
                     else ()

            val { totaldist, totaltime, upstrums, downstrums } = State.stats ()

            val () = print ("Danced: " ^ Real.fmt (StringCvt.FIX (SOME 2)) totaldist ^ "m (" ^
                            Real.fmt (StringCvt.FIX (SOME 3)) (totaldist / totaltime)
                            ^ "m/s)\n")

            val (divi, thetracks) = Game.fromfile BGMIDI
            val tracks = Game.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            val nexta = ref 0w0
            val start = SDL.getticks()
            fun exit () = if SDL.getticks() - start > MINIMUM_TIME
                          then raise Done
                          else ()

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
                    val X_PERCENT = 50
                    val Y_PERCENT = 100
                    val X_COUNT = 50
                    val Y_COUNT = Y_PERCENT + FontHuge.height + 3
                    val X_DANCE = 50
                    val Y_DANCE = Y_COUNT + FontSmall.height + 3
                    val X_STRUM = 50
                    val Y_STRUM = Y_DANCE + FontSmall.height + 3

                in
                    blitall(background, screen, 0, 0);

                    FontHuge.draw(screen, X_PERCENT, Y_PERCENT,
                                  "^3" ^ 
                                  Real.fmt (StringCvt.FIX (SOME 1)) (real hit * 100.0 / real total) ^ "^0%");
                    FontSmall.draw(screen, X_COUNT, Y_COUNT,
                                   "^1(^4" ^ Int.toString hit ^ "^1/^4" ^ Int.toString total ^ "^1) notes");
                    (* XXX extraneous, max streak, average latency, etc. *)
                    FontSmall.draw(screen, X_DANCE, Y_DANCE,
                                   "Danced: ^2" ^ Real.fmt (StringCvt.FIX (SOME 2)) totaldist ^ "^0m (" ^
                                   Real.fmt (StringCvt.FIX (SOME 3)) (totaldist / totaltime)
                                   ^ "m/s)");
                    FontSmall.draw(screen, X_STRUM, Y_STRUM,
                                   "Strum: ^2" ^ Int.toString upstrums ^ "^0 up, ^2" ^
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
