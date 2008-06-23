
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

    datatype medal = PerfectMatch

    exception Done
    fun loop tracks =
        let

            val { misses, percent = (hit, total), ... } = Match.stats tracks
            val () = print ("At end: " ^ Int.toString misses ^ " misses\n");
            val () = if total > 0
                     then print ("At end: " ^ Int.toString hit ^ "/" ^ Int.toString total ^
                                 " (" ^ Real.fmt (StringCvt.FIX (SOME 1)) (real hit * 100.0 / real total) ^ 
                                 "%) of notes hit\n")
                     else ()


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
                    val Y_COUNT = 100 + FontHuge.height + 3
                in
                    blitall(background, screen, 0, 0);

                    FontHuge.draw(screen, X_PERCENT, Y_PERCENT,
                                  "^3" ^ 
                                  Real.fmt (StringCvt.FIX (SOME 1)) (real hit * 100.0 / real total) ^ "^0%");
                    FontSmall.draw(screen, X_COUNT, Y_COUNT,
                                   "^1(^4" ^ Int.toString hit ^ "^1/^4" ^ Int.toString total ^ "^1) notes");
                    (* XXX extraneous, max streak, average latency, etc. *)
                    (* distance danced *)
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
