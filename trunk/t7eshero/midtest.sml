
(* FIXME On Windows, Check that SDL_AUDIODRIVER is dsound otherwise
   this is unusable because of latency *)

structure Test =
struct

  fun messagebox s = print (s ^ "\n")

  (* Comment this out on Linux, or it will not link *)
(*
  local
      val mb_ = _import "MessageBoxA" : MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
  in
      fun messagebox s = mb_(MLton.Pointer.null, s ^ "\000", "Message!\000", MLton.Pointer.null)
  end
*)
  type ptr = MLton.Pointer.t

  exception Nope

  exception Test of string
  exception Exit

  open SDL

  val width = 256
  val height = 600

  val ROBOTH = 32
  val ROBOTW = 16
    
  (* distance of nut (on-tempo target bar) from bottom of screen *)
  val NUTOFFSET = 20

  val screen = makescreen (width, height)

  (* XXX these should describe what kind of track it is *)
  datatype label =
      Music of int
    | Control

  (* XXX assumes joystick 0 *)
(*
  val _ = Util.for 0 (Joystick.number () - 1)
      (fn x => messagebox ("JOY " ^ Int.toString x ^ ": " ^ Joystick.name x ^ "\n"))
*)

  (* XXX requires joystick! *)
(*
  val joy = Joystick.openjoy 0 
  val () = Joystick.setstate Joystick.ENABLE
*)
  (* just enable all joysticks. *)
  val () = Util.for 0 (Joystick.number () - 1) Joystick.openjoy
  val () = Joystick.setstate Joystick.ENABLE

  val initaudio_ = _import "ml_initsound" : unit -> unit ;
  val setfreq_ = _import "ml_setfreq" : int * int * int * int -> unit ;
  val () = initaudio_ ()

  fun requireimage s =
    case Image.load s of
      NONE => (print ("couldn't open " ^ s ^ "\n");
               raise Nope)
    | SOME p => p

  val robotr = requireimage "testgraphics/robot.png"
  val robotl = requireimage "testgraphics/robotl.png" (* XXX should be able to flip graphics *)
  val robotr_fade = alphadim robotr
  val robotl_fade = alphadim robotl
  val solid = requireimage "testgraphics/solid.png"

  val background = requireimage "testgraphics/background.png"
  val backlite   = requireimage "testgraphics/backlite.png"

  val stars = Vector.fromList
      [requireimage "testgraphics/greenstar.png",
       requireimage "testgraphics/redstar.png",
       requireimage "testgraphics/yellowstar.png",
       requireimage "testgraphics/bluestar.png",
       requireimage "testgraphics/orangestar.png"]
       
  val STARWIDTH = surface_width (Vector.sub(stars, 0))
  val STARHEIGHT = surface_height (Vector.sub(stars, 0))
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val blackfade = requireimage "testgraphics/blackfade.png"
  val robobox = requireimage "testgraphics/robobox.png"
  val blackall = alphadim blackfade
  val () = clearsurface(blackall, color (0w0, 0w0, 0w0, 0w255))

  val () = blitall(background, screen, 0, 0)

  datatype dir = UP | DOWN | LEFT | RIGHT
  datatype facing = FLEFT | FRIGHT

  val paused = ref false
  val advance = ref false

  (* note 60 is middle C = 256hz,
     so 0th note is 8hz.
     *)
