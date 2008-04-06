
(* Tom 7 Entertainment System Hero! *)

(* FIXME On Windows, Check that SDL_AUDIODRIVER is dsound otherwise
   this is unusable because of latency *)

structure T7ESHero =
struct

  fun messagebox s = print (s ^ "\n")

  (* Comment this out on Linux, or it will not link *)

  local
      val mb_ = _import "MessageBoxA" : MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
  in
      fun messagebox s = mb_(MLton.Pointer.null, s ^ "\000", "Message!\000", MLton.Pointer.null)
  end

  type ptr = MLton.Pointer.t
  infixr 9 `
  fun a ` b = a b

  exception Nope

  exception Hero of string
  exception Exit

  open SDL

  val width = 256
  val height = 600

  val FINGERS = 5
    
  (* distance of nut (on-tempo target bar) from bottom of screen *)
  val NUTOFFSET = 127

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  (* number of SDL ticks per midi tick. need to fix this to derive from tempo. *)
  val SLOWFACTOR =
    (case map Int.fromString (CommandLine.arguments ()) of
       [_, SOME t] => t
     | _ => 5)

  val screen = makescreen (width, height)

  datatype bar =
      Measure
    | Beat
    | Timesig of int * int

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

  val solid = requireimage "testgraphics/solid.png"

  val background = requireimage "testgraphics/background.png"
  val backlite   = requireimage "testgraphics/backlite.png"

  val stars = Vector.fromList
      [requireimage "testgraphics/greenstar.png",
       requireimage "testgraphics/redstar.png",
       requireimage "testgraphics/yellowstar.png",
       requireimage "testgraphics/bluestar.png",
       requireimage "testgraphics/orangestar.png"]

  val missed = requireimage "testgraphics/missed.png"
  val hit = requireimage "testgraphics/hit.png"

  val STARWIDTH = surface_width (Vector.sub(stars, 0))
  val STARHEIGHT = surface_height (Vector.sub(stars, 0))
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val blackfade = requireimage "testgraphics/blackfade.png"
  val robobox = requireimage "testgraphics/robobox.png"
  val blackall = alphadim blackfade
  val () = clearsurface(blackall, color (0w0, 0w0, 0w0, 0w255))

  val () = blitall(background, screen, 0, 0)

  structure Font = FontFn (val surf = requireimage "font.png"
                           val charmap =
                           " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
                           "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
                           (* CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 
                              BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
                           val width = 9
                           val height = 16
                           val styles = 6
                           val overlap = 1
                           val dims = 3)

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
               st :: _ => st
             | _ => "totally-membrane.mid")
  val r = (Reader.fromfile f) handle _ => 
      raise Hero ("couldn't read " ^ f)
  val m as (ty, divi, thetracks) = MIDI.readmidi r
  val _ = ty = 1
      orelse raise Hero ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
  val () = print ("MIDI division is " ^ itos divi ^ "\n")
  val _ = divi > 0
      orelse raise Hero ("Division must be in PPQN form!\n")

  val divi = divi * SLOWFACTOR 

  (* XXX hammer time.
     if I do this it should be in Song below *)
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


  (* For 360 X-Plorer guitar, which strangely swaps yellow and blue keys *)
  fun joymap 0 = 0
    | joymap 1 = 1
    | joymap 3 = 2
    | joymap 2 = 3
    | joymap 4 = 4
    | joymap _ = 999 (* XXX *)

  (* FIXMEs *)
