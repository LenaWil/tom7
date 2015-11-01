
(* Configure sub-title screen. *)
functor ConfigureFn(val screen : SDL.surface) =
struct

  structure Font = Sprites.Font
  structure FontSmall = Sprites.FontSmall
  structure S = SDL
  datatype sdlk = datatype SDL.sdlk
  datatype event = datatype SDL.event
  structure Joystick = S.Joystick

  exception AbortConfigure and FinishConfigure

  structure LM = ListMenuFn(val screen = screen)
  structure TX = TextScroll(FontSmall)

  (* Configure should start by showing each of the connected devices by
     its name, then ask the user to send some input event on the
     device he wants to configure. Then we want to know what sort of
     instrument it should be configured as. (But for the keyboard, we
     should be able to configure it as a guitar and drums
     simultaneously, right?)

     *)

  val nexta = ref (0w0 : Word32.word)
  val nextd = ref (0w0 : Word32.word)

  fun heartbeat (loopplay : unit -> unit) () : unit =
      let
          val () = Song.update ()
          val () = loopplay ()
          val now = S.getticks ()
      in
          if now > !nexta
          then ((* advance(); *)
                nexta := now + Hero.MENUTICKS)
          else ()
      end

  and go input draw loopplay =
      let
          val () = heartbeat loopplay ()
          val () = input ()
          val now = S.getticks ()
      in
          (if now > !nextd
           then (draw ();
                 nextd := now + Hero.MENUTICKS;
                 S.flip screen)
           else ());
          go input draw loopplay
      end

  (* Once we've chosen a device, what kind of controller shall we configure it as? *)
  (* loopplay is called periodically, to play the background music. *)
  fun configure_how (loopplay : unit -> unit) device =
      let
          val YOFFSET = 160
          val HEIGHT = Sprites.height - YOFFSET

          (* XXX or both, for keyboard. *)
          datatype how = HGuitar | HDrums | HWomb | HWombBench
          (* XXX guitar graphic is too wide *)
          fun drawitem (HGuitar, x, y, _) = S.blitall (Sprites.guitar, screen, x - 6, y)
            | drawitem (HDrums, x, y, _) = S.blitall (Sprites.drums, screen, x, y)
              (* XXX womb graphic *)
            | drawitem (HWomb, x, y, _) = Font.draw (screen, x, y, "laser suspension womb")
            | drawitem (HWombBench, x, y, _) = Font.draw (screen, x, y, "womb ^1bench")
          fun draw () = S.blitall(Sprites.configure, screen, 0, 0);
          fun itemheight HGuitar = S.surface_height Sprites.guitar
            | itemheight HDrums = S.surface_height Sprites.drums
            | itemheight HWomb = Font.height
            | itemheight HWombBench = Font.height

          (* in case we cancel *)
          val old = Input.getmap device
          val () = Input.clearmap device

      in
          nexta := S.getticks();
          nextd := 0w0;
          (case LM.select { x = 0, y = YOFFSET,
                            width = Sprites.gamewidth,
                            height = HEIGHT,
                            items = [HGuitar, HDrums] @ (if Womb.already_found ()
                                                         then [HWomb, HWombBench] else nil),
                            drawitem = drawitem,
                            itemheight = itemheight,
                            bgcolor = SOME LM.DEFAULT_BGCOLOR,
                            selcolor = SOME (S.color (0wx44, 0wx44, 0wx77, 0wxFF)),
                            bordercolor = SOME LM.DEFAULT_BORDERCOLOR,
                            parent = Drawable.drawable { draw = draw,
                                                         heartbeat = heartbeat loopplay,
                                                         resize = Drawable.don't } } of
               NONE => ()
             | SOME HGuitar => configure_guitar loopplay device
             | SOME HDrums => configure_drums loopplay device
             | SOME HWomb => configure_womb loopplay device
             | SOME HWombBench => configure_wombbench loopplay device)
               handle AbortConfigure => Input.restoremap device old
      end

  (* Measure bandwidth of Womb.signal commands. *)
  and configure_wombbench (_ : unit -> unit) _ =
      let
          (* disable, because it also diddles bits *)
          fun loopplay () = ()
          val tx = TX.make { x = 0, y = 0,
                             width = Sprites.gamewidth, height = Sprites.height,
                             bordercolor = NONE,
                             bgcolor = NONE }

          val () = TX.clear tx
          val () = TX.write tx "Benchmark womb. Press key to exit.";

          val nwrites = ref 0
          val starttime = SDL.getticks()
          val data = ref 0wx12345
          val dirty = ref true
          fun accept e = raise FinishConfigure

          fun signal () =
              let in
                  data := Word32.*(!data, 0w31337);
                  data := Word32.xorb(!data, 0wx9876543);
                  data := Word32.orb(Word32.<< (!data, 0w3), Word32.>> (!data, 0w29));
                  data := Word32.+(!data, 0wx9999999);
                  Womb.signal_raw (!data);
                  nwrites := !nwrites + 1;
                  if (!nwrites mod 200) = 0
                  then
                      let val now = SDL.getticks()
                          val gap = Word32.toInt (now - starttime)
                      in TX.write tx ("^3" ^ Int.toString (!nwrites) ^ "^0 in " ^
                                      "^3" ^ Int.toString gap ^ "^2ms ^0 =" ^
                                      "^3" ^ Real.fmt (StringCvt.FIX (SOME 1)) (real gap / real (!nwrites)) ^
                                      "^2ms ^0ea.");
                          dirty := true
                      end
                  else ()
              end

          fun input () =
              case S.pollevent () of
                  SOME (E_KeyDown { sym = _ }) => raise AbortConfigure
                | SOME E_Quit => raise Hero.Exit
                | SOME _ => ()
                | NONE => ()

          fun draw () =
              if !dirty
              then
                  let in
                      S.blitall(Sprites.configure, screen, 0, 0);
                      TX.draw screen tx;
                      SDL.flip screen;
                      dirty := false
                  end
              else ()

          fun gogo () =
              let in
                  signal();
                  input();
                  draw();
                  gogo()
              end
      in
          (* never actually save. *)
          gogo() handle FinishConfigure => ()
      end

  (* don't care about womb's device; this is more for exploration *)
  and configure_womb (_ : unit -> unit) _ =
      let
          (* disable, because it also diddles bits *)
          fun loopplay () = ()

          val tx = TX.make { x = 0, y = 0, width = Sprites.gamewidth, height = Sprites.height,
                             bordercolor = NONE,
                             bgcolor = NONE }

          val () = TX.clear tx
          val () = TX.write tx "Config womb. Press key to cycle bit.";

          val bit = ref 0

          fun accept e = raise FinishConfigure

          fun signal () =
              let in
                  TX.write tx ("Bit #" ^ Int.toString (!bit));
                  Womb.signal_raw (Word32.<< (0w1, Word.fromInt (!bit)))
              end
          val () = signal ()

          fun input () =
              case S.pollevent () of
                  SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise AbortConfigure
                | SOME E_Quit => raise Hero.Exit
                | SOME (E_KeyDown { sym }) =>
                      let in
                         (* any other key advances bit. *)
                          bit := !bit + 1;
                          if (!bit > 32)
                          then bit := 0
                          else ();
                          signal ()
                      end
                | SOME _ => ()
                | NONE => ()

          fun draw () =
              let in
                  S.blitall(Sprites.configure, screen, 0, 0);
                  TX.draw screen tx
              end
      in
          (* never actually save. *)
          go input draw loopplay handle FinishConfigure => ()
      end

  (* XXX would be good if we could merge the following two, which were developed by
     cut and paste and have lots of duplicate code *)

  and configure_drums (loopplay : unit -> unit) device =
      let
          datatype phase = P_Button of int

          val configorder = Vector.fromList [Input.C_Drum 0,
                                             Input.C_Drum 1,
                                             Input.C_Drum 2,
                                             Input.C_Drum 3,
                                             Input.C_Drum 4]
              (* XXX and keypad, and buttons... *)
          val NINPUTS = Vector.length configorder

          val phase = ref (P_Button 0)

          val X_DRUMS = 0
          val Y_DRUMS = 300

          (* In these, 4 is the bass pedal. *)
          fun press 4 = Sprites.kick
            | press _ = Sprites.punch
          fun arrow 4 = Sprites.arrow_up
            | arrow _ = Sprites.arrow_down
          fun y_arrow 4 = 456
            | y_arrow n = 250

          fun x_arrow 4 = 145
            | x_arrow n = n * (220 div 4) + 32
          fun y_press 4 = 520
            | y_press n = 170
          fun x_press 4 = 80
            | x_press n = 20

          fun accept e =
              case !phase of
                  P_Button d =>
                      let in
                          Input.setmap device e (Vector.sub(configorder, d));
                          if d < (NINPUTS - 1)
                          then phase := P_Button (d + 1)
                          else raise FinishConfigure
                      end

          fun input () =
              case S.pollevent () of
                  SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise AbortConfigure
                | SOME E_Quit => raise Hero.Exit
                | SOME e =>
                      if Input.belongsto e device
                      then
                          (* we only support these events for "buttons" right now *)
                          (case e of
                               (* ignore up events; these are handled by input *)
                               E_KeyDown { sym } => accept (Input.Key sym)
                             | E_KeyUp _ => ()
                             | E_JoyDown { button, which = _ } => accept (Input.JButton button)
                             | E_JoyUp _ => ()
                             | E_JoyHat { hat, state, which = _ } =>
                                   if Joystick.hat_centered state
                                   then ()
                                   else accept (Input.JHat { hat = hat, state = state })
                             | _ => print "Unsupported event during configure.\n")
                      else print "Foreign event during configure.\n"
                | NONE => ()

          fun draw () =
              let
              in
                  S.blitall(Sprites.configure, screen, 0, 0);

                  case !phase of
                      P_Button d =>
                          let in
                              S.blitall (Sprites.drums, screen, X_DRUMS, Y_DRUMS);
                              S.blitall (press d, screen, x_press d, y_press d);
                              S.blitall (arrow d, screen, x_arrow d, y_arrow d);
                              (* XXX could print OKs for the ones already done *)
                              ()
                           end
              end

      in
          go input draw loopplay handle FinishConfigure => Input.save ()
      end

  (* loopplay is called periodically, to play the background music. *)
  and configure_guitar (loopplay : unit -> unit) device =
      let
          (* configure sub-menu *)
          val configorder = Vector.fromList [Input.C_Button 0,
                                             Input.C_Button 1,
                                             Input.C_Button 2,
                                             Input.C_Button 3,
                                             Input.C_Button 4,
                                             Input.C_StrumUp,
                                             Input.C_StrumDown]
          val NINPUTS = Vector.length configorder

          datatype phase =
              P_Button of int
            | P_Axes
            | P_Whammy

          val phase = ref (P_Button 0)

          type axis = { min : int, max : int }
          val axes = GrowArray.empty() : axis GrowArray.growarray
          val whammyaxis = ref NONE
          val whammy = ref { min = 32767, max = ~32768 }

          (* in case we cancel *)
          val old = Input.getmap device
          val () = Input.clearmap device

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
              case !phase of
                  P_Button d =>
                      let in
                          Input.setmap device e (Vector.sub(configorder, d));
                          if d < (NINPUTS - 1)
                          then phase := P_Button (d + 1)
                          else phase := P_Axes
                      end
                | P_Axes => phase := P_Whammy
                | P_Whammy => raise FinishConfigure


          fun input () =
              case S.pollevent () of
                  SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise AbortConfigure
                | SOME E_Quit => raise Hero.Exit
                | SOME e =>
                   (case !phase of
                     P_Button _ =>
                         if Input.belongsto e device
                         then
                             (* we only support these events for "buttons" right now *)
                             (case e of
                                  (* ignore up events; these are handled by input *)
                                  E_KeyDown { sym } => accept (Input.Key sym)
                                | E_JoyDown { button, which = _ } => accept (Input.JButton button)
                                | E_JoyHat { hat, state, which = _ } =>
                                      if Joystick.hat_centered state
                                      then ()
                                      else accept (Input.JHat { hat = hat, state = state })
                                | _ => print "Unsupported event during configure.\n")
                         else print "Foreign event during configure.\n"
                   | P_Axes =>
                         (* XXX maybe should skip this if device is a keyboard. *)
                         if Input.belongsto e device
                         then
                             (* we can only handle axis events here *)
                             (case e of
                                  E_JoyAxis { which, axis, v } =>
                                      let
                                          val {min, max} =
                                              if GrowArray.has axes axis
                                              then GrowArray.sub axes axis
                                              else { min = 32767, max = ~32768 }
                                      in
                                          print (Int.toString which ^ "/" ^ Int.toString axis ^ ": "
                                                 ^ Int.toString v ^ "\n");
                                          GrowArray.update axes axis { min = Int.min(min, v),
                                                                       max = Int.max(max, v) }
                                      end
                                | _ =>
                                      (case Input.map e of
                                           (* dummy arg to accept, unused *)
                                           SOME (_, Input.ButtonDown 0) => accept (Input.JButton 0)
                                         | _ => print "Non-axis event during axis configure.\n"))

                         else print "Foreign event during axes\n"

                    | P_Whammy =>
                            (* XXX maybe should skip this too if keyboard. *)
                            if Input.belongsto e device
                            then
                                (* we can only handle axis events here *)
                                (case e of
                                     E_JoyAxis { which, axis, v } =>
                                         (* must not have been configured already, or be a new axis
                                            if we already started configuring the whammy axis... *)
                                         if GrowArray.has axes axis orelse (case !whammyaxis of
                                                                                NONE => false
                                                                              | SOME a => axis <> a)
                                         then () (* Impossible to avoid dancing even when configuring *)
                                         else
                                             let val { min, max } = !whammy
                                             in
                                                 print (Int.toString which ^ "/" ^ Int.toString axis ^ ": "
                                                        ^ Int.toString v ^ "\n");
                                                 whammyaxis := SOME axis;
                                                 whammy := { min = Int.min(min, v),
                                                             max = Int.max(max, v) }
                                             end
                                   | _ =>
                                        (case Input.map e of
                                             (* dummy arg to accept, unused *)
                                             SOME (_, Input.ButtonDown 0) => accept (Input.JButton 0)
                                           | _ => print "Non-axis event during whammy configure.\n"))
                             else print "Foreign event during whammy\n")

                | NONE => ()

          fun draw () =
              let
              in
                  S.blitall(Sprites.configure, screen, 0, 0);

                  (case !phase of
                       P_Button d =>
                           let in
                               S.blitall(Sprites.guitar2x, screen, 0 - buttonpos d, Y_GUITAR);
                               S.blitall(case d of
                                             5 => Sprites.strum_up
                                           | 6 => Sprites.strum_down
                                           | _ => Sprites.press, screen, PRESS_OFFSET, Y_PRESS);
                               Util.for 0 (d - 1)
                               (fn x =>
                                S.blitall(Sprites.press_ok, screen,
                                          (0 - buttonpos d)
                                          + PRESS_OFFSET
                                          + buttonpos x, Y_OK))
                           end
                     | P_Axes =>
                           let
                               val X_MESSAGE = 10
                               val Y_MESSAGE = 100
                               val y = ref (Y_MESSAGE + Font.height * 3)
                           in
                               (* XXX should skip if device is a keyboard. *)
                               Font.draw (screen, X_MESSAGE, Y_MESSAGE, "Rotate the guitar,");
                               Font.draw (screen, X_MESSAGE, Y_MESSAGE + Font.height, "^2but no whammy");
                               Util.for 0 (GrowArray.length axes - 1)
                               (fn a =>
                                if GrowArray.has axes a
                                then let
                                         val {min, max} = GrowArray.sub axes a
                                     in
                                         FontSmall.draw(screen, X_MESSAGE, !y,
                                                        "^0" ^ Int.toString a ^ "^1: ^3" ^
                                                        Int.toString min ^ "^1 - ^3" ^
                                                        Int.toString max);
                                         y := !y + FontSmall.height + 1
                                     end
                                else ());
                               ()
                           end
                     | P_Whammy =>
                           let
                               val X_MESSAGE = 10
                               val Y_MESSAGE = 100
                               val y = Y_MESSAGE + Font.height * 3
                           in
                               (* XXX should skip if device is a keyboard. *)
                               Font.draw (screen, X_MESSAGE, Y_MESSAGE, "Push in and out the");
                               Font.draw (screen, X_MESSAGE, Y_MESSAGE + Font.height, "   ^4 whammy");

                               case (!whammyaxis, !whammy) of
                                   (SOME a, {min, max}) =>
                                       FontSmall.draw(screen, X_MESSAGE, y,
                                                      "^0" ^ Int.toString a ^ "^1: ^3" ^
                                                      Int.toString min ^ "^1 - ^3" ^
                                                      Int.toString max)
                                 | (NONE, _) =>
                                       FontSmall.draw(screen, X_MESSAGE, y,
                                                      "^2no whammy configured yet ^3 :(")
                           end)
              end
      in
          nexta := S.getticks();
          nextd := 0w0;
          go input draw loopplay
          handle FinishConfigure =>
              (* XXX should have some titlescreen message fade-out queue *)
              let
                  val uidx = ref 0
              in
                  (* save (unknown) axes. *)
                  Util.for 0 (GrowArray.length axes - 1)
                  (fn a =>
                   if GrowArray.has axes a
                   then let
                            val {min, max} = GrowArray.sub axes a
                        in
                            Input.setaxis device { which = a, axis = Input.AxisUnknown (!uidx),
                                                   min = min, max = max };
                            uidx := !uidx + 1
                        end
                   else ());
                  (* save whammy *)
                  case !whammyaxis of
                      NONE => ()
                    | SOME a => Input.setaxis device { which = a, axis = Input.AxisWhammy,
                                                       min = #min (!whammy), max = #max (!whammy) };

                  Input.save ()
              end
      end

  val configure = configure_how

end
