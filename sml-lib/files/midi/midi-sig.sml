
signature MIDI =
sig

  datatype meta =
      END
    | SEQNO of int option
    | TEMPO of int

    | TEXT of string
    | COPY of string
    | NAME of string
    | INST of string
    | LYRIC of string
    | MARK of string
    | CUE of string
    | PROG of string
    | DEV of string

      (* hr mn sec fr subfr *)
    | SMPTE of int * int * int * int * int
      (* numerator log(denominator) clocksperclick bb 
         bb is the number of 32nd notes in a MIDI quarter-note
            (=24 clocks). 
         *)
    | TIME of int * int * int * int

    (* sharps/flats maj/minor *)
    | KEY of int * bool
      
    (* proprietary data, like sysex *)
    | PROP of string
    (* unknown *)
    | OTHER of int * string

  datatype event =
      (* channel note vel *)
      NOTEON of int * int * int
    | NOTEOFF of int * int * int (* vel = 0 ?? *)
    (* channel program *)
    | PCHANGE of int * int
    (* channel controller value *)
    | CONTROL of int * int * int
    (* channel pitch1 pitch2 (??) *)
    | PITCH of int * int * int
    (* sysex data *)
    | SYSEX of CharVector.vector
      
    | META of meta

  type reader = Reader.reader

  val etos : event -> string

  (* a track is a list of delta-times (ticks since last event) and
     events *)
  type track = (int * event) list

  (* merge tracks into a single track (meta events are not treated
     specially, meaning the result may have multiple names, etc.) *)
  val merge : track list -> track
  (* as above, but preserve the 0-based track number that the
     event came from. *)
  val mergei : track list -> (int * (int * event)) list
  (* and with arbitrary data *)
  val mergea : ('a * (int * event) list) list -> (int * ('a * event)) list

  exception MIDI of string

  (* returns (midi type, division, tracks)
     leaving out chunk types it doesn't understand.
     midi type and division are as defined in the MIDI spec. *)
  val readmidi  : reader -> int * int * track list

  (* write a midi file of the same format to disk. *)
  (* type 1 is recommended *)
  val writemidi : string -> int * int * track list -> unit

end
