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
    fun loop profile =
        let
            val () = Sound.all_off ()

            val (divi, thetracks) = Game.fromfile BGMIDI
            val tracks = Game.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            val humpframe = ref 0
            val humprev = ref false

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
                    SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Done (* Abort? *)
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

                    fun drawitem item =
                        let val (f, x, y) = Vector.sub(Items.frames item, !humpframe)
                        in blitall(f, screen, X_ROBOT + x, Y_ROBOT + y)
                        end

                    val closet = Profile.closet profile
                        
                    val c = ref 100
                in
                    blitall(background, screen, 0, 0);
                    Items.app_behind (Profile.outfit profile) drawitem;
                    blitall(Vector.sub(Sprites.humps, !humpframe), screen, X_ROBOT, Y_ROBOT);
                    Items.app_infront (Profile.outfit profile) drawitem;

                    List.app (fn item =>
                              let in
                                  FontSmall.draw(screen, 10, !c, Items.name item);
                                  c := FontSmall.height + !c
                              end) closet;
                    ()
                end

            and advance () =
                let in
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
                     else ())
                end

            and heartbeat () = 
                let 
                    val () = Song.update ()
                    val () = loopplay ()
                    val now = getticks ()
                in
                    if now > !nexta
                    then (advance();
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
            go () handle Done => 
                let in
                    Sound.all_off ();
                    Profile.save ()
                end
(*
            | Abort => 
                let in
                    (* restore profile somehow? *)
                    Sound.all_off ()
                end
*)
        end

end
