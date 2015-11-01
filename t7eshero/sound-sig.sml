(* Low-level sound stuff for T7eshero. *)
signature SOUND =
sig

    exception Sound of string

    (* A sample at the native sample rate. *)
    eqtype sample
    (* A set of 128 samples. *)
    eqtype sampleset

    val silence : sample

    (* Currently, assume 16-bit signed, 44.1khz. Copies the
       vector so it can be safely discarded from the ML side. *)
    val register_sample : int Vector.vector -> sample
    val register_sampleset : sample Vector.vector -> sampleset

    type volume
    (* Convert a midi volume value [0--127] into a native value *)
    val midivel : int -> volume

    (* multiplier on pitch values, so that we can use integers
       to represent fractional values. *)
    val PITCHFACTOR : int

    (* +/- on MIDI notes *)
    val transpose : int ref

    (* The pitch (in Hz * PITCHFACTOR) of the given midi note *)
    val pitchof : int -> int

    (* An instrument is played with MIDI notes. *)
    type inst
    (* A waveform can be played at any frequency. *)
    type waveform

    val INST_NONE : inst
    val INST_SQUARE : inst
    val INST_SAW : inst
    val INST_NOISE : inst
    val INST_SINE : inst
    val INST_RHODES : inst
    val INST_SAMPLER : sampleset -> inst

    val WAVE_NONE : waveform
    val WAVE_SQUARE : waveform
    val WAVE_SAW : waveform
    val WAVE_NOISE : waveform
    val WAVE_SINE : waveform
    val WAVE_RHODES : waveform
    val WAVE_SAMPLER : sampleset -> waveform

    (* setfreq (ch, freq, vol, inst).
       If the waveform is SAMPLER, then freq is the
       sample to play, in the range 0--127. *)
    val setfreq : int * int * volume * waveform -> unit

    (* number of channels *)
    val NMIX : int
    (* channel set aside for sound effects *)
    val MISSCH : int
    (* channels set aside for drums *)
    val DRUMCH : int -> int

    (* noteon (ch, midinote, vol, inst) *)
    val noteon : int * int * volume * inst -> unit

    (* noteoff (ch, midinote) *)
    val noteoff : int * int -> unit

    (* Set the effect amount, from 0.0 (none) to 1.0 (full).
       XXX: Add the ability to configure the active effect!
       *)
    val seteffect : real -> unit

    val all_off : unit -> unit

end
