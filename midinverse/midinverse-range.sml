(* Compute the inverse of a MIDI file.

   This version is like -sustain but rather than treat the gamut of
   notes as being 0-127 (all MIDI notes), we consider only the ones
   that are ever turned on for that track.
 *)
structure MIDInverse =
struct

  infixr 9 `
  fun a ` b = a b

  exception Nope

  exception MIDInverse of string
  exception Exit

  val outputp = Params.param "" (SOME("-o", "Set the output file.")) "output"
  val rangep = Params.flag false (SOME("-range", "If set, then the range of notes " ^
                                       "(that we invert to) is determined by each " ^
                                       "input track.")) "range"
  val gamutp = Params.flag false (SOME ("-gamut", "If set, then the notes that we " ^
                                        "invert to are the ones that appear in a " ^
                                        "track. Implies -range.")) "gamut"

  fun getoutput song =
      case !outputp of
          "" => let val (base, ext) = FSUtil.splitext song
                in base ^ "-inverted." ^ ext
                end
        | s => s

  val itos = Int.toString
  fun eprint s = TextIO.output(TextIO.stdErr, s)

  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  fun getchannel ((_, MIDI.NOTEON (ch, _, _)) :: _) = SOME ch
    | getchannel ((_, MIDI.NOTEOFF (ch, _, _)) :: _) = SOME ch
    | getchannel (_ :: l) = getchannel l
    | getchannel nil = NONE

  fun getoutputmask (t : (int * MIDI.event) list) =
    let
        val min = ref 127
        val max = ref 0
        (* Did we see this note used? *)
        val mask = Array.array (128, false)

        fun see note =
            let in
                if note < !min
                then min := note
                else ();
                if note > !max
                then max := note
                else ();
                Array.update (mask, note, true)
            end

        fun doevent (_, e) =
            case e of
                MIDI.NOTEON (_, note, _) => see note
              | MIDI.NOTEOFF (_, note, _) => see note
              | _ => ()
        val () = app doevent t
    in
        case (!rangep, !gamutp) of
          (false, false) => Array.array (128, true)
        | (true, false) => Array.tabulate (128, fn i => i >= !min andalso i <= !max)
        | (_, true) => mask
    end

  fun inverttrack (t : (int * MIDI.event) list) =
    let
      val outputmask = getoutputmask t
    in
      (* All the note events in the track should be in the
         same channel, so start by just getting that to simplify
         matters (and later verify) *)
      case getchannel t of
          (* No note events in track *)
          NONE => t
        | SOME channel =>
        let
            (* Whether the numbered note is on, in the input song
               and inverted song respectively. *)
            val state = Array.array (128, false)
            val invstate = Array.array (128, false)
            val lastvel = ref 64

            fun gen nil =
                (* XXX Turn off any notes that are on? *)
                let val offs = ref nil
                in
                    Util.for 0 127
                    (fn note =>
                     if Array.sub(invstate, note)
                     then offs := (0, MIDI.NOTEON(channel, note, 0)) :: !offs
                     else ());
                    rev (!offs)
                end
              | gen ((delta, event) :: rest) =
                let
                    fun getnow ((0, e) :: r) =
                        let val (nows, rest) = getnow r
                        in (e :: nows, rest)
                        end
                      | getnow r = (nil, r)

                    val (now, rest) = getnow rest
                    (* All the events happening right this instant. *)
                    val now = event :: now

                    datatype noteevent =
                        (* note, vel *)
                        On of int * int
                      | Off of int
                    fun cleave nil = (nil, nil)
                      | cleave (e :: rest) =
                        let
                            val (n, nn) = cleave rest
                        in
                            case e of
                                MIDI.NOTEON (ch, note, vel) =>
                                    if ch <> channel
                                    then raise MIDInverse "channel mismatch"
                                    else
                                        if vel = 0
                                        then (Off note :: n, nn)
                                        else (On (note, vel) :: n, nn)
                              | MIDI.NOTEOFF (ch, note, _) =>
                                    if ch <> channel
                                    then raise MIDInverse "channel mismatch off"
                                    else (Off note :: n, nn)
                              | other => (n, other :: nn)
                        end
                    val (notes, notnotes) = cleave now

                    (* apply note events to the new state, etc. *)
                    (* XXX figure out how to use velocity? *)
                    fun apply (On (note, vel)) =
                        let in
                            lastvel := vel;
                            Array.update (state, note, true)
                        end
                      | apply (Off note) = Array.update (state, note, false)

                    val () = app apply notes
                    val notes = ()

                    (* Now figure out what to emit to turn the current invstate
                       into the desired state. *)
                    val desired = Array.tabulate (Array.length state,
                                                  fn i =>
                                                  (* Only if it appears in the mask. *)
                                                  Array.sub(outputmask, i) andalso
                                                  (* And the opposite of what the song has. *)
                                                  not ` Array.sub(state, i))
                    val invnotes = ref nil
                    val () =
                        Util.for 0 127
                        (fn i =>
                         case (Array.sub (invstate, i), Array.sub (desired, i)) of
                             (false, true) =>
                                 invnotes := MIDI.NOTEON (channel, i, !lastvel) :: !invnotes
                           | (true, false) =>
                                 invnotes := MIDI.NOTEON (channel, i, 0) :: !invnotes
                           | _ => ())

                    (* First one gets real delta, rest are zero *)
                    val (invnow_first : MIDI.event, invnow_rest : MIDI.event list) =
                       case rev (!invnotes) @ notnotes of
                         nil => (DUMMY, nil)
                       | h :: t => (h, t)

                    val nowevents = (delta, invnow_first) ::
                       map (fn e => (0, e)) invnow_rest
                in
                    (* Now the inv state is achieved *)
                    Array.copy { di = 0, dst = invstate, src = desired };
                    (* eprint ` itos delta; eprint "\n"; *)
                    nowevents @ gen rest
                end
        in
            gen t
        end
    end

  fun invert song =
  let
    val OUTPUT = getoutput song
    val r = (Reader.fromfile song) handle _ =>
      raise MIDInverse ("couldn't read " ^ song)
    val m as (ty, divi, thetracks) = MIDI.readmidi r
        handle e as (MIDI.MIDI s) => raise MIDInverse ("Couldn't read MIDI file: " ^ s ^ "\n")
    val _ = ty = 1
        orelse raise MIDInverse ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
    val () = eprint ("MIDI division is " ^ itos divi ^ "\n")
    val _ = divi > 0
        orelse raise MIDInverse ("Division must be in PPQN form!\n")

    val tracks = map inverttrack thetracks
  in
    MIDI.writemidi OUTPUT (1, divi, tracks)
  end

end

val () = Params.main1 "Command-line argument: the midi file to invert." MIDInverse.invert
