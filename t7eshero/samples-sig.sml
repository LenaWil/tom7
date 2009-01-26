
signature SAMPLES =
sig
    (* A sample set for this purpose is 128 samples, with a fixed meaning.
       Samples [35--81] are defined by General MIDI and for the rest
       we use the Roland SC-880's assignment. *)

    val sid : Sound.sampleset

end