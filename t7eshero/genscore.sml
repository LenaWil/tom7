
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
  type ptr = MLton.Pointer.t
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

  (* FIXME totally ad hoc!! *)
  val itos = Int.toString

  val (f, includes) = 
      (case CommandLine.arguments() of 
           st :: includes => (st,
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
                  (* We don't care about control messages, channels, instruments, or velocities. *)
                  val ending = List.mapPartial (fn (Music _, MIDI.NOTEON(ch, note, 0)) => SOME note
                                                 | (Music _, MIDI.NOTEOFF(ch, note, _)) => SOME note
                                                 | _ => NONE) nowevts
                  val starting = List.mapPartial (fn (Music _, MIDI.NOTEON(ch, note, 0)) => NONE
                                                   | (Music _, MIDI.NOTEON(ch, note, vel)) => SOME note
                                                   | _ => NONE) nowevts
                  val bars = List.mapPartial (fn (Bar b, _) => SOME b | _ => NONE) nowevts

                  (* okay, so we have some notes ending this instant ('ending'),
                     and some notes starting ('starting'), and maybe some other stuff ('bars').
                     First we need to turn off any active notes that are ending now, so we don't
                     get confused into thinking they're still active. *)
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

  val () = if List.null includes
           then (print "Specify a list of track numbers to include in the score, as arguments.\n";
                 raise Exit)
           else ()
  val () =
      let
          val tracks = label thetracks
          val tracks = MIDI.mergea tracks
          val tracks = add_measures tracks
          val tracks = normalize tracks
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
