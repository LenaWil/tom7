
(* Configure sub-title screen. *)
functor ConfigureFn(val screen : SDL.surface) =
struct

  structure Font = Sprites.Font
  structure FontSmall = Sprites.FontSmall
  structure S = SDL
  datatype sdlk = datatype SDL.sdlk
  datatype event = datatype SDL.event
  structure Joystick = S.Joystick

  (* configure sub-menu *)
  val configorder = Vector.fromList [Input.C_Button 0,
                                     Input.C_Button 1,
                                     Input.C_Button 2,
                                     Input.C_Button 3,
                                     Input.C_Button 4,
                                     Input.C_StrumUp,
                                     Input.C_StrumDown]
  val NINPUTS = Vector.length configorder

  (* Configure should start by showing each of the connected devices by
     its name, then ask the user to send some input event on the
     device he wants to configure. Then we want to know what sort of
     instrument it should be configured as. (But for the keyboard, we
     should be able to configure it as a guitar and drums
     simultaneously, right?)

     *)

  (* loopplay is called periodically, to play the background music. *)
  fun configure (loopplay : unit -> unit) device =
      let
          exception AbortConfigure and FinishConfigure
          datatype phase =
              P_Button of int
            | P_Axes

          val phase = ref (P_Button 0)

          type axis = { min : int, max : int }
          val axes = GrowArray.empty() : axis GrowArray.growarray

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
                | P_Axes => raise FinishConfigure


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

                         else print "Foreign event during axes\n")
                | NONE => ()

          (* nothin' doin' *)
          fun advance () = ()
          fun draw () =
              let
              in
                  S.blitall(Sprites.configure, screen, 0, 0);

                  (case !phase of
                       P_Button d =>
                           let in
                               S.blitall(Sprites.guitar, screen, 0 - buttonpos d, Y_GUITAR);
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
                           end)
              end

          val nexta = ref (S.getticks ())
          fun heartbeat () = 
              let 
                  val () = Song.update ()
                  val () = loopplay ()
                  val now = S.getticks ()
              in
                  if now > !nexta
                  then (advance();
                        nexta := now + Hero.MENUTICKS)
                  else ()
              end

          val nextd = ref 0w0
          fun go () =
              let 
                  val () = heartbeat ()
                  val () = input ()
                  val now = S.getticks ()
              in
                  (if now > !nextd
                   then (draw (); 
                         nextd := now + Hero.MENUTICKS;
                         S.flip screen)
                   else ());
                  go ()
              end
      in
          go () handle AbortConfigure => Input.restoremap device old
                       (* XXX should have some titlescreen message fade-out queue *)
                     | FinishConfigure => 
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
                  (* XXX should save whammy here too *)
                  Input.save ()
              end
      end

end
