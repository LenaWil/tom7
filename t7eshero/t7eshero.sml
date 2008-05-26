
(* Tom 7 Entertainment System Hero! *)

(* FIXME On Windows, Check that SDL_AUDIODRIVER is dsound otherwise
   this is unusable because of latency *)

structure T7ESHero =
struct

  open SDL
  val itos = Int.toString
  type ptr = MLton.Pointer.t
  infixr 9 `
  fun a ` b = a b

  exception Nope and Exit
  val Hero = Hero.Hero

  fun messagebox s = print (s ^ "\n")

  (* Comment this out on Linux, or it will not link *)
  local
      val mb_ = _import "MessageBoxA" : ptr * string * string * ptr -> unit ;
  in
      fun messagebox s = mb_(MLton.Pointer.null, s ^ "\000", "Message!\000", 
                             MLton.Pointer.null)
  end

  val width = 256
  val height = 600

  val FINGERS = 5
    
  (* distance of nut (on-tempo target bar) from bottom of screen *)
  val NUTOFFSET = 127

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  (* FIXME INSTANCE *)
  (* XXX This should be smarter: Derived from tempo or at least saved somewhere. *)
  (* number of SDL ticks per midi tick. *)
  val SLOWFACTOR =
    (case map Int.fromString (CommandLine.arguments ()) of
       [_, SOME t] => t
     | _ => 5)

  val screen = makescreen (width, height)

  (* XXX assumes joystick 0 *)
