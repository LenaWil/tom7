signature MATCH =
sig

    type scoreevt

    (* number of ticks within which we count a match *)
    val EPSILON : int

    (* These should describe what kind of track an event is drawn from *)
    datatype label =
        Music of Sound.inst * int
      | Score of scoreevt (* the tracks that are gated by this score *)
      | Control
      | Bar of Hero.bar

    val state : scoreevt -> Hero.state
    val setstate : scoreevt -> Hero.state -> unit

    val hammered : scoreevt -> bool

    (* input (absolute time, input event)
       can change the state of some scoreevts *)
    val input : int * Hero.input -> unit

    (* initialize (PREDELAY, SLOWFACTOR, gates, events)
       produces a t7eshero track of (int * (label * event))
       where the labels are Score. Also initializes the
       internal matching matrix. *)
    val initialize : (int * int * (* XXX leaky *)
                      int list * (int * MIDI.event) list) ->
                     (int * (label * MIDI.event)) list

    (* number of total known misses at time now.
       (time must never decrease) *)
    (* val misses : int -> int *)

    (* XXX HAX. Number of consecutive hits *)
    val streak : unit -> int
    val endstreak : unit -> unit

    (* dump debugging infos. SLOW! *)
    val dump : unit -> unit

    (* needs the tracks in order to conveniently count missed notes *)
    val stats : (int * (label * MIDI.event)) list -> { misses : int, percent : int * int }

end
