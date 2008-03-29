
(* Tom 7 Entertainment System Hero!

   This program generates default scores for a song (in a midi file)
   using the notes actually played as a guide. 

   This is very simple; doing a good job needs a certain amount of
   human input to understand how the song "feels", particularly
   with regard to repeating phrases in which there are some things
   that should be obviously "up" vs. "down".

   One important thing we do is to make sure that there are no
   illegal overlaps: a note that starts while another note is
   active. If the second note starts after the first, we terminate
   the first one at that point. If they both start at the same time
   on the same fret, we erase the one with the earlier finish.

   To run this program, you must specify which tracks the score
   should be derived from. The track numbers are displayed when
   the program is run without any tracks specified.

   TODO: mod 5 or mod 3 are bad ideas, since those are common
   intervals. If we have two on the same fret at the same time, we
   should probably instead shift one over, so it looks like a chord!

*)

structure T7ESHero =
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
  infixr 9 `
  fun a ` b = a b

  exception Nope

  exception Hero of string
  exception Exit

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  datatype bar =
      Measure
    | Beat
    | Timesig of int * int
    | Nothing

  (* XXX these should describe what kind of track it is *)
  datatype label =
      Music of int
    | Control
    | Bar of bar

  (* must agree with sound.c *)
  val INST_NONE   = 0
  val INST_SQUARE = 1
  val INST_SAW    = 2
  val INST_NOISE  = 3
  val INST_SINE   = 4

  val itos = Int.toString

  val (f, includes) = 
      (case CommandLine.arguments() of 
           st :: includes => 
               (st,
                map (fn SOME i => i
              | NONE => (print "Expected a series of track numbers after the filename\n";
                         raise Exit)) (map Int.fromString includes))
         | _ => (print "Expected a MIDI file on the command line.\n";
                 raise Exit))

  val r = (Reader.fromfile f) handle _ => 
      raise Hero ("couldn't read " ^ f)
  val m as (ty, divi, thetracks) = MIDI.readmidi r
  val _ = ty = 1
      orelse raise Hero ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
  val () = print ("MIDI division is " ^ itos divi ^ "\n")
  val _ = divi > 0
      orelse raise Hero ("Division must be in PPQN form!\n")

  datatype normalized =
      BAR of bar
    | OFF of int
    | ON  of int

  datatype lengthened =
      LBAR of bar
      (* non-nil *)
    | NOTES of (int * int option ref) list

  (* note/durations. non-nil *)
  type measure_event = (int * int) list
  (* delta, chord *)
  type measure = (int * measure_event) list

  structure MeasureKey : ORD_KEY =
  struct
      type ord_key = measure

      val devent = Util.lex_order Int.compare 
                     (Util.lex_list_order 
                      (Util.lex_order Int.compare Int.compare))

      val compare : measure * measure -> order = Util.lex_list_order devent
  end

  structure MM = SplayMapFn(MeasureKey)

  val RADIX = 5 (* XXX configurable. Also, include open? *)
  val gamut = List.tabulate (RADIX, fn x => x)

  (* Render a single measure. We got rid of the deltas and lengths. *)
  fun render_one (m : int list list) =
      let
          val total = ref 0
          (* given the assignment for the previous 
             event, compute the best possible assignment
             for the tail, and its penalty. *)
          (* PERF: memoize!! *)
          fun best_rest BEST_REST (_, nil) = (total := !total + 1; 
                                 if (!total mod 1000) = 0
                                 then print (Int.toString (!total) ^ "\n")
                                 else ();
                                 (nil, 0))
            | best_rest BEST_REST ((evt, ass), ns :: rest) =
              let
                  (* all legal assignments for evt. 
                     It turns out this only depends on
                     the length of evt; its cardinality is
                       RADIX choose (length evt).
                     *)
                  fun all_assignments n = ListUtil.choosek n gamut
                      
                  val olds = ListPair.zip (evt, ass)

                  (* The heart of genscore. Compute a penalty for this assignment,
                     given the previous assignment.
                     The penalty is "linear" over the components of the soneme, so
                     we do this note by note.
                     *)
                  fun this_penalty (enew, anew) =
                      let
                          fun note_penalty (e1, a1) (e2, a2) =
                              case Int.compare (e1, e2) of
                                  EQUAL => if a1 = a2
                                           then 0 (* good! *)
                                           else 10 (* really bad! *)
                                | LESS => (case Int.compare (a1, a2) of
                                               LESS => 0 (* good! *)
                                             | EQUAL => 3 (* bad! *)
                                             | GREATER => 1 (* a little bad *))
                                | GREATER => (case Int.compare (a1, a2) of
                                                  GREATER => 0
                                                | EQUAL => 3
                                                | LESS => 1)

                          val news = ListPair.zip (enew, anew)
                      in
                          ListPair.foldl (fn (old, new, s) =>
                                          s + note_penalty old new) 0 (olds, news)
                      end

                  val nevt = length evt
                  val () = if nevt > RADIX
                           then raise Hero "can't do chords larger than radix!"
                           else ()

                  (* try all, choose best. *)
                  fun getbest (best, bestpen) (ass :: more) =
                      let
                          val (tail, tailpen) = BEST_REST ((ns, ass), rest)
                          val pen = this_penalty (ns, ass)
                      in
                          if pen + tailpen < bestpen
                          then getbest (ass :: tail, pen + tailpen) more
                          else getbest (best, bestpen) more
                      end
                    | getbest (best, bestpen) nil = (best, bestpen)

              in
                  getbest (nil, 9999999) (all_assignments nevt)
              end

          (* Memoize or this is ridiculously expensive.
             PERF: use hashing or a dense int map, not eq! *)
          val tabler = Memoize.eq_tabler op=
          val best_rest = Memoize.memoizerec tabler best_rest

          (* pretend there is a (normally illegal) empty soneme with empty
             assignment, since this won't influence the choice for the
             first note. XXX To make this better, we might as well put the
             last note from (a) previous measure, if there is one. *)
          val (best, bestpen) = best_rest ((nil, nil), m)
      in
          print ("Got best penalty of " ^ Int.toString bestpen ^ " with " ^
                 Int.toString (!total) ^ " assignments viewed\n");
          best
      end

  (* Do the rendering once it's been normalized. *)
  fun render (t : measure list) =
      let
          (* Maps measures we've already rendered to their rendered versions. *)
          val completed = ref (MM.empty)
          fun get m = MM.find(!completed, m)

          fun do_one m =
              let
                  (* we don't care about the deltas, or the note lengths
                     for the purposes of assignment. take those out first. *)
                  val (dels, sons) = ListPair.unzip m
                  val (nots, lens) = ListPair.unzip (map ListPair.unzip sons)

                  val nots = render_one nots

                  (* Now put them back together... *)
                  val sons' = map ListPair.zip (ListPair.zip (nots, lens))
                  val res = ListPair.zip (dels, sons')
              in
                  completed := MM.insert(!completed, m, res)
              end

          fun maybe_do_one m =
              case get m of
                  NONE => do_one m
                | SOME _ => ()

      in
          app maybe_do_one t;
          map (fn m =>
               case get m of
                   SOME n => n
                 | NONE => 
                   raise Hero "After rendering, a measure wasn't completed?") t
      end

  (* Chunk the song into measures. This is really simple now
     that NOTES events have lengths in them, the only complication
     being deltas on events that we want to ignore, like LBAR Nothing. *)
  fun measures (t : (int * lengthened) list) =
      let
          (* All measures so far, in reverse *)
          val revmeasures = ref nil
          fun newmeasure revd = revmeasures := (rev revd) :: !revmeasures

          fun read this xdelta nil = newmeasure this
            | read this xdelta ((d, NOTES ns) :: rest) = 
              let
                  fun getlength (n, ref (SOME l)) = (n, l)
                    | getlength _ = raise Hero "NOTES's length not set!"
              in
                  read ((d + xdelta, map getlength ns) :: this) 0 rest
              end
            | read this xdelta ((d, LBAR Measure) :: rest) = 
              (newmeasure this;
               read nil 0 rest)
            | read this xdelta ((d, LBAR _) :: rest) = 
              read this (d + xdelta) rest
              
          val () = read nil 0 t
      in
          rev (!revmeasures)
      end

  (* Assuming normalized tracks, we can get rid of ON/OFF style
     events by computing the length of each note and putting it
     right in the event itself. We'll also group all of the notes
     that turn on at the same time into a chord. *)
  fun makelengths (t : (int * normalized) list) =
      let
          (* set the references in the NOTES we emit *)
          val null = (fn _ => raise Hero "Note was ended that never began?!")
          val current = Array.array(128, null)
          fun write ticks nil = nil
            | write ticks ((d, BAR b) :: more) =
              (d, LBAR b) :: write (ticks + d) more
            | write ticks ((d, ON i) :: more) =
              let
                  (* collect them up... *)
                  fun getnow acc ((0, ON i) :: more) = getnow (i :: acc) more
                    | getnow acc more = (rev acc, more)

                  val (nows, thens) = getnow nil more
                  val nows = i :: nows

                  fun onenow note =
                      let
                          val b = ref (fn () => ())
                          val r = ref NONE
                      in
                          Array.update(current,
                                       note,
                                       fn t =>
                                       let in
                                           r := SOME (t - (ticks + d));
                                           !b ();
                                           b := (fn () => raise Hero "note multiply ended")
                                       end);
                          (note, r)
                      end
              in
                  (d, NOTES ` map onenow nows) :: write (ticks + d) thens
              end
            | write ticks ((d, OFF i) :: more) =
              let in
                  Array.sub(current, i) (ticks + d);
                  (* and the off event is gone. But insert a dummy event to account
                     for the delta. *)
                  (d, LBAR Nothing) :: write (ticks + d) more
              end
      in
          write 0 t
      end

  (* Clean up to establish invariants. Ensure that we never get a
     NOTE-ON once another note has been going for more than 0 ticks. *)
  fun normalize t =
      let
          val finish = OFF

          fun getnow acc ((0, e) :: more) = getnow (e :: acc) more
            | getnow acc _ = rev acc

          fun withdelta plusdelta nil = raise Hero "withdelta on nil"
            | withdelta plusdelta (e :: rest) = (plusdelta, e) :: map (fn ee => (0, ee)) rest

          fun go plusdelta nil nil = nil
            | go plusdelta (active : int list) nil =
              (* if there are any active at the end, then stop 'em *)
              withdelta plusdelta ` map finish active
            | go plusdelta active ((delta, first) :: more) =
              let
                  val nowevts = first :: getnow nil more
                  (* We don't care about control messages, channels, instruments, or
                     velocities. *)
                  val ending = List.mapPartial 
                      (fn (Music _, MIDI.NOTEON(ch, note, 0)) => SOME note
                    | (Music _, MIDI.NOTEOFF(ch, note, _)) => SOME note
                    | _ => NONE) nowevts
                  val starting = List.mapPartial 
                      (fn (Music _, MIDI.NOTEON(ch, note, 0)) => NONE
                    | (Music _, MIDI.NOTEON(ch, note, vel)) => SOME note
                    | _ => NONE) nowevts
                  val bars = List.mapPartial (fn (Bar b, _) => SOME b | _ => NONE) nowevts

                  (* okay, so we have some notes ending this instant 
                     ('ending'), and some notes starting ('starting'), 
                     and maybe some other stuff ('bars'). First we need
                     to turn off any active notes that are ending now, 
                     so we don't get confused into thinking they're still
                     active. *)
                  val (stops, active) =
                      let
                          fun rem stops active (note :: rest) =
                              (case List.partition (fn n => n = note) active of
                                   ([match], nomatch) => rem (OFF match :: stops) nomatch rest
                                 | (nil, active) => 
                                       let in
                                           print ("Note " ^ Int.toString note ^ " was not active but turned off?\n");
                                           rem stops active rest
                                       end
                                 | _ => raise Hero "invt violation: note multiply active!")
                            | rem stops active nil = (stops, active)

                      in
                          rem nil active ending
                      end

                  (* If we are starting new notes here, we have to kill anything that's
                     now still active. This is the main way we establish the invariant. *)
                  val (stops, active) = if not (List.null starting) 
                                        then (stops @ map finish active, nil)
                                        else (stops, active)

                  val (starts, active) =
                      if List.null starting
                      then (nil, active)
                      else 
                          (* just start them, but make sure they're unique. *)
                          let
                              fun add act (note :: notes) =
                                  if List.exists (fn n => n = note) act
                                  then
                                      let in
                                          print ("Note begun multiply: " ^ Int.toString note ^ "\n");
                                          add act notes
                                      end
                                  else add (note :: act) notes
                                | add act nil = act

                              val act = add nil starting
                          in
                              (map ON act, act)
                          end
                  val nows = stops @ map BAR bars @ starts
              in
                  case nows of
                      nil => go (plusdelta + delta) active more
                    | _ => withdelta (plusdelta + delta) nows @ go 0 active more
              end
      in
          go 0 nil t
      end

(*
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
                                print ("myTIME " ^ itos n ^ "/" ^ itos (Util.pow 2 d) ^ "  @ "
                                       ^ itos cpc ^ " bb: " ^ itos bb ^ "\n")
                          | _ => print ("unknown ctrl event: " ^ MIDI.etos evt ^ "\n"))
                   | Bar _ => () (* XXX could play metronome click *)
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
*)


  (* In an already-labeled track set, add measure marker events. *)
  fun add_measures t =
    let
      (* Read through tracks, looking for TIME events in
         Control tracks. 
         Each TIME event starts a measure, naturally.
         We need to find one at 0 time, otherwise this is
         impossible:
         *)
      fun getstarttime nil = (print "(TIME) no events?"; raise Hero "(TIME) no events??")
        | getstarttime ((0, (_, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) :: rest) = ((n, d, cpc, bb), rest)
        | getstarttime ((0, evt) :: t) = 
        let val (x, rest) = getstarttime t
        in (x, (0, evt) :: rest)
        end
        | getstarttime (_ :: t) = (print ("(TIME) no 0 time events"); raise Hero "(TIME) no 0 time events")

      val ((n, d, cpc, bb), rest) = getstarttime t

      val () = if bb <> 8 
               then (messagebox ("The MIDI file may not redefine 32nd notes!");
                     raise Hero "The MIDI file may not redefine 32nd notes!")
               else ()

      (* We ignore the clocksperclick, which gives the metronome rate. Even
         though this is ostensibly what we want, the values are fairly
         unpredictable. *)

      (* First we determine the length of a measure in midi ticks. 
         ?? Here only the ratio is important: 4/4 time has the same measure length as 2/2.

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

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  (* Label all of the tracks
     This uses the track's name to determine its label. *)
  fun label tracks =
      let
          fun onetrack (tr, i) =
              case findname tr of
                  NONE => SOME (Control, tr) (* (print "Discarded track with no name.\n"; NONE) *)
                | SOME "" => SOME (Control, tr) (* (print "Discarded track with empty name.\n"; NONE) *)
                | SOME name => 
                      if List.null includes (* so we can see the list; will die below *)
                         orelse List.exists (fn x => x = i) includes
                      then SOME
                          let in
                              print ("Track " ^ StringUtil.pad ~2 (Int.toString i) ^ ": " ^ name ^ "\n");
                              (case CharVector.sub(name, 0) of
                                   #"+" =>
                                   (case CharVector.sub (name, 1) of
                                        #"Q" => Music INST_SQUARE 
                                      | #"W" => Music INST_SAW 
                                      | #"N" => Music INST_NOISE
                                      | #"S" => Music INST_SINE
                                      | _ => (print "?? expected Q or W or N\n"; raise Hero ""),
                                        tr)
                                 | _ => (print ("confused by named track '" ^ name ^ "'?? expected + or ...\n"); 
                                         (Control, tr))
                                        )
                          end
                      else NONE
      in
          List.mapPartial (fn x => x) (ListUtil.mapi onetrack tracks)
      end

  val tracks = label thetracks

  val () = if List.null includes
           then (print "Specify a list of track numbers to include in the score, as arguments.\n";
                 raise Exit)
           else ()
  val () =
      let
          val tracks = MIDI.mergea tracks
          val tracks = add_measures tracks
          val tracks = normalize tracks
          val tracks = makelengths tracks
          val tracks = measures tracks
          val tracks = render tracks
          (* val tracks = makemidiagain tracks *)
              
      in
          ()
      end handle Hero s => print ("Error: " ^ s  ^ "\n")
                    | e => print ("Uncaught exn: " ^ exnName e ^ "\n")

(*
  val () = app (fn (dt, (lab, evt)) =>
                let in
                  print ("dt: " ^ itos dt ^ "\n")
                end) tracks
*)

end
