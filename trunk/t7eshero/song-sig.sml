(* This gives access to the stream of song events. There is a single
   universal notion of "now" which updates at a constant pace. This
   gives us a cursor into song events that we use for e.g. controlling
   the audio subsystem.

   It is also possible to create cursors that work at a fixed offset
   (positive or negative) from "now". For example, we want to draw
   notes that have already occured, so that we can show status about
   them. We also want to be able to perform the matching algorithm
   over a small window of notes in the past and future. *)
signature SONG =
sig
    type cursor
    (* give offset in ticks. A negative offset cursor displays events
       from the past. *)
    val cursor : int -> (int * (Match.label * MIDI.event)) list -> cursor


    (* get the events that are occurring now or which this cursor has
       already passed. Advances the cursor to immediately after the
       events. *)
    val nowevents : cursor -> (Match.label * MIDI.event) list

    (* show the upcoming events from the cursor's perspective. *)
    val look : cursor -> (int * (Match.label * MIDI.event)) list

    (* How many ticks are we behind real time? Always non-negative.
       Always 0 after calling nowevents, look, or cursor, until
       update is called again. *)
    val lag : cursor -> int

    (* Initializes the local clock. *)
    val init : unit -> unit

    (* Updates the local clock from the wall clock. Call as often as
       desired. Time does not advance between calls to this, for
       synchronization across cursors. *)
    val update : unit -> unit

    (* Advance the given number of ticks, as if time had just
       non-linearly done that. Implies an update. *)
    val fast_forward : int -> unit

    (* Absolute real-time since calling init *)
    val now : unit -> int

end