(* XXX no floats on mingw, urgh
  val () = Control.Print.printLength := 10000
  fun pitchof n = Real.round ( 80000.0 * Math.pow (2.0, real n / 12.0) )
  val pitches = Vector.fromList (List.tabulate(128, pitchof))
*)

  (* in ten thousandths of a hertz *)
  val pitches = Vector.fromList
  [80000,84757,89797,95137,100794,106787,113137,119865,126992,134543,142544,
   151020,160000,169514,179594,190273,201587,213574,226274,239729,253984,
   269087,285088,302040,320000,339028,359188,380546,403175,427149,452548,
   479458,507968,538174,570175,604080,640000,678056,718376,761093,806349,
   854298,905097,958917,1015937,1076347,1140350,1208159,1280000,1356113,
   1436751,1522185,1612699,1708595,1810193,1917833,2031873,2152695,2280701,
   2416318,2560000,2712226,2873503,3044370,3225398,3417190,3620387,3835666,
   4063747,4305390,4561401,4832636,5120000,5424451,5747006,6088740,6450796,
   6834380,7240773,7671332,8127493,8610779,9122803,9665273,10240000,10848902,
   11494011,12177481,12901592,13668760,14481547,15342664,16254987,17221559,
   18245606,19330546,20480000,21697804,22988023,24354962,25803183,27337520,
   28963094,30685329,32509974,34443117,36491211,38661092,40960000,43395608,
   45976045,48709923,51606366,54675040,57926188,61370658,65019947,68886234,
   72982423,77322184,81920000,86791217,91952091,97419847,103212732,109350081,
   115852375,122741316]

  val transpose = ref 0 (* XXX? *)
  fun pitchof n =
      let
          val n = n + ! transpose
          val n = if n < 0 then 0 else if n > 127 then 127 else n
      in
          Vector.sub(pitches, n)
      end

  (* must agree with sound.c *)
  val INST_NONE   = 0
  val INST_SQUARE = 1
  val INST_SAW    = 2
  val INST_NOISE  = 3
  val INST_SINE   = 4

  val freqs = Array.array(16, 0)
  fun setfreq (ch, f, vol, inst) =
      let in
