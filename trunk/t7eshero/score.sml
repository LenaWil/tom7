(* Score concerns the reading of MIDI files and translating them
   into the internal song format. *)
structure Score :> SCORE =
struct

  infixr 9 `
  fun a ` b = a b

  val messagebox = Hero.messagebox

  val itos = Int.toString

  exception Score of string

  type track = (int * (Match.label * MIDI.event)) list

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  type rawmidi = int * MIDI.track list
  fun fromfile f =
    let
      val r = (Reader.fromfile f) handle _ =>
        raise Score ("couldn't read " ^ f)
      val m as (ty, divi, thetracks) = MIDI.readmidi r handle MIDI.MIDI s =>
        let in
          print (s ^ "\n");
          raise Score ("MIDI error: " ^ s)
        end
    in
      ty = 1 orelse
        raise Score ("MIDI file must be type 1 (got type " ^ itos ty ^ ")");
      print ("MIDI division is " ^ itos divi ^ "\n");
      divi > 0 orelse raise Score ("Division must be in PPQN form!\n");
      (divi, thetracks)
    end

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  (* Label all of the tracks
     This uses the track's name to determine its label. *)
  fun label PREDELAY SLOWFACTOR tracks =
    let
      fun foldin (data, tr) : (int * (Match.label * MIDI.event)) list =
          map (fn (d, e) => (d, (data, e))) tr

      fun onetrack (tr, i) =
        case findname tr of
            NONE => SOME ` foldin (Match.Control, tr)
          | SOME "" => SOME ` foldin (Match.Control, tr)
          | SOME name =>
            (case CharVector.sub(name, 0) of
                 #"+" =>
                 SOME `
                 foldin
                 (case CharVector.sub (name, 1) of
                      #"Q" => Match.Music (Sound.INST_SQUARE, i)
                    | #"W" => Match.Music (Sound.INST_SAW, i)
                    | #"N" => Match.Music (Sound.INST_NOISE, i)
                    | #"S" => Match.Music (Sound.INST_SINE, i)
                    | #"R" => Match.Music (Sound.INST_RHODES, i)
                    | #"D" => Match.Music (Sound.INST_SAMPLER Samples.sid, i)
                    | _ => (messagebox "?? expected R, S, Q, W, N, or D\n";
                            raise Score ""),
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
                            NONE =>
                              raise Score "bad tracknum in Score name"
                          | SOME i => i) `
                     String.tokens (StringUtil.ischar #",")
                     ` String.substring(name, 2, size name - 2),
                     tr)
                  | _ => (print "I only support REAL score!";
                          raise Score "real"))

               | _ => (print ("confused by named track '" ^
                              name ^ "'?? expected + or ! ...\n");
                       SOME ` foldin (Match.Control, tr)))
    in
        List.mapPartial (fn x => x) (ListUtil.mapi onetrack tracks)
    end


  (* In an already-labeled track set, add measure marker events. *)
  fun add_measures divi t =
    let
      (* Read through tracks, looking for TIME events in
         Control tracks.
         Each TIME event starts a measure, naturally.
         We need to find one at 0 time, otherwise this is
         impossible:
         *)
      fun getstarttime nil = (messagebox "(TIME) no events?"; raise Score "")
        | getstarttime ((0, (_, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) :: rest) =
          ((n, d, cpc, bb), rest)
        | getstarttime ((0, evt) :: t) =
          let val (x, rest) = getstarttime t
          in (x, (0, evt) :: rest)
          end
        | getstarttime (_ :: t) = (messagebox ("(TIME) no 0 time events");
                                   raise Score "no 0 time events")

      val ((n, d, cpc, bb), rest) = getstarttime t

      val () = if bb <> 8
               then (messagebox ("The MIDI file may not redefine 32nd notes!");
                     raise Score "the midi file may not redefine 32nd notes!")
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

      (* number of ticks at which we place minor bars; at end we place
         a major one *)
      val ticklist = map (fn b => b * beat) beatlist

      fun ibars tl nil = nil (* XXX probably should finish out
                                the measure, draw end bar. *)

        | ibars (ticksleft :: rtl) ((dt, evt) :: rest) =
        (* Which comes first, the next event or our next bar? *)
        if dt <= ticksleft
        then
          (case evt of
             (* Time change event coming up! *)
             (Match.Control, MIDI.META (MIDI.TIME _)) =>
             (* emit dummy event so that we can always start time changes
                with dt 0 *)
               (dt, (Match.Control, DUMMY)) ::
               add_measures divi ((0, evt) :: rest)

           | _ => (dt, evt) :: ibars (ticksleft - dt :: rtl) rest)
        else
          (* if we exhausted the list, then there is a major (measure)
             bar here. *)
          (case rtl of
             nil => (ticksleft, (Match.Bar Hero.Measure, DUMMY)) ::
               ibars ticklist ((dt - ticksleft, evt) :: rest)
           | _   => (ticksleft, (Match.Bar Hero.Beat, DUMMY)) ::
               ibars rtl      ((dt - ticksleft, evt) :: rest))

        | ibars nil _ = raise Score "tickslist never nil" (* 0/4 time?? *)

    in
      (0, (Match.Control, MIDI.META (MIDI.TIME (n, d, cpc, bb)))) ::
      (0, (Match.Bar (Hero.Timesig (n, Util.pow 2 d)), DUMMY)) ::
      ibars ticklist rest
    end

  (* fun slow l = map (fn (delta, e) => (delta * 6, e)) l *)
  fun slow SLOWFACTOR l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l

  (* How to complete pre-delay? *)
  fun delay PREDELAY t = (PREDELAY, (Match.Control, DUMMY)) :: t

  (* Replace forced end label with real end. *)
  fun endify nil = nil
    | endify ((f as (_, (_, MIDI.META (MIDI.MARK m)))) :: r) =
      if m = "!END"
      then nil
      else f :: endify r
    | endify (f :: r) = f :: endify r

  fun assemble { file : string,
                 slowfactor : int,
                 hard : int,
                 fave : int,
                 title : string,
                 artist : string,
                 year : string,
                 id : Setlist.songid } =
    let
      val (divi, thetracks) = fromfile file
      val divi = divi * slowfactor
      val PREDELAY = 2 * divi (* ?? *)
      val (tracks : (int * (Match.label * MIDI.event)) list list) =
        label PREDELAY slowfactor thetracks
      val tracks = slow slowfactor (MIDI.merge tracks)
      val tracks = add_measures divi tracks
      val tracks = endify tracks
      val (tracks : (int * (Match.label * MIDI.event)) list) =
        delay PREDELAY tracks
    in
      tracks
    end

end
