
(* Tom 7 Entertainment System Hero!

   This program generates default scores for a song (in a midi file)
   using the notes actually played as a guide.

   This is very simple; doing a good job needs a certain amount of
   human input to understand how the song "feels", particularly
   with regard to repeating phrases in which there are some things
   that should be obviously "up" vs. "down".
   (Actually I do that now. See below.)

   One important thing we do is to make sure that there are no
   illegal overlaps: a note that starts while another note is
   active. If the second note starts after the first, we terminate
   the first one at that point. If they both start at the same time
   on the same fret, we erase the one with the earlier finish.

   To run this program, you must specify which tracks the score
   should be derived from. The track numbers are displayed when
   the program is run without any tracks specified.

*)

structure T7ESHero =
struct

  fun messagebox s = print (s ^ "\n")

  infixr 9 `
  fun a ` b = a b

  exception Nope

  exception Hero of string
  exception Exit

  val watermark_min =
    Params.param "2" (SOME("-watermark",
                           "Make zero-length notes actually be this long " ^
                           "(measured in MIDI ticks)"))
                         "watermark"

  val nomeasurehist =
    Params.flag false (SOME("-noxmeasure",
                            "Don't save history across measure (sometimes " ^
                            "produces better scores)"))
                         "noxmeasure"

  val nosort =
    Params.flag false (SOME("-nosort",
                            "Don't sort notes (sometimes makes weirder, " ^
                            "and thus better, scores)"))
                         "nosort"

  val output =
    Params.param "genscore.mid" (SOME("-o", "Set the output file."))
                         "output"

  val hammertime =
    Params.param "25" (SOME("-hammertime",
                            "Threshold (in MIDI ticks) for allowing " ^
                            "hammering"))
                         "hammertime"

  (* more than about 5 will make this consume gigabytes of memory -- it's
     exponential. *)
  val history =
    Params.param "1" (SOME("-history",
                           "Events of history to consider during assignment."))
                         "history"

  val volscale =
    Params.param "1.0" (SOME("-volscale",
                             "Scale the velocity of all (nonzero) notes by " ^
                             "this fraction. Notes are still capped to the " ^
                             "maximum and minimum volumes, so this may " ^
                             "reduce (or completely flatten) dynamic range."))
    "volscale"

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  datatype bar =
      Measure
    | Beat
    | Timesig of int * int
    | Nothing

  (* XXX these should describe what kind of track it is *)
  datatype label =
      Music
    | Control
    | Bar of bar

  (* must agree with sound.c *)
  val legal_instruments = ["Q", "W", "S", "N", "R", "D"]
  fun is_legal s = List.exists (fn s' => s = s') legal_instruments

  val itos = Int.toString

  val (f, includes) =
    (case Params.docommandline() of
       st :: includes =>
         (st,
          map (fn SOME i => i
        | NONE => (print ("Expected a series of track numbers after " ^
                          "the filename\n");
                   print "Also:\n";
                   print (Params.usage());
                   raise Exit)) (map Int.fromString includes))
     | _ => (print "Expected a MIDI file on the command line.\n";
             print "Also:\n";
             print (Params.usage());
             raise Exit))

  val r = (Reader.fromfile f) handle _ =>
      raise Hero ("couldn't read " ^ f)
  val m as (ty, divi, thetracks) = MIDI.readmidi r
       handle e as (MIDI.MIDI s) =>
         (print("Couldn't read MIDI file: " ^ s ^ "\n");
          raise e)

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

  fun printmeasures t =
    let
      fun show_measure m =
        StringUtil.delimit " "
        (map (fn (d, nots) =>
              "(" ^
              Int.toString d ^ ", [" ^
              StringUtil.delimit ", " (map (fn (n, len) =>
                                            Int.toString n ^ ":" ^
                                            Int.toString len) nots) ^
              "])") m)
    in
      List.app (fn m => print (show_measure m ^ "\n")) t
    end

  val RADIX = 5 (* XXX configurable. Also, include open? *)
  val gamut = List.tabulate (RADIX, fn x => x)
  val OFFSET = 0

  (* after rendering, make back into a midi track
     (only NOTEON and NOTEOFF events). *)

  val DEF_CHANNEL = 1   (* shouldn't really matter *)
  val DEF_VEL     = 127 (* has to be greater than 64 *)
  val HAM_VEL     = 32  (* and less than 64 *)
  fun humidify (t : measure list) =
    let
      (* val () = print "humidify:\n"
      val () = printmeasures t *)
      fun make subtract ((delta, ndl) :: rest) =
        let in
(*
          print ("make " ^ Int.toString subtract ^ " (" ^ Int.toString delta
                 ^ ", [" ^ StringUtil.delimit ", "
                       (map (fn (n,l) =>
                             "(" ^ Int.toString n ^ ":" ^
                                   Int.toString l ^ ")")
                        ndl) ^ "]\n");
*)
        if delta < subtract
        then raise Hero ("Wasn't normalized, oops: " ^ Int.toString delta ^
                         " < " ^ Int.toString subtract)
        else
          let
              (* sort by length so that we can emit their OFFs in
                 the right order *)
              val ndl = ListUtil.sort (ListUtil.bysecond Int.compare) ndl
              val () = if List.null ndl
                       then raise Hero "humidify: note notes in event!"
                       else ()

              val hammer = length ndl = 1 andalso
                delta < Params.asint 0 hammertime
          in
            (* (there's always at least one note) *)
            (delta - subtract,
             MIDI.NOTEON(DEF_CHANNEL, OFFSET + #1 (hd ndl),
                         if hammer
                         then HAM_VEL
                         else DEF_VEL)) ::
            map (fn (n, len) =>
                 (0, MIDI.NOTEON(DEF_CHANNEL, OFFSET + n,
                                 if hammer
                                 then HAM_VEL
                                 else DEF_VEL))) (tl ndl) @

            (* then the offs *)
            let
              fun eat dt [(lastn, lastlen)] =
                (lastlen - dt, MIDI.NOTEOFF(DEF_CHANNEL, OFFSET + lastn, 0)) ::
                (* now that we've emitted some note-offs, the deltas
                   for the next measure event are inaccurate by the
                   length of the longest note. that's this one. *)
                make lastlen rest
                | eat dt ((n, len) :: more) =
                (len - dt, MIDI.NOTEOFF(DEF_CHANNEL, OFFSET + n, 0)) ::
                eat len more
                | eat dt nil = raise Hero "no notes in measureevent"
              in
                eat 0 ndl
              end
          end
      end
      | make _ nil = nil
    in
      make 0 (List.concat t)
    end

  val DISCOUNT = 4

  (* Render a single measure. We got rid of the deltas and lengths.

     Returns the assignment as a list of pairs of (old notes, finger
     assignments). Takes the assignment that was given for the
     previous measure (An empty list has the effect of ignoring any
     prior context.)

     done and total are just the counts of measures done and total,
     for printing progress. *)
  fun render_one (prev_measure : (int list * int list) list)
                 (m : int list list)
                 (measures_done, measures_total) =
    let
      val HISTORY = Params.asint 1 history

      val total = ref 0
      (* given the assignment for the previous event(s), compute the best
         possible assignment for the tail, and its penalty. *)

      fun best_rest BEST_REST (_, nil) = (nil, 0)
        | best_rest BEST_REST (hist, ns :: rest) =
        let
          (* hist = (evt, ass) :: ... *)

          val () = (total := !total + 1;
                    if (!total mod 50000) = 0
                    then print (f ^ " [" ^ Int.toString measures_done ^ "/" ^
                                Int.toString measures_total ^ "]: " ^
                                Int.toString (!total) ^ "\n")
                    else ())

          (* all legal assignments for evt.
             It turns out this only depends on
             the length of evt; its cardinality is
             RADIX choose (length evt).
             *)
          fun all_assignments n = ListUtil.choosek n gamut

          val olds = map ListPair.zip hist

          (* The heart of genscore. Compute a penalty for this
             assignment relative to a previous assignment.

             The penalty is "linear" over the components of
             the soneme, so we do this note by note.

             nb. I think it might make sense to hard-code the
             case where the event is the same as the previous
             one, so that we don't bother trying all of the
             possibilities in that case. (That is, consider
             the adjacent non-equal penalty infinite and then
             optimize out the infinitely costly alternatives.)
             *)
          fun this_penalty old (enew, anew) =
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
              val () = if List.null news
                       then raise Hero "assignment was empty??"
                       else ()
            in
              ListPair.foldl (fn (old, new, s) =>
                              s + note_penalty old new) 0 (old, news)
            end

          (* compute the penalty relative to all olds. we discount as we
             get deeper into the list (older notes) *)
          fun all_penalty assignment =
            let
              fun ap acc _ nil = acc
                | ap acc 0 _ = acc
                | ap acc n (old :: more) =
                ap (acc * DISCOUNT + this_penalty old assignment) (n - 1) more
            in
              ap 0 HISTORY olds
            end

          val nns = length ns
          val (nns, ns) = if nns > RADIX
                          then
                            let in
                              print "can't do (real) chords larger than radix!";
                              (RADIX, List.take (ns, RADIX))
                            end
                          else (nns, ns)

          val () = if nns = 0
                   then raise Hero "chord is empty!"
                   else ()

          (* try all, choose best. *)
          fun getbest (best, bestpen) (ass :: more) =
            let
              val (tail, tailpen) = BEST_REST ((ns, ass) :: hist, rest)
              val pen = all_penalty (ns, ass)
            in
              if pen + tailpen < bestpen
              then getbest ((ns, ass) :: tail, pen + tailpen) more
              else getbest (best, bestpen) more
            end
            | getbest (best, bestpen) nil = (best, bestpen)

        in
          getbest (nil, 9999999) (all_assignments nns)
        end

      (* Hash, only looking at the first HISTORY elements of l *)
      fun hash_list_hist (l : (int list * int list) list, ill : int list list) =
        let
          (* hash intlist *)
          fun hil s nil = s
            | hil s (h :: t) = hil (s + 0wx123457) t + (s * Word32.fromInt h)

          fun elh 0 _ = 0wxDEADBEEF
            | elh _ nil = 0wxDEADBEEF
            | elh n ((ha, hb) :: t) = (Word32.fromInt n) *
            (hil (Word32.fromInt n * 0w11) ha) +
            (hil (Word32.notb(Word32.fromInt n)) hb) +
            elh (n - 1) t

          fun el nil = 0wx5E18008
            | el (h :: t) = 0w7 * (hil 0w257 h) + el t
        in
          Word32.xorb (el ill, elh HISTORY l)
        end

      fun cmp_list_hist ((l1 : (int list * int list) list,
                          ill1 : int list list), (l2, ill2)) =
        let
          val cl = Util.lex_list_order Int.compare
          val cll = Util.lex_list_order cl
          fun elh 0 _ = EQUAL
            | elh _ (nil, nil) = EQUAL
            | elh n ((ha, hb) :: t, (ha', hb') :: t') =
            (case cl (ha, ha') of
               LESS => LESS
             | GREATER => GREATER
             | EQUAL =>
                 (case cl (hb, hb') of
                    LESS => LESS
                  | GREATER => GREATER
                  | EQUAL => elh (n - 1) (t, t')))
            | elh _ (_ :: _, nil) = LESS
            | elh _ (nil, _ :: _) = GREATER
        in
          case elh HISTORY (l1, l2) of
            EQUAL => cll (ill1, ill2)
          | ord => ord
        end

      (* maybe hash would be faster? *)
      val tabler = Memoize.cmp_tabler cmp_list_hist
      val best_rest = Memoize.memoizerec tabler best_rest

(*
      val () = print ("Assign a measure of length: " ^
                      Int.toString (length m) ^
                      " with history: " ^ Int.toString HISTORY ^
                      "\n")
*)

      (* We start with the history of the previous measure's assignment
         (only). This helps especially when important transitions
         only happen at measure boundaries. Recall that the history
         is stored in reverse order from the assignment. *)
      val (best, bestpen) = best_rest (rev prev_measure, m)
    in
(*
      print ("Got best penalty of " ^ Int.toString bestpen ^ " with " ^
             Int.toString (!total) ^ " assignments viewed\n");
*)
      best
    end

  (* Do the rendering once it's been normalized. *)
  fun render (t : measure list) =
    let
      (* val () = print "render:\n" *)
      val () = printmeasures t

      (* Maps measures we've already rendered to their rendered versions. *)
      (* XXX should probably render independent of deltas, since the delta
         on the first note tells us something about what came before it.
         assignments don't use deltas, anyway. *)
      val completed = ref (MM.empty)
      fun get m = MM.find(!completed, m)

      (* Compute the assignment for the measure and return it. Put the
         re-lengthend result along with the raw assignment (for
         cross-measure history) in the completed cache. Optionally
         gets the assignment for the previous measure. *)
      fun do_one prev m =
        let
          (* we don't care about the deltas, or the note lengths
             for the purposes of assignment. take those out first. *)
          val (dels : int list, sons : (int * int) list list) =
            ListPair.unzip m
          val notslens : (int list * int list) list =
            map ListPair.unzip sons
          val (nots : int list list, lens : int list list) =
            ListPair.unzip notslens

          val () = if List.exists List.null nots
                   then raise Hero "empty notes"
                   else ()

          val assignment =
            render_one (Option.getOpt (prev, nil)) nots
                       (MM.numItems (!completed), length t)
          val nots = map #2 assignment

          val notslens : (int list * int list) list = ListPair.zip (nots, lens)

          (* Now put them back together... *)
          val sons' = map ListPair.zip notslens
          val res = ListPair.zip (dels, sons')
        in
          completed := MM.insert(!completed, m, (res, assignment));
          assignment
        end

      (* Do one, returning its assignment. If we've already done it and it's
         in the cache, use that, but still return the assignment
         in case the next measure is fresh. *)
      fun maybe_do_one prev m =
        case get m of
          NONE => do_one prev m
        | SOME (_, this) => this

      (* Apply, also passing along (SOME r) where r is the result of
         application to the previous element, if any. *)
      fun appwithprev (f : 'b option -> 'a -> 'b) (l : 'a list) =
        let
          fun awp _ nil = ()
            | awp (p : 'b option) (h :: t) =
            let val r = f p h
            in awp (SOME r) t
            end
        in
          awp NONE l
        end

    in
      appwithprev maybe_do_one t;
      map (fn m =>
           case get m of
             SOME (n, _) => n
           | NONE =>
               raise Hero "After rendering, a measure wasn't completed?") t
    end

  (* Chunk the song into measures. This is really simple now
     that NOTES events have lengths in them, the only complication
     being deltas on events that we want to ignore, like LBAR Nothing. *)
  fun measures (t : (int * lengthened) list) =
    let
(*
      val () = print "Measures:"
      val () =
          let
              fun pnorm (BAR bar) = "BAR"
                | pnorm (OFF i) = "OFF:" ^ Int.toString i
                | pnorm (ON i) = "ON:" ^ Int.toString i
              fun plen (LBAR bar) = "BAR"
                | plen (NOTES iiorl) =
                  "[" ^ StringUtil.delimit ", "
                        (map (fn (i, ior) =>
                              Int.toString i ^ ":" ^
                              (case !ior of
                                   NONE => "?"
                                 | SOME l => Int.toString l)) iiorl) ^ "]"
          in
              print (StringUtil.delimit "  " (map (fn (d, l) =>
                                                  "(" ^ Int.toString d ^ ", " ^
                                                   plen l ^ ")") t))
          end
*)

      (* All measures so far, in reverse *)
      val revmeasures = ref nil
      fun newmeasure revd = revmeasures := (rev revd) :: !revmeasures

      fun read this xdelta nil = newmeasure this
        | read this xdelta ((d, NOTES ns) :: rest) =
        let
          fun getlength (n, ref (SOME l)) = (n, l)
            | getlength _ = raise Hero "NOTES's length not set!"

          val () = if List.null ns
                   then raise Hero "measures: ns empty??"
                   else ()
        in
          read ((d + xdelta, map getlength ns) :: this) 0 rest
        end
        | read this xdelta ((d, LBAR Measure) :: rest) =
        (newmeasure this;
         read nil (d + xdelta) rest)
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

          val notes = map onenow nows
          val () = if List.null notes
                   then raise Hero "no now notes?"
                   else ()

          val notes =
            if !nosort
            then notes
            else ListUtil.sort (ListUtil.byfirst Int.compare) notes
        in
          (d, NOTES notes) :: write (ticks + d) thens
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
        | getnow acc l = (rev acc, l)

      fun withdelta plusdelta nil = raise Hero "withdelta on nil"
        | withdelta plusdelta (e :: rest) =
        (plusdelta, e) :: map (fn ee => (0, ee)) rest

      fun go plusdelta nil nil = nil
        | go plusdelta (active : int list) nil =
        (* if there are any active at the end, then stop 'em *)
        withdelta plusdelta ` map finish active
        | go plusdelta active ((delta, first) :: more) =
        let
          val (nowevts, more) = getnow nil more
          val nowevts = first :: nowevts
          (* We don't care about control messages, channels, instruments, or
             velocities. *)
          val ending = List.mapPartial
            (fn (Music, MIDI.NOTEON(ch, note, 0)) => SOME note
          | (Music, MIDI.NOTEOFF(ch, note, _)) => SOME note
          | _ => NONE) nowevts
          val starting = List.mapPartial
            (fn (Music, MIDI.NOTEON(ch, note, 0)) => NONE
          | (Music, MIDI.NOTEON(ch, note, vel)) => SOME note
          | _ => NONE) nowevts
          val bars = List.mapPartial (fn (Bar b, _) => SOME b | _ => NONE)
            nowevts

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
                       print ("Note " ^ Int.toString note ^
                              " was not active but turned off?\n");
                       rem stops active rest
                     end
                 | _ => raise Hero "invt violation: note multiply active!")
                | rem stops active nil = (stops, active)

            in
              rem nil active ending
            end

          (* If we are starting new notes here, we have to kill anything that's
             now still active. This is the main way we establish the
             invariant. *)
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
                      print ("Note begun multiple times: " ^
                             Int.toString note ^ "\n");
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

  (* In an already-labeled track set, add measure marker events. *)
  fun add_measures t =
    let
      (* Read through tracks, looking for TIME events in
         Control tracks.
         Each TIME event starts a measure, naturally.
         We need to find one at 0 time, otherwise this is
         impossible:
         *)
      fun getstarttime nil = (print "(TIME) no events?";
                              raise Hero "(TIME) no events??")
        | getstarttime ((0, (_, MIDI.META (MIDI.TIME (n, d,
                                                      cpc, bb)))) :: rest) =
          ((n, d, cpc, bb), rest)
        | getstarttime ((0, evt) :: t) =
          let val (x, rest) = getstarttime t
          in (x, (0, evt) :: rest)
          end
        | getstarttime (_ :: t) = (print ("(TIME) no 0 time events");
                                   raise Hero "(TIME) no 0 time events")

      val ((n, d, cpc, bb), rest) = getstarttime t

      val () = if bb <> 8
               then (messagebox ("The MIDI file may not redefine 32nd notes!");
                     raise Hero "The MIDI file may not redefine 32nd notes!")
               else ()

      (* We ignore the clocksperclick, which gives the metronome rate. Even
         though this is ostensibly what we want, the values are fairly
         unpredictable. *)

      (* First we determine the length of a measure in midi ticks.

         ?? Here only the ratio is important: 4/4 time has the same
         measure length as 2/2.

         The midi division tells us how many clicks there are in a
         quarter note.

         The denominator tells us how many beats there are per
         measure. So we can first compute the number of midi ticks in
         a beat: *)
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
      val () = print ("And the measure value is: " ^ Int.toString measure ^
                      "\n")

      (* XXX would be better if we could also additionally label the beats when
         using a complex time, like for sensations: 5,5,6,5. Instead we just
         put one minor bar for each beat. *)

      (* For now the beat list is always [1, 1, 1, 1 ...] so that we put
         a minor bar on every beat. *)
      val beatlist = List.tabulate (n, fn _ => 1)

      (* FIXME test *)
      (* val beatlist = [5, 5, 6, 5] *)

      (* number of ticks at which we place minor bars; at end we place a
         major one *)
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
               (* emit dummy event so that we can always start time
                  changes with dt 0 *)
               (dt, (Control, DUMMY)) :: add_measures ((0, evt) :: rest)
           | _ => (dt, evt) :: ibars (ticksleft - dt :: rtl) rest)
        else
          (* if we exhausted the list, then there is a major (measure)
             bar here. *)
          (case rtl of
             nil => (ticksleft, (Bar Measure, DUMMY)) ::
               ibars ticklist ((dt - ticksleft, evt) :: rest)
           | _   => (ticksleft, (Bar Beat, DUMMY)) ::
               ibars rtl      ((dt - ticksleft, evt) :: rest))

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
          NONE => (* (print "Discarded track with no name.\n"; NONE) *)
            SOME (Control, tr)

        | SOME "" => (* (print "Discarded track with empty name.\n"; NONE) *)
            SOME (Control, tr)
        | SOME name =>
            if List.null includes (* so we can see the list; will die below *)
               orelse List.exists (fn x => x = i) includes
            then SOME
              let in
                print ("Track " ^ StringUtil.pad ~2 (Int.toString i) ^
                       ": " ^ name ^ "\n");
                case CharVector.sub(name, 0) of
                  #"+" =>
                  let val s = String.substring(name, 1, 1)
                  in
                    if is_legal s
                    then (Music, tr)
                    else (print ("Not a legal instrument code: " ^ s ^ "\n");
                          raise Hero "")
                  end
                | _ => (print ("confused by named track '" ^ name ^
                               "'?? expected + or ...\n");
                        (Control, tr))
              end
            else NONE
      in
        List.mapPartial (fn x => x) (ListUtil.mapi onetrack tracks)
      end

  (* Correct for zero-length NOTEON-NOTEOFF spans, by making them have
     watermark_min length. This is easy. For each group of events (which
     is an initial event and all the events that occur 0 delta ticks
     after it) we see if there is a NOTEON with a corresponding NOTEOFF
     occurring later in the list. If so, we push that NOTEOFF event forward
     into the event stream (except we stop and deposit it early if we
     encounter another matching NOTEON event). *)
  fun watermark (tr : (int * MIDI.event) list) =
    let
      fun push_off (ch, note) dt nil = [(dt, MIDI.NOTEOFF(ch, note, 0))]
        | push_off (ch, note) dt ((t, evt) :: rest) =
        (* does the new event come before or after the head? *)
        if dt <= t
        then (dt, MIDI.NOTEOFF(ch, note, 0)) :: (t - dt, evt) :: rest
        else
          let fun skip () = (t, evt) :: push_off (ch, note) (dt - t) rest
          in case evt of
            MIDI.NOTEON(ch', note', v') =>
              if ch = ch' andalso note = note'
              then (* deposit early. *)
                push_off (ch, note) t ((t, evt) :: rest)
              else skip ()
          | _ => skip ()
          end
    in
      case tr of
        nil => nil
      | (this as (t, MIDI.NOTEON(ch, note, v))) :: rest =>
          let
            fun ensure nil = nil
              | ensure ((that as (0, MIDI.NOTEON(ch', note', 0))) :: more) =
              ensure ((0, MIDI.NOTEOFF(ch', note', 0)) :: more)
              | ensure ((that as (0, MIDI.NOTEOFF(ch', note', _))) :: more) =
              if ch = ch' andalso note = note'
              then
                let in
                  print ("Making minimum watermark for " ^ itos ch ^
                         "/" ^ itos note ^ "\n");
                  push_off (ch, note) (Params.asint 1 watermark_min) more
                end
              else
                let in
                  (* print "ensure: not same noteoff\n"; *)
                  that :: ensure more
                end
              | ensure ((that as (0, evt)) :: more) =
                let in
                  (* print "ensure: not noteoff\n"; *)
                  that :: ensure more
                end
              | ensure later = later
          in
            this :: watermark (ensure rest)
          end
      | next :: rest => next :: watermark rest
    end

  fun scalevel r (tr : (int * MIDI.event) list) =
    let
      (* 0 is special; means NOTEOFF to many systems. *)
      val over = ref 0
      val under = ref 0
      fun makevel 0 = 0
        | makevel v =
        let val nv = Real.round (r * real v)
        in
          if nv < 1 then
             let in
               under := 1 + !under;
               1
             end
          else if nv > 127
               then
                 let in
                   over := 1 + !over;
                   127
                 end
               else nv
        end

      fun oneevent (dt, MIDI.NOTEON(ch, note, vel)) =
        (dt, MIDI.NOTEON(ch, note, makevel vel))
        | oneevent other = other
      val tr = map oneevent tr
    in
      if !over > 0 orelse !under > 0
      then print ("Velocity scale: Capped " ^ itos (!over) ^ " note(s) " ^
                  "over 127 and " ^ itos (!under) ^ " note(s) under 1.\n")
      else ();
      tr
    end

  (* val () = MIDI.writemidi "copy.mid" (1, divi, thetracks) *)

  val thetracks = map watermark thetracks
  val thetracks = map (scalevel (Params.asreal 1.0 volscale)) thetracks
  val tracks = label thetracks

  val () = if List.null includes
           then (print ("Specify a list of track numbers to include " ^
                        "in the score, as arguments.\n");
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
      val tracks = humidify tracks
      (* we only generate REAL score for now *)
      val tracks = (0, MIDI.META `
                    MIDI.NAME ("!R" ^
                               StringUtil.delimit ","
                               (map Int.toString includes))) :: tracks
      val tracks = thetracks @ [tracks]
    in
      MIDI.writemidi (!output) (1, divi, tracks)
    end handle Hero s => print ("Error: " ^ s  ^ "\n")
                  | e => print ("Uncaught exn: " ^ exnName e ^ "\n")

(*
  val () = app (fn (dt, (lab, evt)) =>
                let in
                  print ("dt: " ^ itos dt ^ "\n")
                end) tracks
*)

end
