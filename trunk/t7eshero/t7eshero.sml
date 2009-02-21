
(* Tom 7 Entertainment System Hero! *)

(* FIXME On Windows, Check that SDL_AUDIODRIVER is dsound otherwise
   this is unusable because of latency *)

structure T7ESHero =
struct

  structure S = SDL
  val itos = Int.toString
  type ptr = MLton.Pointer.t
  infixr 9 `
  fun a ` b = a b

  val Hero = Hero.Hero
  val Exit = Hero.Exit
  exception Abort (* abort gameplay, return to menu *)

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  val messagebox = Hero.messagebox

  (* just enable all joysticks. If there are no joysticks, then you cannot play. *)
  val () = Input.register_all ()
  val () = Input.load () handle Input.Input s => messagebox ("input file error: " ^ s)
  val () = Items.load ()

  val missnum = ref 0
  local 
      val misstime = ref 0

      fun sf () = 
          (*  FIXME XXXX restore me, just wanna play around without damage
          Sound.setfreq(Sound.MISSCH, Sound.PITCHFACTOR * 4 * !misstime, 
                        Sound.midivel (10000 div 90),
                        Sound.WAVE_SQUARE) *)
          ()
  in

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
              missnum := !missnum + 1;
              misstime := 300;
              sf ();
              maybeunmiss 0
          end

      fun reset_miss () = 
          let in
              misstime := 0;
              missnum := 0
          end
  end

  structure Title = TitleFn(val screen = Sprites.screen)


  structure Scene = SceneFn(val screen = Sprites.screen
                            val missnum = missnum)


  (* The game loop shows the title, plays the selected song,
     then shows postmortem, then returns back to the title. *)
  fun gameloop () =
  let
    val () = reset_miss ()
    val () = State.reset ()


    val (song, diff, profile) =
        let
            val { song : Setlist.songinfo,
                  difficulty : Hero.difficulty,
                  profile : Profile.profile } = Title.loop ()
        in
            (song, difficulty, profile)
        end

    (* XXX should pull these out of the song as needed, I think? *)
    val songid = #id song
    val SLOWFACTOR = #slowfactor song

    val (divi, thetracks) = Game.fromfile (#file song)
    val divi = divi * SLOWFACTOR
    val PREDELAY = 2 * divi (* ?? *)


    datatype label = datatype Match.label

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
        in
            List.app 
            (fn (label, evt) =>
             case label of
                 Music (inst, track) =>
                     (case evt of
                          MIDI.NOTEON(ch, note, 0) => Sound.noteoff (ch, note)
                        | MIDI.NOTEON(ch, note, vel) => Sound.noteon (ch, note, 
                                                                      Sound.midivel vel, inst) 
                        | MIDI.NOTEOFF(ch, note, _) => Sound.noteoff (ch, note)
                        | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
               (* otherwise no sound..? *) 
               | Control =>
                     (case evt of
                          (* http://jedi.ks.uiuc.edu/~johns/links/music/midifile.html *)
                          MIDI.META (MIDI.TEMPO n) => print ("TEMPO " ^ itos n ^ "\n")
                        | MIDI.META (MIDI.TIME (n, d, cpc, bb)) =>
                              print ("myTIME " ^ itos n ^ "/" ^ itos (Util.pow 2 d) ^ "  @ "
                                     ^ itos cpc ^ " bb: " ^ itos bb ^ "\n")
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
            S.flip Sprites.screen
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
                                       (* play a noise *)
                                       miss ();
                                       Match.setstate se Hero.Missed
                                   end)
                       | _ => ()) nows
        end

    fun loop (playcursor, drawcursor, failcursor) =
        let 
            
            fun polls () =
                case S.pollevent () of
                    SOME e =>
                        let in
                            (case e of
                                 S.E_KeyDown { sym = S.SDLK_ESCAPE } => raise Abort
                               | S.E_Quit => raise Exit
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
                                                   (S.E_KeyDown { sym = S.SDLK_i }) => Song.fast_forward 2000
                                                 | (S.E_KeyDown { sym = S.SDLK_o }) => Sound.transpose := !Sound.transpose - 1
                                                 | (S.E_KeyDown { sym = S.SDLK_p }) => Sound.transpose := !Sound.transpose + 1
                                                 | _ => ())));
                              polls ()
                        end
                  | NONE => ()
        in
             polls ();
             Song.update ();
             loopfail failcursor;
             loopplay playcursor;
             loopdraw drawcursor;

             (* failcursor is the last cursor, so when it's done, we're done. *)
             if Song.done failcursor
             then ()
             else loop (playcursor, drawcursor, failcursor)
        end

    (* In an already-labeled track set, add measure marker events. *)
    fun add_measures t =
      let
        (* Read through tracks, looking for TIME events in
           Control tracks. 
           Each TIME event starts a measure, naturally.
           We need to find one at 0 time, otherwise this is
           impossible:
           *)
        fun getstarttime nil = (messagebox "(TIME) no events?"; raise Hero "")
          | getstarttime ((0, (_, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) :: rest) = 
            ((n, d, cpc, bb), rest)
          | getstarttime ((0, evt) :: t) = 
          let val (x, rest) = getstarttime t
          in (x, (0, evt) :: rest)
          end
          | getstarttime (_ :: t) = (messagebox ("(TIME) no 0 time events"); raise Hero "")

        val ((n, d, cpc, bb), rest) = getstarttime t

        val () = if bb <> 8 
                 then (messagebox ("The MIDI file may not redefine 32nd notes!");
                       raise Hero "")
                 else ()

        (* We ignore the clocksperclick, which gives the metronome rate. Even
           though this is ostensibly what we want, the values are fairly
           unpredictable. *)

        (* First we determine the length of a measure in midi ticks. 

           The midi division tells us how many clicks there are in a quarter note.
           The denominator tells us how many beats there are per measure. So we can
           first compute the number of midi ticks in a beat:
           *)

        val beat =
          (* in general  divi/(2^(d-2)), but avoid using fractions
             by special casing the d < 2 *)
          case d of
            (* n/1 time *)
            0 => divi * 4
            (* n/2 time: half notes *)
          | 1 => divi * 2
            (* n/4 time, n/8 time, etc. *)
          | _ => divi div (Util.pow 2 (d - 2))

        val () = print ("The beat value is: " ^ Int.toString beat ^ "\n")

        val measure = n * beat
        val () = print ("And the measure value is: " ^ Int.toString measure ^ "\n")

        (* XXX would be better if we could also additionally label the beats when
           using a complex time, like for sensations: 5,5,6,5. Instead we just
           put one minor bar for each beat. *)

        (* For now the beat list is always [1, 1, 1, 1 ...] so that we put
           a minor bar on every beat. *)
        val beatlist = List.tabulate (n, fn _ => 1)

        (* FIXME test *)
        (* val beatlist = [5, 5, 6, 5] *)

        (* number of ticks at which we place minor bars; at end we place a major one *)
        val ticklist = map (fn b => b * beat) beatlist

        fun ibars tl nil = nil (* XXX probably should finish out
                                  the measure, draw end bar. *)

          | ibars (ticksleft :: rtl) ((dt, evt) :: rest) = 
          (* Which comes first, the next event or our next bar? *)
          if dt <= ticksleft
          then 
            (case evt of
               (* Time change event coming up! *)
               (Control, MIDI.META (MIDI.TIME _)) =>
               (* emit dummy event so that we can always start time changes with dt 0 *)
               (dt, (Control, DUMMY)) :: add_measures ((0, evt) :: rest)

             | _ => (dt, evt) :: ibars (ticksleft - dt :: rtl) rest)
          else 
            (* if we exhausted the list, then there is a major (measure) bar here. *)       
            (case rtl of
               nil => (ticksleft, (Bar Hero.Measure, DUMMY)) :: ibars ticklist ((dt - ticksleft, evt) :: rest)
             | _   => (ticksleft, (Bar Hero.Beat, DUMMY))    :: ibars rtl      ((dt - ticksleft, evt) :: rest))

          | ibars nil _ = raise Hero "tickslist never nil" (* 0/4 time?? *)

      in
        (0, (Control, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) ::
        (0, (Bar (Hero.Timesig (n, Util.pow 2 d)), DUMMY)) ::
        ibars ticklist rest
      end

    (* fun slow l = map (fn (delta, e) => (delta * 6, e)) l *)
    fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l

    (* How to complete pre-delay? *)
    fun delay t = (PREDELAY, (Control, DUMMY)) :: t

    val () =
        let
            val (tracks : (int * (label * MIDI.event)) list list) = 
                Game.label PREDELAY SLOWFACTOR thetracks
            val tracks = slow (MIDI.merge tracks)
            val tracks = add_measures tracks
            val (tracks : (int * (label * MIDI.event)) list) = delay tracks
            val () = Song.init ()
            val playcursor = Song.cursor 0 tracks
            val drawcursor = Song.cursor (0 - Scene.DRAWLAG) tracks
            val failcursor = Song.cursor (0 - Match.EPSILON) tracks

            val () = loop (playcursor, drawcursor, failcursor)

            (* Get postmortem statistics *)
            val () = Postmortem.loop (songid, profile, tracks)
        in
            ()
        end handle Abort => 
            let in
                (* should go FAILURE!!!! *)
                ()
            end
  in
      Sound.all_off ();
      Sound.seteffect 0.0;
      print "GAME END.\n";
      (* XXX highscores... *)
      gameloop () 
  end handle Hero.Hero s => messagebox ("hero error: " ^ s)
           | SDL.SDL s => messagebox ("sdl error: " ^ s)
           | Game.Game s => messagebox ("sdl error: " ^ s)
           | Items.Items s => messagebox ("items database error: " ^ s)
           | Input.Input s => messagebox ("input subsystem error: " ^ s)
           | Hero.Exit => ()
           | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

  (* and, begin. *)
  val () = gameloop ()
end
