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

    val background = Sprites.requireimage "wardrobe.png"
    val screen = Sprites.screen

    val BGMIDI = "wardrobe.mid" (* XXX: sines should not click so much. *)
    val PRECURSOR = 180
    val SLOWFACTOR = 5
    val MENUTICKS = 0w60

    structure LM = ListMenuFn(val screen = screen)

    local open Womb
    in
        val womb_pattern =
            Womb.pattern 0w100
            [[A,J,M], [B,K,L], [E,J,M], [F,K,L],
             [H,J,M], [G,K,L], [D,J,M], [C,K,L]]
    end

    exception Done and Abort
    fun loop profile =
        let
            val () = Sound.all_off ()

            val (divi, thetracks) = Score.fromfile BGMIDI
            val tracks = Score.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            val humpframe = ref 0
            val humprev = ref false

            val nexta = ref 0w0
            val start = SDL.getticks()
            fun exit () = raise Done

            val closet = Profile.closet profile
            val outfit = ref (Profile.outfit profile)

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
                                                                           Sound.midivel vel,
                                                                           inst)
                             | MIDI.NOTEOFF(ch, note, _) => Sound.noteoff (ch, note)
                             | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
                             | _ => ()))
                    nows
                end


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
                    Items.app_behind (!outfit) drawitem;
                    blitall(Vector.sub(Sprites.humps, !humpframe), screen, X_ROBOT, Y_ROBOT);
                    Items.app_infront (!outfit) drawitem;

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
                    (if !humpframe >= Vector.length Sprites.humps
                     then (humpframe := (Vector.length Sprites.humps - 1);
                           humprev := true)
                     else ())
                end

            and heartbeat () =
                let
                    val () = Song.update ()
                    val () = Womb.maybenext womb_pattern
                    val () = loopplay ()
                    val now = getticks ()
                in
                    if now > !nexta
                    then (advance();
                          nexta := now + MENUTICKS)
                    else ()
                end

            val WIDTH = 256 - 16
            fun itemheight _ = FontSmall.height + 1
            fun drawitem (item, x, y, sel) =
                let in
                    (case item of
                         NONE => FontSmall.draw(screen, x + (FontSmall.width - FontSmall.overlap) * 3, y, "^1Save outfit")
                       | SOME item =>
                          let in
                             (if Items.has (!outfit) item
                              then FontSmall.draw(screen, x, y, Chars.CHECKMARK)
                              else ());
                             FontSmall.draw(screen, x + (FontSmall.width - FontSmall.overlap) * 3, y, Items.name item)
                          end)
                end

            fun repeat () =
                (case LM.select { x = 8, y = 90,
                                  width = WIDTH,
                                  height = 200,
                                  items = NONE :: map SOME closet,
                                  drawitem = drawitem,
                                  itemheight = itemheight,
                                  bgcolor = SOME LM.DEFAULT_BGCOLOR,
                                  selcolor = SOME (SDL.color (0wx44, 0wx44, 0wx77, 0wxFF)),
                                  bordercolor = SOME LM.DEFAULT_BORDERCOLOR,
                                  parent = Drawable.drawable { draw = draw, heartbeat = heartbeat,
                                                               resize = Drawable.don't }
                                  } of
                     NONE => raise Abort
                   | SOME NONE => raise Done
                   | SOME (SOME item) =>
                         let in
                             (if Items.has (!outfit) item
                              then outfit := Items.remove (!outfit) item
                              else outfit := Items.add (!outfit) item);
                             (* XXX should keep current position in list, rather
                                than jump to the top.*)
                             repeat ()
                         end)

        in
            (repeat ()
             handle Done =>
                 let in
                     Profile.setoutfit profile (!outfit);
                     Profile.save ()
                 end
                  | Abort => ());

            Sound.all_off ()
        end

end