(*
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
      in blitall(Vector.sub(stars,0), screen, 0, height - 42);
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
*)

  datatype state =
      Future
    | Missed
    | Hit

  (* ... ? *)
  datatype input =
      FingerDown of int
    | FingerUp of int
    | Commit of int list

  structure Match :
  sig

      type scoreevt

      (* These should describe what kind of track an event is drawn from *)
      datatype label =
          Music of int * int
        | Score of scoreevt (* the tracks that are gated by this score *)
        | Control
        | Bar of bar

      val state : scoreevt -> state

      (* input (absolute time, input event)
         can change the state of some scoreevts *)
      val input : int * input -> unit

      (* initialize (gates, events)
         produces a t7eshero track of (int * (label * event))
         where the labels are Score. Also initializes the
         internal matching matrix. *)
      val initialize : (int list * (int * MIDI.event) list) ->
                       (int * (label * MIDI.event)) list

  end =
  struct

      val EPSILON = 15

      datatype scoreevt = 
          SE of { (* audio tracks that are gated by this event *)
                  gate : int list,
                  state : state ref,
                  idx : int,
                  soneme : int list }
        | SE_BOGUS


      (* These should describe what kind of track an event is drawn from *)
      datatype label =
          Music of int * int
        | Score of scoreevt (* the tracks that are gated by this score *)
        | Control
        | Bar of bar


      fun state (SE { state, ... }) = !state
        | state  SE_BOGUS = raise Hero "Bogus"

      structure GA = GrowArray
      (* The matching array is 

         song events on this axis; one column per event ......
        |
        |
        |
        |
        v

        input events on the vertical axis, one row per input.
        
         *)
      (* This is a growarray of Arrays (vectors?), each of length
         equal to the number of events in the song.

         Absolute time, the event, the dp score (= streak,#misses).
         *)
      val matching = GA.empty () : (int * input * (bool * int) array) GA.growarray

      (* contains all of the scoreevts in the song *)
      val song = ref (Vector.fromList nil) : (int * scoreevt) vector ref

      (* This is the heart of T7esHero. Process a piece of input by adding
         a new row to the matrix. *)
      fun input (now, input) = 
          let
              val current_length = GA.length matching
              val prevrow = 
                  if current_length = 0
                  then (fn _ => (false, 0))
                  else 
                      let val (_, _, a) = GA.sub matching (current_length - 1)
                      in (fn i => Array.sub(a, i))
                      end

              (* This is pretty inefficient. We really only need to look at
                 a fraction of it because most of the comparisons are refuted
                 by being out of epsilon range. Oh, well. *)
              (* PERF doesn't need to be initialized here *)
              val nsong = Vector.length (!song)
              val new = Array.array (nsong, (false, 0))

              val () =
              Util.for 0 (nsong - 1)
              (fn i =>
               let
                   val (t, se) = Vector.sub(!song, i)
                   val up = prevrow i
                   val (upleft, left) = 
                       if i > 0 
                       then (prevrow (i - 1), Array.sub(new, i - 1))
                       else ((false, 0), (false, 0))
                           
                   val didhit =
                   (* OK, so we're comparing the input event against
                      the ith event in the score. First thing is,
                      if the input and the event are not within
                      epsilon of one another, it's definitely a miss. *)
                       Int.abs (t - now) <= EPSILON
                       andalso 
                       (* ... *)
                       true

                   (* less here means "better" *)
                   fun less ((s1, i1), (s2, i2)) =
                       case Int.compare (i1, i2) of
                           LESS => true
                         | GREATER => false
                         | EQUAL => s1 andalso (not s2)

                   fun min (val1, val2, val3) =
                       if less(val1, val2)
                       then (if less(val1, val3)
                             then val1
                             else val3)
                       else (if less(val2, val3)
                             then val2
                             else val3)

                   val best =
                   case input of
                       Commit nl =>
                           if didhit
                           then 
                               min ((false, #2 upleft + 1),
                                    (false, #2 left + 1),
                                    (false, #2 up + 1))
                           else
                               min ((* hit! *)
                                    (true, #2 upleft),
                                    (false, #2 left + 1),
                                    (false, #2 up + 1))
                               
                     (* XXX currently ignoring all other input! *)
                     | _ => min ((false, #2 upleft + 1),
                                 (false, #2 left + 1),
                                 (* consume input, doing nothing *)
                                 up)
               in
                   Array.update(new, i, best)
               end)
          in
              GA.append matching (now, input, new)              
          end

      fun initialize (gates, track) =
          (* let's do *)
          let
              (* Add scorevent holders so we can update them later. *)
              val track = map (fn (d, e) => (d, (ref SE_BOGUS, e))) track

              (* For the purpose of matching we don't care about
                 note lengths at all (phew) so we don't care about
                 NOTEOFF events. *)
              val starts = MIDI.filter (fn (_, MIDI.NOTEON(_, _, 0)) => false
                                         | (_, MIDI.NOTEON _) => true
                                         | _ => false) track

              fun makeabsolute idx total ((d, evt) :: rest) =
                  let
                      fun now ((0, evt) :: more) = 
                          let val (nows, laters) = now more
                          in (evt :: nows, laters)
                          end
                        | now l = (nil, l)

                      fun get (_, MIDI.NOTEON (ch, n, vel)) = n
                        | get _ = raise Hero "impossible"

                      val (nows, laters) = now rest
                      val nows = evt :: nows

                      val soneme = map get nows

                      val se = SE { gate = gates, 
                                    state = ref Future,
                                    idx = idx,
                                    soneme = soneme }

                      (* they all share the same scoreevt *)
                      val () = app (fn (s, _) => s := se) nows
                  in
                      (total + d, se) :: makeabsolute (idx + 1) (total + d) laters
                  end
                | makeabsolute _ _ nil = nil

              val () = song := Vector.fromList (makeabsolute 0 0 starts)
              val track = map (fn (d, (ref se, e)) => (d, (Score se, e))) track
          in
              app (fn (d, (Score SE_BOGUS, MIDI.NOTEON(_, _, vel))) =>
                   (if vel > 0 then messagebox ("at " ^ Int.toString d ^ " bogus!") else ())
                   | _ => ()) track;
              track
          end

  end

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

      (* Actually just need to take a measurement, but clearer to
         give these separate names. *)
      val init = update

      (* shadowing for export *)
      val now = fn () => !now
  end


  structure State =
  struct

    (* Player input *)
    val fingers = Array.array(FINGERS, false) (* all fingers start off *)

    (* Is there a sustained note on this finger (off the bottom of the screen,
       not the nut)? *)
    val spans = Array.array(FINGERS, false) (* and not in span *)


    fun fingeron n = 
        let in
            Array.update(fingers, n, true);
            Match.input (Song.now (), FingerDown n)
        end
    
    fun fingeroff n =
        let in
            Array.update(fingers, n, false);
            Match.input (Song.now (), FingerUp n)
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
            Match.input (Song.now (), Commit (theevent 0))
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
    (* type, y, height *)
    val bars  = ref nil : (color * int * int) list ref
      
    (* XXX fingers, strum, etc. *)

    fun clear () =
      let in
        stars := nil;
        spans := nil;
        bars  := nil
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

    fun addbar (b, t) = 
      let 
        val (c, h) = 
          case b of
            Beat => (BEATCOLOR, 2)
          | Measure => (MEASURECOLOR, 5)
          | Timesig _ => (TSCOLOR (* XXX also show time sig *), 8)
      in
          bars := (c, (height - mynut) - (t div TICKSPERPIXEL), h) :: !bars
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
        (* XXX *)
        (* app (fn (x, y, w, h) => fillrect(screen, x, y, w, h, Vector.sub(TEMPOCOLORS, 1))) (!spans); *)

        app (fn (x, y, w, h) => blit(backlite, x, y, w, h, screen, x, y)) (!spans);

        (* tempo *)
        (* XXX probably could have different colors for major and minor bars... *)
        app (fn (c, y, h) => fillrect(screen, 16, y - (h div 2), width - 32, h, c)) (!bars);
        (* stars on top *)
        app (fn (f, x, y, e) => 
             let in
                 blitall(Vector.sub(starpics, f), screen, x, y);

                 (* plus icon *)
                 (case Match.state e of
                      Missed => blitall(missed, screen, x, y)
                    | Hit => blitall(hit, screen, x, y)
                    | _ => ())
             end) (!stars);

        (* finger state *)
        Util.for 0 (FINGERS - 1)
        (fn i =>
         if Array.sub(State.fingers, i)
         then blitall(hit, screen, 
                      (STARWIDTH div 4) + 6 + i * (STARWIDTH + 18),
                      (height - NUTOFFSET) - (STARWIDTH div 2))
         else ())
      end
       
  end

  (* XXX assuming ticks = midi delta times; wrong! We'll live with it for now. *)

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
                            print ("myTIME " ^ itos n ^ "/" ^ itos (Util.pow 2 d) ^ "  @ "
                                   ^ itos cpc ^ " bb: " ^ itos bb ^ "\n")
                      | _ => print ("unknown ctrl event: " ^ MIDI.etos evt ^ "\n"))
             | Bar _ => () (* XXX could play metronome click *)
             | Score _ => ())
          nows
      end

  val DRAWTICKS = (* 128 *) 3
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
                                        (even though this is not the case when
                                        we generate the score by mod5 or include
                                        multiple channels!) *)
                                     Array.update(spans, finger, SOME tiempo)
                                 end
                             | doevent _ = ()
                         in doevent e
                         end
                   | Bar b => Scene.addbar(b, tiempo)
                         (* otherwise... ? *)
                   | Control => ()
                         );

                     draw tiempo rest
                end
        in
          draw 0 (Song.look cursor);
          Scene.draw ();
          flip screen
        end
      else ()

  fun loop (playcursor, drawcursor) =
      let in
          (case pollevent () of
               SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Exit
             | SOME E_Quit => raise Exit
             | SOME (E_KeyDown { sym = SDLK_i }) => Song.fast_forward 2000
             | SOME (E_KeyDown { sym = SDLK_o }) => transpose := !transpose - 1
             | SOME (E_KeyDown { sym = SDLK_p }) => transpose := !transpose + 1
             (* Assume joystick events are coming from the one joystick we enabled
                (until we have multiplayer... ;)) *)
             | SOME (E_JoyDown { button, ... }) => State.fingeron (joymap button)
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
           loopplay playcursor;
           loopdraw drawcursor;
           loop (playcursor, drawcursor)
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
             nil => (ticksleft, (Bar Measure, DUMMY)) :: ibars ticklist ((dt - ticksleft, evt) :: rest)
           | _   => (ticksleft, (Bar Beat, DUMMY))    :: ibars rtl      ((dt - ticksleft, evt) :: rest))

        | ibars nil _ = raise Hero "tickslist never nil" (* 0/4 time?? *)

    in
      (0, (Control, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) ::
      (0, (Bar (Timesig (n, Util.pow 2 d)), DUMMY)) ::
      ibars ticklist rest
    end

  (* fun slow l = map (fn (delta, e) => (delta * 6, e)) l *)
  fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l

  (* How to complete pre-delay? *)
  fun delay t = (2 * divi, (Control, DUMMY)) :: t

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
                            #"Q" => Music (INST_SQUARE, i)
                          | #"W" => Music (INST_SAW, i)
                          | #"N" => Music (INST_NOISE, i)
                          | #"S" => Music (INST_SINE, i)
                          | _ => (print "?? expected S or Q or W or N\n"; raise Hero ""),
                            tr)

                     | #"!" =>
                       (case CharVector.sub (name, 1) of
                            #"R" =>
                              (* XXX only if this is the score we desire. *)
                              SOME `
                              Match.initialize
                              (map (fn i => 
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
          val drawcursor = Song.cursor (0 - Scene.DRAWLAG) tracks (* XXX offset! *)
      in
          loop (playcursor, drawcursor)
      end
    handle Hero s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | Exit => ()
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
