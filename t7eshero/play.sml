(* Actually playing a song. *)
structure Play =
struct

  datatype label = datatype Match.label
  structure Scene = SceneFn(val screen = Sprites.screen)
  exception Abort (* abort gameplay, return to menu *)

  val itos = Int.toString

  local
    val domiss = ref true
    val misstime = ref 0

    fun sf () =
        if !domiss
        then
            Sound.setfreq(Sound.MISSCH, Sound.PITCHFACTOR * 4 * !misstime,
                          Sound.midivel (7000 div 90),
                          Sound.WAVE_SQUARE)
        else ()
  in

    (* Maybe stop dying sound. *)
    fun maybeunmiss t =
        if !misstime <= 0
        then Sound.setfreq(Sound.MISSCH, Sound.pitchof 60, Sound.midivel 0, Sound.WAVE_NONE)
        else
            let in
                misstime := !misstime - t;
                sf ()
            end

    fun miss () =
        let in
            if !domiss then Stats.miss () else ();
            misstime := 300;
            sf ();
            maybeunmiss 0
        end

    fun setmiss b = domiss := b
  end

  exception EarlyExit

  (* This is the main loop. There are three mutually recursive functions.
     The loop function checks input and deals with it appropriately.
     The loopplay function plays the notes to the audio subsystem.
     The loopdraw function displays the score.

     The loopplay function wants to look at the note (event) that's happening next.
     But draw actually wants to see somewhat old events, so that it can show a little
     bit of history. Therefore the two functions are going to be looking at different
     positions in the same list of track events. *)
  fun loopplay cursor =
      let
          val nows = Song.nowevents cursor


          fun noteon (ch, note, vel, inst) =
              let in
                  Womb.liteson[Vector.sub(Womb.leds, note mod Vector.length Womb.leds),
                               Vector.sub(Womb.lasers, note mod Vector.length Womb.lasers)];
                  Sound.noteon (ch, note, Sound.midivel vel, inst)
              end
          fun noteoff (ch, note) =
              let in
                  Womb.litesoff [Vector.sub(Womb.leds, note mod Vector.length Womb.leds),
                                 Vector.sub(Womb.lasers, note mod Vector.length Womb.lasers)];
                  Sound.noteoff (ch, note)
              end
      in
          List.app
          (fn (label, evt) =>
           case label of
               Music (inst, track) =>
                   (case evt of
                        MIDI.NOTEON(ch, note, 0) => noteoff (ch, note)
                      | MIDI.NOTEON(ch, note, vel) => noteon (ch, note, vel, inst)
                      | MIDI.NOTEOFF(ch, note, _) => noteoff (ch, note)
                      | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
             (* otherwise no sound..? *)
             | Control =>
                   (case evt of
                        (* http://jedi.ks.uiuc.edu/~johns/links/music/midifile.html *)
                        MIDI.META (MIDI.TEMPO n) => print ("TEMPO " ^ itos n ^ "\n")
                      | MIDI.META (MIDI.TIME (n, d, cpc, bb)) =>
                            let in
                                print ("myTIME " ^ itos n ^ "/" ^ itos (Util.pow 2 d) ^ "  @ "
                                       ^ itos cpc ^ " bb: " ^ itos bb ^ "\n");
                                Scene.settimesig (n, Util.pow 2 d)
                            end
                      | _ => print ("unknown ctrl event: " ^ MIDI.etos evt ^ "\n"))
             | Bar _ => () (* XXX could play metronome click *)
             | Score _ => ())
          nows
      end

  val DRAWTICKS = (* 128 *) 12
  fun loopdraw cursor =
      if Song.lag cursor >= DRAWTICKS
      then
        let
          val () = Scene.clear ()

          (* We have to keep track of a bit of state for each finger: whether we are
             currently in a span for that one. *)
          val () =
              List.app
              (fn (label, evt) =>
               (case label of
                    Score _ =>
                        (case evt of
                             (* XXX should ensure note in bounds *)
                             MIDI.NOTEON (ch, note, 0) => Array.update(State.spans, note, false)
                           | MIDI.NOTEON (ch, note, _) => Array.update(State.spans, note, true)
                           | MIDI.NOTEOFF(ch, note, _) => Array.update(State.spans, note, false)
                           | _ => ())

                  (* tempo here? *)
                  | _ => ())) (Song.nowevents cursor)

          (* spans may be so long they run off the screen. We use the state information
             maintained above. *)
          val spans = Array.tabulate(5, fn f =>
                                     if Array.sub(State.spans, f)
                                     then SOME 0
                                     else NONE)

          fun emit_span finger (spanstart, spanend) =
            let in
              (*
              print ("addspan " ^ itos finger ^ ": "
              ^ itos spanstart ^ " -> " ^ itos (Int.min(MAXAHEAD, spanend)) ^ "\n");
              *)
              Scene.addspan (finger, spanstart, Int.min(Scene.MAXAHEAD, spanend))
            end

          (* val () = print "----\n" *)

          fun draw _ nil =
              (* Make sure that we only end a span if it's started *)
              Array.appi (fn (finger, SOME spanstart) => emit_span finger (spanstart, Scene.MAXAHEAD)
                  | _ => ()) spans

            | draw when (track as ((dt, (label, e)) :: rest)) =
              if when + dt > Scene.MAXAHEAD
              then draw when nil
              else
                let
                  val tiempo = when + dt
                in
                  (case label of
                     Music _ => ()
                   | Score scoreevt =>
                         let
                           fun doevent (MIDI.NOTEON (x, note, 0)) =
                                 doevent (MIDI.NOTEOFF (x, note, 0))
                             | doevent (MIDI.NOTEOFF (_, note, _)) =
                                 let val finger = note mod 5
                                 in
                                     (case Array.sub(spans, finger) of
                                        NONE => (* print "ended span we're not in?!\n" *) ()
                                      | SOME ss => emit_span finger (ss, tiempo));

                                     Array.update(spans, finger, NONE)
                                 end
                             | doevent (MIDI.NOTEON (_, note, vel)) =
                                 let val finger = note mod 5
                                 in
                                     Scene.addstar (finger, tiempo, scoreevt);

                                     (* don't emit--we assume proper bracketing
                                        as produced by genscore. (This won't
                                        necessarily be the case for arbitrary
                                        MIDI files.) *)
                                     Array.update(spans, finger, SOME tiempo)
                                 end
                             | doevent _ = ()
                         in doevent e
                         end
                   | Bar b => Scene.addbar(b, tiempo)
                         (* otherwise... ? *)
                   | Control =>
                         (case e of
                              MIDI.META (MIDI.MARK m) =>
                                  if size m > 0 andalso String.sub(m, 0) = #"#"
                                  then Scene.addtext(String.substring(m, 1, size m - 1), tiempo)
                                  else ()
                            | _ => ())

                         );

                     draw tiempo rest
                end
        in
          draw 0 (Song.look cursor);
          Scene.draw ();
          SDL.flip Sprites.screen
        end
      else ()

  fun loopfail cursor =
      let
          val () = maybeunmiss (Song.lag cursor)
          val nows = Song.nowevents cursor
      in
          List.app (fn (_, MIDI.NOTEON(_, _, 0)) => ()
                     | (Score se, MIDI.NOTEON(x, note, vel)) =>
                       (case Match.state se of
                             Hero.Hit _ => ()
                           | Hero.Missed => () (* how would we have already decided this? *)
                           | Hero.Future =>
                                 let in
                                     Match.endstreak ();
                                     (* play a noise *)
                                     miss ();
                                     Match.setstate se Hero.Missed
                                 end)
                     | _ => ()) nows
      end

  fun loop (playcursor, drawcursor, failcursor) =
      let

          fun polls () =
              case SDL.pollevent () of
                  SOME e =>
                      let in
                        (case e of
                             SDL.E_KeyDown { sym = SDL.SDLK_ESCAPE } => raise Abort
                                 (* Skip to end of song, for show emergencies. *)
                           | SDL.E_KeyDown { sym = SDL.SDLK_n } => raise EarlyExit
                           | SDL.E_Quit => raise Hero.Exit
                           | e =>
                               (* Currently, allow events from any device to be for Player 1, since
                                  there is only one player. *)
                               (case Input.map e of
                                    SOME (_, Input.ButtonDown b) => State.fingeron b
                                  | SOME (_, Input.ButtonUp b) => State.fingeroff b
                                  | SOME (_, Input.StrumUp) => (State.upstrum(); State.commit ())
                                  | SOME (_, Input.StrumDown) => (State.downstrum(); State.commit ())
                                  | SOME (_, Input.Axis (Input.AxisUnknown i, r)) => State.dance (i, r)
                                  | SOME (_, Input.Axis (Input.AxisWhammy, r)) => Sound.seteffect r
                                  | SOME (_, Input.Drum d) =>
                                        Sound.setfreq(Sound.DRUMCH d,
                                                      Vector.sub(Samples.default_drumbank, d),
                                                      Sound.midivel 127,
                                                      Sound.WAVE_SAMPLER Samples.sid)
                                  (* | SOME _ => () *)
                                  | NONE =>
                                      (* only if not mapped *)
                                      (case e of
                                           (SDL.E_KeyDown { sym = SDL.SDLK_i }) => Song.fast_forward 2000
                                         | (SDL.E_KeyDown { sym = SDL.SDLK_o }) => Sound.transpose := !Sound.transpose - 1
                                         | (SDL.E_KeyDown { sym = SDL.SDLK_p }) => Sound.transpose := !Sound.transpose + 1
                                         | _ => ())));
                          polls ()
                      end
                | NONE => ()
      in
           polls ();
           Song.update ();
           loopfail failcursor;
           loopplay playcursor;
           Womb.heartbeat ();
           loopdraw drawcursor;

           (* failcursor is the last cursor, so when it's done, we're done. *)
           if Song.done failcursor
           then ()
           else loop (playcursor, drawcursor, failcursor)
      end handle EarlyExit => ()

end