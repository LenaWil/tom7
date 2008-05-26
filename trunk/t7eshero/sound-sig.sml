(* Low-level sound stuff for T7eshero. *)
signature SOUND =
sig

    (* multiplier on pitch values, so that we can use integers
       to represent fractional values. *)
    val PITCHFACTOR : int

    (* +/- on MIDI notes *)
    val transpose : int ref

    (* The pitch (in Hz * PITCHFACTOR) of the given midi note *)
    val pitchof : int -> int

    type inst

    val INST_NONE : inst
    val INST_SQUARE : inst
    val INST_SAW : inst
    val INST_NOISE : inst
    val INST_SINE : inst

    (* setfreq (ch, freq, vol, inst) *)
    val setfreq : int * int * int * inst -> unit

    (* number of channels *)
    val NMIX : int
    (* channel set aside for sound effects *)
    val MISSCH : int

    (* noteon (ch, midinote, vol, inst) *)
    val noteon : int * int * int * inst -> unit

    (* noteoff (ch, midinote) *)
    val noteoff : int * int -> unit

end