(*
          print ("setfreq " ^ Int.toString ch ^ " = " ^
                 Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
*)
(*
          print("setfreq " ^ Int.toString ch ^ " = " ^
                        Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
*)
          setfreq_ (ch, f, vol, inst);
          (* "erase" old *)
          blitall (blackfade, screen, Array.sub(freqs, ch), 16 * (ch + 1));
          (* draw new *)
          (if vol > 0 then blitall (solid, screen, f, 16 * (ch + 1))
           else ());
          Array.update(freqs, ch, f);
          flip screen
      end



  datatype status = 
      OFF
    | PLAYING of int
  (* for each channel, all possible midi notes *)
  val miditable = Array.array(16, Array.array(127, OFF))
  val NMIX = 12 (* XXX get from C code *)
  val mixes = Array.array(NMIX, false)

  fun noteon (ch, n, v, inst) =
      (case Array.sub(Array.sub(miditable, ch), n) of
           OFF => (* find channel... *)
               (case Array.findi (fn (_, b) => not b) mixes of
                    SOME (i, _) => 
                        let in
                            Array.update(mixes, i, true);
                            setfreq(i, pitchof n, v, inst);
                            Array.update(Array.sub(miditable, ch),
                                         n,
                                         PLAYING i)
                        end
                  | NONE => print "No more mix channels.\n")
         (* re-use mix channel... *)
         | PLAYING i => setfreq(i, pitchof n, v, inst)
                    )

  fun noteoff (ch, n) =
      (case Array.sub(Array.sub(miditable, ch), n) of
           OFF => (* already off *) ()
         | PLAYING i => 
               let in
                   Array.update(mixes, i, false);
                   setfreq(i, pitchof 60, 0, INST_NONE);
                   Array.update(Array.sub(miditable, ch),
                                n,
                                OFF)
               end)
      

  (* FIXME totally ad hoc!! *)
  val itos = Int.toString
  val f = (case CommandLine.arguments() of 
               [st] => st
             | _ => "totally-membrane.mid")
  val r = (Reader.fromfile f) handle _ => 
      raise Test ("couldn't read " ^ f)
  val m as (ty, divi, thetracks) = MIDI.readmidi r
  val _ = ty = 1
      orelse raise Test ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
  val () = print ("MIDI division is " ^ itos divi ^ "\n")
  val _ = divi > 0
      orelse raise Test ("Division must be in PPQN form!\n")

  (* val () = app (fn l => print (itos (length l) ^ " events\n")) thetracks *)

  (* XXX hammer time *)
(* 
  val hammerspeed = 0w1
  local val gt = ref 0w0 : Word32.word ref
  in
    fun getticks () =
      let in
        gt := !gt + hammerspeed;
        !gt
      end
  end
*)

  (* allow fast forwarding into the future *)
  val skip = ref 0
  fun getticksi () = (Word32.toInt (getticks ()) + !skip)

  (* how many ticks forward do we look? *)
  val MAXAHEAD = 960

  (* For 360 X-Plorer guitar, which strangely swaps yellow and blue keys *)
  fun joymap 0 = 0
    | joymap 1 = 1
    | joymap 3 = 2
    | joymap 2 = 3
    | joymap 4 = 4
    | joymap _ = 999 (* XXX *)

  fun fingeron f =
      let val x = 8 + 6 + f * (STARWIDTH + 18)
          val y = height - 42
      in
          if f >= 0 andalso f <= 4
          then (blitall(Vector.sub(stars, f),
                        screen, x, y);
                flip screen)
          else ()
      end

  fun fingeroff f =
      let val x = 8 + 6 + f * (STARWIDTH + 18)
          val y = height - 42
      in
          if f >= 0 andalso f <= 4
          then (blit(background, x, y, STARWIDTH, STARHEIGHT,
                     screen, x, y);
                flip screen)
          else ()
      end

  fun commit () =
      let
      in blitall(robotr, screen, 0, height - 42);
          flip screen
      end

  (* just drawing *)
  fun commitup () =
      let
      in
          blit(background, 0, height - 42, ROBOTW, ROBOTH,
               screen, 0, height - 42);
          flip screen
      end

  (* Fudge a score track from the actual notes. *)
  (* XXX should do for score tracks, not music tracks *)
  (* but for now don't show drum tracks, at least *)
  fun score_inst_XXX inst = inst <> INST_NOISE

  structure State =
  struct

    (* Player input *)
    val fingers = Array.array(5, false) (* all fingers start off *)

    (* Is there a sustained note on this finger? *)
    val spans = Array.array(5, false) (* and not in span *)

  end

  (* PERF could keep 'lastscene' and only draw changes? *)
  (* This is the description of what is currently displayed. *)
  structure Scene =
  struct

    val TEMPOCOLORS = Vector.fromList [color(0wx77, 0wx77, 0wx77, 0wxFF),
                                       color(0wxAA, 0wxAA, 0wxAA, 0wxFF)]
    val starpics = stars

     (* color, x, y *)
    val stars = ref nil : (int * int * int) list ref
    (* rectangles the liteup background to draw. x,y,w,h *)
    val spans = ref nil : (int * int * int * int) list ref
    (* color, y *)
    val bars  = ref nil : (int * int) list ref
      
    (* XXX fingers, strum, etc. *)

    fun clear () =
      let in
        stars := nil;
        spans := nil;
        bars  := nil
      end

    fun addstar (finger, stary) =
      (* XXX fudge city *)
      stars := 
      (finger,
       (STARWIDTH div 4) +
       6 + finger * (STARWIDTH + 18),
       (* hit star half way *)
       (height - (NUTOFFSET + STARHEIGHT div 2)) - (stary div 2)) :: !stars

    fun addbar (c, t) = bars := (c, (height - NUTOFFSET) - (t div 2)) :: !bars

    fun addspan (finger, spanstart, spanend) =
      spans :=
      (21 + finger * (STARWIDTH + 18), 
       (height - NUTOFFSET) - spanend div 2,
       18 (* XXX *),
       (spanend - spanstart) div 2) :: !spans

    fun draw () =
      let in
        (* entire background first first *)
        blitall(background, screen, 0, 0);
        (* spans first *)
        (* XXX *)
        (* app (fn (x, y, w, h) => fillrect(screen, x, y, w, h, Vector.sub(TEMPOCOLORS, 1))) (!spans); *)

        app (fn (x, y, w, h) => blit(backlite, x, y, w, h, screen, x, y)) (!spans);

        (* tempo *)
        (* XXX probably could have different colors for major and minor bars... *)
        app (fn (c, y) => fillrect(screen, 16, y, width - 32, 2, Vector.sub(TEMPOCOLORS, c))) (!bars);
        (* stars on top *)
        app (fn (f, x, y) => blitall(Vector.sub(starpics, f), screen, x, y)) (!stars)
      end
       
  end

  (* XXX assuming ticks = midi delta times; wrong! 
     (even when slowed by factor of 4 below) *)
  val TICKBARS = (* 256 *) (* 240 *) divi * 2
  val DRAWTICKS = (* 128 *) 3
  fun loopplay (_,  _,  nil) = print "SONG END.\n"
    | loopplay (lt, ld, track) =
      let
          val now = getticksi ()
          (* val () = print ("Lt: " ^ itos lt ^ " Now: " ^ itos now ^ "\n") *)

          (* Last time we were here it was time 'lt', and now it is 'now'. The
             events in the track are measured as deltas from lt. We
             want to play any event that was late (or on time): that
             occurred between lt and now. This is the case when the delta time
             is less than now - lt.
             
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
              updating lt, but there is no reason for that.)

              When the gap is too small to include the next event, we reduce
              its delta time by the remaining gap amount.

             *)
          fun nowevents gap ((dt, (label, evt)) :: rest) =
            let 
(*
              val () = if gap > dt then print ("late by " ^ Int.toString (gap - dt) ^ "\n")
                       else ()
*)

              (* try to account for drift *)
              (* val () = if nn < 0 then skip := !skip + nn
                       else () *)
            in
              if dt <= gap
              then 
                let in
                  (case label of
                     Music inst =>
                       (case evt of
                          MIDI.NOTEON(ch, note, 0) => noteoff (ch, note)
                        | MIDI.NOTEON(ch, note, vel) => noteon (ch, note, 12000, inst) 
                        | MIDI.NOTEOFF(ch, note, _) => noteoff (ch, note)
                        | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
                          (* otherwise no sound..? *) 
                   | Control =>
                       (case evt of
                            (* http://jedi.ks.uiuc.edu/~johns/links/music/midifile.html *)
                            MIDI.META (MIDI.TEMPO n) => print ("TEMPO " ^ itos n ^ "\n")
                          | MIDI.META (MIDI.TIME (n, d, cpc, bb)) =>
                                print ("TIME " ^ itos n ^ "/" ^ itos (Util.pow 2 d) ^ "  @ "
                                       ^ itos cpc ^ " bb: " ^ itos bb ^ "\n")
                          | _ => print ("unknown ctrl event: " ^ MIDI.etos evt ^ "\n"))
                          );

                  (* and adjust state *)
                  (case label of
                     Music inst =>
                       if score_inst_XXX inst
                       then
                         case evt of
                           MIDI.NOTEON (ch, note, 0) => Array.update(State.spans, note mod 5, false)
                         | MIDI.NOTEON (ch, note, _) => Array.update(State.spans, note mod 5, true)
                         | MIDI.NOTEOFF(ch, note, _) => Array.update(State.spans, note mod 5, false)
                         | _ => ()
                       else ()
                    (* tempo here? *)
                    | _ => ());

                  nowevents (gap - dt) rest
                end
              (* the event is not ready yet. it must be measured as a
                 delta from 'now' *)
              else (dt - gap, (label, evt)) :: rest
            end
            (* song will end on next trip *)
            | nowevents _ nil = nil

          val track = nowevents (now - lt) track
      in
          loop (now, ld, track)
      end

  and loopdraw (lt, ld, track) =
    let 
      val now = getticksi ()
    in
      if now - ld >= DRAWTICKS
      then 
        let 
          val () = Scene.clear ()

          (* spans may be so long they run off the screen. We keep track of
             a bit of state for each finger, which is whether we are currently
             in a span there. *)
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
              Scene.addspan (finger, spanstart, Int.min(MAXAHEAD, spanend))
            end
          
          (* val () = print "----\n" *)

          val period = now - lt

          fun draw _ nil =
            (* Make sure that we only end a span if it's started *)
            Array.appi (fn (finger, SOME spanstart) => emit_span finger (spanstart, MAXAHEAD)
                         | _ => ()) spans
            | draw when ((dt, (label, e)) :: rest) = 
            if when + dt > MAXAHEAD
            then draw when nil
            else 
              let 
                val tiempo = when + dt
                  
              in
                (case label of
                   Music inst => 
                     if score_inst_XXX inst
                     then
                       let
                         fun doevent (MIDI.NOTEON (x, note, 0)) = doevent (MIDI.NOTEOFF (x, note, 0))
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
                                 Scene.addstar (finger, tiempo);
                                 
                                 (* don't emit--we assume proper bracketing
                                    (even though this is not the case when
                                    we generate the score by mod5 or include
                                    multiple channels!) *)
                                 Array.update(spans, finger, SOME tiempo)
                               end
                           | doevent _ = ()
                       in doevent e
                       end
                     else ()
                       (* otherwise... ? *)
                 | Control => ()
                       );
                   draw tiempo rest
              end
            
          (* Bars are wrong, for some reason. 
             Maybe it has to do with drift?
             Maybe it is because the input delta times are actually
             sort of weird? *)
          val baroffset = TICKBARS - (now mod TICKBARS)
        in
          Util.for 0 (MAXAHEAD div TICKBARS)
          (fn n =>
           Scene.addbar (n mod 2, (n * TICKBARS) + baroffset)
           );

          draw 0 (* period? XXX *) track;
          Scene.draw ();
          flip screen;
          loopplay (lt, now, track)
        end
      else loopplay (lt, ld, track)
    end

  and loop x =
      let in
          (case pollevent () of
               SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Exit
             | SOME E_Quit => raise Exit
             | SOME (E_KeyDown { sym = SDLK_i }) => skip := !skip + 2000
             | SOME (E_KeyDown { sym = SDLK_o }) => transpose := !transpose - 1
             | SOME (E_KeyDown { sym = SDLK_p }) => transpose := !transpose + 1
             (* Assume joystick events are coming from the one joystick we enabled
                (until we have multiplayer... ;)) *)
             | SOME (E_JoyDown { button, ... }) => fingeron (joymap button)
             | SOME (E_JoyUp { button, ... }) => fingeroff (joymap button)
             | SOME (E_JoyHat { state, ... }) =>
               (* XXX should have some history here--we want to ignore events
                  triggered by left-right hat movements (those never happen
                  on the xplorer though) *)
               if Joystick.hat_up state orelse
                  Joystick.hat_down state
               then commit ()
               else commitup ()

             | _ => ()
               );
          loopdraw x
      end

  (* fun slow l = map (fn (delta, e) => (delta * 6, e)) l *)
  fun slow l = map (fn (delta, e) => (delta * 4, e)) l

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  (* Label all of the tracks
     This uses the track's name to determine its label. *)
  fun label tracks =
      let
          fun onetrack tr =
              case findname tr of
                  NONE => SOME (Control, tr) (* (print "Discarded track with no name.\n"; NONE) *)
                | SOME "" => SOME (Control, tr) (* (print "Discarded track with empty name.\n"; NONE) *)
                | SOME name => 
                      (case CharVector.sub(name, 0) of
                           #"+" =>
                           SOME (case CharVector.sub (name, 1) of
                                     #"Q" => Music INST_SQUARE 
                                   | #"W" => Music INST_SAW 
                                   | #"N" => Music INST_NOISE
                                   | #"S" => Music INST_SINE
                                   | _ => (print "?? expected Q or W or N\n"; raise Test ""),
                                 tr)
                         | _ => (print ("confused by named track '" ^ name ^ "'?? expected + or ...\n"); SOME (Control, tr))
                           )
      in
          List.mapPartial onetrack tracks
      end
      
  val tracks = label thetracks
  val tracks = slow (MIDI.mergea tracks)

(*
  val () = app (fn (dt, (lab, evt)) =>
                let in
                  print ("dt: " ^ itos dt ^ "\n")
                end) tracks
*)

  val () = loop (getticksi (), getticksi (), tracks)
    handle Test s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | Exit => ()
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
