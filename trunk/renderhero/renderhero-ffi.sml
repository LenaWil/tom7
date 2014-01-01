
(* Renderhero is a fork of Tom 7 Entertainment System Hero that
   simply renders the MIDI file to a WAV file offline. The purpose
   is to provide sample-accurate rendering for e.g. making music
   videos that may need tight time-based synchronization. *)

structure RenderHero =
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

  exception Hero of string

  (* This uses lots of top-level evaluation, making exception handling awkward *)
  fun report e =
      case e of 
          Hero s => (messagebox ("exn test: " ^ s); raise e)
        | Wave.Wave s => (print ("WAVE ERROR: " ^ s ^ "\n"); raise e)
        | e => 
              let in
                  app (fn s => print (s ^ "\n")) (MLton.Exn.history e);
                  messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e);
                  raise e
              end

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  datatype bar =
      Measure
    | Beat
    | Timesig of int * int

  (* XXX these should describe what kind of track it is *)
  datatype label =
      Music of int
    | Control
    | Bar of bar

  local val initaudio_ = _import "ml_initsound" : unit -> unit ;
  in val () = initaudio_ ()
  end

  val setfreq_ = _import "ml_setfreq" : int * int * int * int -> unit ;

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
          Array.update(freqs, ch, f)
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

  (* val divi = divi * SLOWFACTOR *)

  (* val () = app (fn l => print (itos (length l) ^ " events\n")) thetracks *)

  structure GA = GrowMonoArrayFn_Safe(structure A = Word16Array
                                      val default = 0w0 : Word16.word)

  val rendered = GA.empty ()
      
  (* The crux of this fork is that "time" proceeds only through manual
     intervention. Each tick is a sample. *)
  val hammerspeed = 0w1
  local val gt = ref 0w0 : Word32.word ref
  in
    fun getticks () = !gt
    fun maketick () =
    let in
        gt := !gt + hammerspeed;
        !gt
    end
  end

  fun getticksi () = Word32.toInt (getticks ())


  fun div_exact (m : IntInf.int, n) =
      let
          val q = m div n
      in
          if n * q <> m
          then raise Hero (IntInf.toString m ^ " div " ^ 
                           IntInf.toString n ^ " cannot be represented exactly")
          else q
      end
      
  fun div_exacti (m, n) = IntInf.toInt (div_exact (IntInf.fromInt m, IntInf.fromInt n))

  infix div_exact div_exacti

  val SAMPLERATE = 44100 * 4 (* XXX must agree with .c *)
  (* Given a MIDI tempo in microseconds-per-quarter note
     (which is what the TEMPO event carries),
     compute the number of samples per MIDI tick,
     and insist that this can be represented exactly
     as an integer. *)
  fun spt_from_upq upq =
      let
          val () = print ("Microseconds per quarternote: " ^
                          Int.toString upq ^ "\n")

          (* microseconds per tick  NO *)
          (* val uspt = IntInf.fromInt upq * IntInf.fromInt divi *)

          (* samples per tick is
             
             usec per tick      samples per usec
             (upq / divi)    *  (fps / 1000000)

             *)
          val fpq = (IntInf.fromInt SAMPLERATE * IntInf.fromInt upq) div_exact 
                    (IntInf.fromInt 1000000 * IntInf.fromInt divi)
      in
          print ("Samples per tick is now: " ^ IntInf.toString fpq ^ "\n");
          IntInf.toInt fpq
      end

  (* XXX don't need ld arg *)
  fun loopplay (_,  _,  _, nil) = print "SONG END.\n"
    | loopplay (lt, ld, spt, track) =
      let
          val now = getticksi ()

          (* hack attack *)
          val spt = ref spt
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
                        | MIDI.NOTEON(ch, note, vel) => (print ".";
                                                         noteon (ch, note, 12000, inst))
                        | MIDI.NOTEOFF(ch, note, _) => noteoff (ch, note)
                        | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
                          (* otherwise no sound..? *) 
                   | Control =>
                       (case evt of
                            (* http://jedi.ks.uiuc.edu/~johns/links/music/midifile.html *)
                            MIDI.META (MIDI.TEMPO n) => 
                                let in
                                    print ("TEMPO " ^ itos n ^ "\n");
                                    spt := spt_from_upq n
                                end
                                
                          | MIDI.META (MIDI.TIME (n, d, cpc, bb)) =>
                                print ("myTIME " ^ itos n ^ "/" ^ itos (Util.pow 2 d) ^ "  @ "
                                       ^ itos cpc ^ " bb: " ^ itos bb ^ "\n")
                          | _ => print ("unknown ctrl event: " ^ MIDI.etos evt ^ "\n"))
                   | Bar _ => () (* XXX could play metronome click *)
                          );

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
          loop (now, ld, !spt, track)
      end

  and loop (x as (_, _, spt, _)) =
      let 
          (* render spt (samples-per-tick) samples *)
          val n = spt
          val samples = Array.array(n, 0w0 : Word16.word)
          val mixaudio_ = _import "mixaudio" : ptr * Word16.word array * int -> unit ;
      in
          (* two bytes per sample *)
          mixaudio_(MLton.Pointer.null, samples, n * 2);
          
          (*
          if Array.sub(samples, 0) <> 0w0
          then raise Hero ("COOL: " ^ Word16.toString (Array.sub(samples, 0)))
          else ();
          *)

          Util.for 0 (n - 1) (fn i => GA.append rendered (Array.sub(samples, i)));
          
          (* advance time; continue *)
          maketick ();
          loopplay x
      end

  (* This stuff is not necessary for rendering into samples, but could be
     useful anyway. *)

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
        | getstarttime ((0, (_, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) :: rest) = ((n, d, cpc, bb), rest)
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
  (* fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l *)

  (* How to complete pre-delay? *)
  fun delay t = (2 * divi, (Control, DUMMY)) :: t

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  val DIVI_DIVISION = 4 (* I care about sixteenth notes *)
  val FRAMES_PER_TICK = 3 (* report in frames *)
  (* For ActionScript geometric renderers *)
  fun print_track t =
      let 
          (* number of ticks per sixteenth note *)
          val divisor = divi div_exacti DIVI_DIVISION

          fun noteson extra ((delta, e) :: l) =
              let val delta = delta + extra
                  val extra = 
                      case e of
                          MIDI.NOTEON(_, note, 0) => delta
                        | MIDI.NOTEON(_, note, v) => 
                           let in
                              print
                              ("{ d:" ^ Int.toString ((delta * FRAMES_PER_TICK) 
                                                      div_exacti divisor) ^
                               ", n:" ^ Int.toString note ^ "}, ");
                              0
                            end
                        | _ => delta
              in
                  noteson extra l
              end
            | noteson _ nil = ()
      in
          noteson 0 t
      end

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
                                     #"Q" => 
                                     let in 
                                         (* XXX hack attack, should be command line or sth? *)
                                         (* print_track tr; *)
                                         Music INST_SQUARE 
                                     end
                                   | #"W" => 
                                     let in
                                         (* XXX hack attack *)
                                         print_track tr;
                                         Music INST_SAW 
                                     end
                                   | #"N" => Music INST_NOISE
                                   | #"S" => Music INST_SINE
                                   | _ => (print "?? expected Q or W or N\n"; raise Hero ""),
                                 tr)
                         | _ => (print ("confused by named track '" ^ name ^ "'?? expected + or ...\n"); 
                                 SOME (Control, tr))
                           )
      in
          List.mapPartial onetrack tracks
      end handle e => report e
      
  val tracks = label thetracks
  val tracks = MIDI.mergea tracks
  (* val tracks = slow (MIDI.mergea tracks) *)
  val tracks = add_measures tracks

  val tracks = delay tracks

  (* Start with the play loop, because we want to begin at time 0, sample 0 *)
  (* need to start with tempo 120 = 0x07a120 ms per tick *)
  val () = loopplay (getticksi (), getticksi (), spt_from_upq 0x07a120 , tracks)
    handle e => report e

  val () = print "Rendered. Writing wave...\n"

  (* PERF why bother finalizing if we're also copying? *)
  val f = GA.finalize rendered
  val a = Vector.tabulate(Word16Array.length f,
                          fn x => Int16.fromInt (Word16.toIntX (Word16Array.sub (f, x))))

  val () = Wave.tofile { frames = Wave.Bit16 (Vector.fromList [a]),
                         samplespersec = Word32.fromInt SAMPLERATE } "test.wav"
      handle e => report e

end