(*
  val _ = Util.for 0 (Joystick.number () - 1)
      (fn x => messagebox ("JOY " ^ Int.toString x ^ ": " ^ Joystick.name x ^ "\n"))
*)

  (* just enable all joysticks. If there are no joysticks, then you cannot play. *)
  val () = Util.for 0 (Joystick.number () - 1) Joystick.openjoy
  val () = Joystick.setstate Joystick.ENABLE

  fun requireimage s =
    case Image.load s of
      NONE => (print ("couldn't open " ^ s ^ "\n");
               raise Nope)
    | SOME p => p

  val solid = requireimage "testgraphics/solid.png"

  val background = requireimage "testgraphics/background.png"
  val backlite   = requireimage "testgraphics/backlite.png"

  val stars = Vector.fromList
      [requireimage "testgraphics/greenstar.png",
       requireimage "testgraphics/redstar.png",
       requireimage "testgraphics/yellowstar.png",
       requireimage "testgraphics/bluestar.png",
       requireimage "testgraphics/orangestar.png"]

  val hammers = Vector.fromList
      [requireimage "testgraphics/greenhammer.png",
       requireimage "testgraphics/redhammer.png",
       requireimage "testgraphics/yellowhammer.png",
       requireimage "testgraphics/bluehammer.png",
       requireimage "testgraphics/orangehammer.png"]

  val zaps = Vector.fromList
      [requireimage "zap1.png",
       requireimage "zap1.png",
       requireimage "zap2.png",
       requireimage "zap2.png",
       requireimage "zap3.png",
       requireimage "zap3.png",
       requireimage "zap4.png", (* XXX hack attack *)
       requireimage "zap4.png"]

  val missed = requireimage "testgraphics/missed.png"
  val hit = requireimage "testgraphics/hit.png"

  val STARWIDTH = surface_width (Vector.sub(stars, 0))
  val STARHEIGHT = surface_height (Vector.sub(stars, 0))
  val ZAPWIDTH = surface_width (Vector.sub(zaps, 0))
  val ZAPHEIGHT = surface_height (Vector.sub(zaps, 0))
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val blackfade = requireimage "testgraphics/blackfade.png"
  val robobox = requireimage "testgraphics/robobox.png"
  val blackall = alphadim blackfade
  val () = clearsurface(blackall, color (0w0, 0w0, 0w0, 0w255))

  val () = blitall(background, screen, 0, 0)

  structure Font = 
  FontFn (val surf = requireimage "testgraphics/fontbig.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          (* CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 
             BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
          val width = 18
          val height = 32
          val styles = 6
          val overlap = 2
          val dims = 3)

  structure FontHuge = 
  FontFn (val surf = requireimage "testgraphics/fonthuge.png"
          val charmap =
          " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
          "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          (* CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 
             BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
          val width = 27
          val height = 48
          val styles = 6
          val overlap = 3
          val dims = 3)

  val missnum = ref 0
  local 
      val misstime = ref 0

      fun sf () = Sound.setfreq(Sound.MISSCH, Sound.PITCHFACTOR * 4 * !misstime, 
                                10000, Sound.INST_SQUARE)
  in

      fun maybeunmiss t =
          if !misstime <= 0
          then Sound.setfreq(Sound.MISSCH, Sound.pitchof 60, 0, Sound.INST_NONE)
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
  end

  local
      val f = case CommandLine.arguments() of 
          st :: _ => st
        | _ => "totally-membrane.mid"
  in
      val (divi, thetracks) = Game.fromfile f
  end
  val divi = divi * SLOWFACTOR
  val PREDELAY = 2 * divi (* ?? *)

  (* FIXME INSTANCE *)
  (* XXX This should be configurable from the main menu and loaded from
     a settings file. *)
  (* For 360 X-Plorer guitar, which strangely swaps yellow and blue keys *)
  fun joymap 0 = 0
    | joymap 1 = 1
    | joymap 3 = 2
    | joymap 2 = 3
    | joymap 4 = 4
    | joymap _ = 999 (* XXX *)

  datatype label = datatype Match.label

  (* This gives access to the stream of song events. There is a single
     universal notion of "now" which updates at a constant pace. This
     gives us a cursor into song events that we use for e.g.
     controlling the audio subsystem.

     It is also possible to create cursors that work at a fixed offset
     (positive or negative) from "now". For example, we want to draw
     notes that have already occured, so that we can show status about
     them. We also want to be able to perform the matching algorithm
     over a small window of notes in the past and future.

     *)
  structure Song :
  sig
      type cursor
      (* give offset in ticks. A negative offset cursor displays events
         from the past. *)
      val cursor : int -> (int * (label * MIDI.event)) list -> cursor

          
      (* get the events that are occurring now or which this cursor has
         already passed. Advances the cursor to immediately after the
         events. *)
      val nowevents : cursor -> (label * MIDI.event) list

      (* show the upcoming events from the cursor's perspective. *)
      val look : cursor -> (int * (label * MIDI.event)) list

      (* How many ticks are we behind real time? Always non-negative.
         Always 0 after calling nowevents, look, or cursor, until
         update is called again. *)
      val lag : cursor -> int

      (* Initializes the local clock. *)
      val init : unit -> unit

      (* Updates the local clock from the wall clock. Call as often as
         desired. Time does not advance between calls to this, for
         synchronization across cursors. *)
      val update : unit -> unit

      (* Advance the given number of ticks, as if time had just
         non-linearly done that. Implies an update. *)
      val fast_forward : int -> unit

      (* Absolute real-time since calling init *)
      val now : unit -> int

  end =
  struct

      (* allow fast forwarding into the future *)
      val skip = ref 0
      val now = ref 0
      val started = ref 0
      fun update () = now := (Word32.toInt (getticks ()) + !skip)
      fun fast_forward n = skip := !skip + n

      type cursor = { lt : int ref, evts : (int * (label * MIDI.event)) list ref }
      fun lag { lt = ref n, evts = _ } = !now - n

      (* move the cursor so that lt is now, updating the events as
         needed. *)
      (* The cursor is looking at time 'lt', and now it is 'now'. The
         events in the track are measured as deltas from lt. We
         want to play any event that was late (or on time): that
         occurred between lt and now. This is the case when the delta time
         is less than or equal to (now - lt).

         There may be many such events, each measured as a delta from the
         previous one. For example, we might have

                        now = 17
           1 1  2   5   |
           -A-B- -C- - -v- -D
          . : . : . : . : . :
          ^
          |
          lt = 10

          We want to emit events A-C, and reduce the delta time on D to 2,
          then continue with lt=now. To do so, we call the period of time
          left to emit the 'gap'; this begins as now - lt = 7.

          We then emit any events with delta time less than the gap,
          reducing the gap as we do so. (We can think of this as also
          updating lt. Instead we just set lt to now when we finish
          with the gap.)

          When the gap is too small to include the next event, we reduce
          its delta time by the remaining gap amount to restore the
          representation invariant for the cursor. *)
      fun nowevents { lt, evts } =
          let
              (* returns the events that are now. modifies evts ref *)
              fun ne gap ((dt, (label, evt)) :: rest) =
                  if dt <= gap
                  then (label, evt) :: ne (gap - dt) rest

                  (* the event is not ready yet. it must be measured as a
                     delta from 'now' *)
                  else (evts := (dt - gap, (label, evt)) :: rest; nil)

                (* song will end on next trip *)
                | ne _ nil = (evts := nil; nil)

              (* sets evts to the tail, returns now events *)
              val ret = ne (!now - !lt) (!evts)
          in
              (* up to date *)
              lt := !now;
              ret
          end
          
      (* It turns out this offset is just a modification to the the delta
         for the first event. If we are pushing the cursor into the past,
         then the offset will be negative, which corresponds to a larger
         delta (wait longer). If we're going to the future, then we're
         reducing the delta. The delta could become negative. If so, we
         are skipping those events. The nowevents function gives us the
         events that are occurring now or that have already passed, so if
         we call that and discard them, our cursor will be at the appropriate
         future position. *)
      fun cursor off nil = { lt = ref (!now), evts = ref nil }
        | cursor off ((d, e) :: song) = 
          let val c = { lt = ref 0, evts = ref ((d - off, e) :: song) }
          in
              ignore (nowevents c);
              c
          end

      fun look (c as { lt = _, evts }) =
          let in
              (* get rid of anything that has passed *)
              ignore (nowevents c);
              !evts
          end

      fun init () =
          let in
              update();
              started := !now
          end

      (* shadowing for export *)
      val now = fn () => !now - !started
  end


  structure State =
  struct

    (* Player input *)
    val fingers = Array.array(FINGERS, false) (* all fingers start off *)

    (* Is there a sustained note on this finger (off the bottom of the screen,
       not the nut)? *)
    val spans = Array.array(FINGERS, false) (* and not in span *)


    fun fingeron n = 
        let 
            fun highest i =
                if i = FINGERS
                then Match.input (Song.now (), Hero.FingerDown n)
                else
                    if Array.sub(fingers, i)
                    then ()
                    else highest (i + 1)
        in
            Array.update(fingers, n, true);
            (* if there are no fingers higher than this, 
               then it can be a hammer event. *)
            highest (n + 1)
        end
    
    fun fingeroff n =
        let 
            fun belowit i =
                if i < 0
                then ()
                else if Array.sub(fingers, i)
                     (* it's the finger below that is pulled off to *)
                     then Match.input (Song.now (), Hero.FingerUp i)
                     else belowit (i - 1)
        in
            Array.update(fingers, n, false);
            belowit (n - 1)
        end

    fun commit () =
        let 
            fun theevent i =
                if i = FINGERS
                then nil
                else
                    if Array.sub(fingers, i)
                    then i :: theevent (i + 1)
                    else theevent (i + 1)
        in
            Match.input (Song.now (), Hero.Commit (theevent 0))
        end

    (* ? *)
    fun commitup () = ()

  end

  (* PERF could keep 'lastscene' and only draw changes? *)
  (* This is the description of what is currently displayed. *)
  structure Scene =
  struct

    val TICKSPERPIXEL = 2
    (* how many ticks forward do we look? *)
    val MAXAHEAD = 960
    (* how many MIDI ticks in the past do we draw? *)
    val DRAWLAG = NUTOFFSET * TICKSPERPIXEL

    val BEATCOLOR    = color(0wx77, 0wx77, 0wx77, 0wxFF)
    val MEASURECOLOR = color(0wxDD, 0wx22, 0wx22, 0wxFF)
    val TSCOLOR      = color(0wx22, 0wxDD, 0wx22, 0wxFF)
    val starpics = stars

    (* color, x, y *)
    val stars = ref nil : (int * int * int * Match.scoreevt) list ref
    (* rectangles the liteup background to draw. x,y,w,h *)
    val spans = ref nil : (int * int * int * int) list ref
    (* type, y, message, height *)
    val bars  = ref nil : (color * int * string * int) list ref

    val texts = ref nil : (string * int) list ref
      
    (* XXX strum, etc. *)

    fun clear () =
      let in
        stars := nil;
        spans := nil;
        bars  := nil;
        texts := nil
      end

    val mynut = 0

    fun addstar (finger, stary, evt) =
      (* XXX fudge city *)
      stars := 
      (finger,
       (STARWIDTH div 4) +
       6 + finger * (STARWIDTH + 18),
       (* hit star half way *)
       (height - (mynut + STARHEIGHT div TICKSPERPIXEL)) - (stary div TICKSPERPIXEL),
       evt) :: !stars

    fun addtext (s, t) =
        let in
            missnum := 0; (* FIXME hack city *)
            texts := (s, (height - mynut) - (t div TICKSPERPIXEL)) :: !texts
        end

    fun addbar (b, t) = 
      let 
        val (c, s, h) = 
          case b of
            Hero.Beat => (BEATCOLOR, "", 2)
          | Hero.Measure => (MEASURECOLOR, "", 5)
          | Hero.Timesig (n, d) => (TSCOLOR, "^3" ^ Int.toString n ^ "^0/^3" ^ Int.toString d ^ "^4 time", 8)
      in
          bars := (c, (height - mynut) - (t div TICKSPERPIXEL), s, h) :: !bars
      end

    fun addspan (finger, spanstart, spanend) =
      spans :=
      (21 + finger * (STARWIDTH + 18), 
       (height - mynut) - spanend div TICKSPERPIXEL,
       18 (* XXX *),
       (spanend - spanstart) div TICKSPERPIXEL) :: !spans

    fun draw () =
      let in
        (* entire background first first *)
        blitall(background, screen, 0, 0);
        (* spans first *)

        app (fn (x, y, w, h) => blit(backlite, x, y, w, h, screen, x, y)) (!spans);

        (* tempo *)
        app (fn (c, y, s, h) => 
             if y < (height - NUTOFFSET)
             then 
                 let in
                     fillrect(screen, 16, y - (h div 2), width - 32, h, c);
                     FontHuge.draw(screen, 4, y - (h div 2) - FontHuge.height, s)
                 end
             else ()) (!bars);

        (* stars on top *)
        app (fn (f, x, y, e) => 
             let 
                 fun drawnormal () =
                     let in
                         if Match.hammered e
                         then blitall(Vector.sub(hammers, f), screen, x, y)
                         else blitall(Vector.sub(starpics, f), screen, x, y)
                     end
             in
                 (* blitall(Vector.sub(starpics, f), screen, x, y); *)

                 (* plus icon *)
                 (case Match.state e of
                      Hero.Missed => blitall(missed, screen, x, y)
                    | Hero.Hit n =>
                          if y >= ((height - NUTOFFSET) - (STARHEIGHT div 2))
                          then
                              (if !n >= Vector.length zaps
                               then ()
                               else (blitall(Vector.sub(zaps, !n), screen, 
                                             x - ((ZAPWIDTH - STARWIDTH) div 2),
                                             y - ((ZAPHEIGHT - STARHEIGHT) div 2));
                                     n := !n + 1))
                          else drawnormal ()
                    | _ => drawnormal ())
             end) (!stars);

        (* finger state *)
        Util.for 0 (FINGERS - 1)
        (fn i =>
         if Array.sub(State.fingers, i)
         then blitall(hit, screen, 
                      (STARWIDTH div 4) + 6 + i * (STARWIDTH + 18),
                      (height - NUTOFFSET) - (STARWIDTH div 2))
         else ());

        app (fn (s, y) =>
             if FontHuge.sizex_plain s > (width - 64)
             then Font.draw(screen, 4, y - Font.height, s) 
             else FontHuge.draw(screen, 4, y - FontHuge.height, s)) (!texts);

        if !missnum > 0
        then FontHuge.draw (screen, 4, height - (FontHuge.height + 6),
                            "^2" ^ Int.toString (!missnum) ^ " ^4 misses")
        else ()

      end
       
  end

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
                      | MIDI.NOTEON(ch, note, vel) => Sound.noteon (ch, note, 90 * vel, inst) 
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
          flip screen
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
      let in
          (case pollevent () of
               SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Exit
             | SOME E_Quit => raise Exit
             | SOME (E_KeyDown { sym = SDLK_i }) => Song.fast_forward 2000
             | SOME (E_KeyDown { sym = SDLK_o }) => Sound.transpose := !Sound.transpose - 1
             | SOME (E_KeyDown { sym = SDLK_p }) => Sound.transpose := !Sound.transpose + 1
             (* Assume joystick events are coming from the one joystick we enabled
                (until we have multiplayer... ;)) *)
             | SOME (E_JoyDown { button, ... }) => 
               let in
                   (* messagebox (Int.toString button); *)
                   State.fingeron (joymap button)
               end
             | SOME (E_JoyUp { button, ... }) => State.fingeroff (joymap button)
             | SOME (E_JoyHat { state, ... }) =>
               (* XXX should have some history here--we want to ignore events
                  triggered by left-right hat movements (those never happen
                  on the xplorer though) *)
               if Joystick.hat_up state orelse
                  Joystick.hat_down state
               then State.commit ()
               else State.commitup ()

             | _ => ()
               );

           Song.update ();
           loopfail failcursor;
           loopplay playcursor;
           loopdraw drawcursor;
           loop (playcursor, drawcursor, failcursor)
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
      fun getstarttime nil = (print "(TIME) no events?"; raise Hero "")
        | getstarttime ((0, (_, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) :: rest) = 
          ((n, d, cpc, bb), rest)
        | getstarttime ((0, evt) :: t) = 
        let val (x, rest) = getstarttime t
        in (x, (0, evt) :: rest)
        end
        | getstarttime (_ :: t) = (print ("(TIME) no 0 time events"); raise Hero "")

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

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  (* Label all of the tracks
     This uses the track's name to determine its label. *)
  fun label tracks =
      let
          fun foldin (data, tr) : (int * (label * MIDI.event)) list = 
              map (fn (d, e) => (d, (data, e))) tr

          fun onetrack (tr, i) =
            case findname tr of
                NONE => SOME ` foldin (Control, tr)
              | SOME "" => SOME ` foldin (Control, tr)
              | SOME name => 
                  (case CharVector.sub(name, 0) of
                       #"+" =>
                       SOME `
                       foldin
                       (case CharVector.sub (name, 1) of
                            #"Q" => Music (Sound.INST_SQUARE, i)
                          | #"W" => Music (Sound.INST_SAW, i)
                          | #"N" => Music (Sound.INST_NOISE, i)
                          | #"S" => Music (Sound.INST_SINE, i)
                          | _ => (print "?? expected S or Q or W or N\n"; raise Hero ""),
                            tr)

                     | #"!" =>
                       (case CharVector.sub (name, 1) of
                            #"R" =>
                              (* XXX only if this is the score we desire.
                                 (Right now we expect there's just one.) *)
                              SOME `
                              Match.initialize
                              (PREDELAY, SLOWFACTOR, (* XXX *)
                               map (fn i => 
                                    case Int.fromString i of
                                        NONE => raise Hero "bad tracknum in Score name"
                                      | SOME i => i) ` 
                               String.tokens (StringUtil.ischar #",")
                               ` String.substring(name, 2, size name - 2),
                               tr)
                          | _ => (print "I only support REAL score!"; raise Hero "real"))

                     | _ => (print ("confused by named track '" ^ 
                                    name ^ "'?? expected + or ! ...\n"); 
                             SOME ` foldin (Control, tr))
                       )
      in
          List.mapPartial (fn x => x) (ListUtil.mapi onetrack tracks)
      end

  val () =
      let
          val (tracks : (int * (label * MIDI.event)) list list) = label thetracks
          val tracks = slow (MIDI.merge tracks)
          val tracks = add_measures tracks
              
          val tracks = delay tracks
(*
  val () = app (fn (dt, (lab, evt)) =>
                let in
                  print ("dt: " ^ itos dt ^ "\n")
                end) tracks
*)

          val playcursor = Song.cursor 0 tracks
          val drawcursor = Song.cursor (0 - Scene.DRAWLAG) tracks
          val failcursor = Song.cursor (0 - Match.EPSILON) tracks
      in
          loop (playcursor, drawcursor, failcursor)
      end
    handle Hero.Hero s => messagebox ("hero error: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | Game.Game s => messagebox ("sdl error: " ^ s)
        | Exit => Match.dump ()
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
