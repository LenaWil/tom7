structure Song :> SONG =
struct

  (* allow fast forwarding into the future *)
  val skip = ref 0
  val now = ref 0
  val started = ref 0

  (* XXX not clear we want a direct dependency on SDL here, but fairly
     easy to change later. *)
  fun update () = now := (Word32.toInt (SDL.getticks ()) + !skip)
  fun fast_forward n = skip := !skip + n

  type cursor = { lt : int ref, evts : (int * (Match.label * MIDI.event)) list ref }
  fun lag { lt = ref n, evts = _ } = !now - n

  (* move the cursor so that lt is now, updating the events as
     needed. *)
  (* The cursor is looking at time 'lt', and now it is 'now'. The
     events in the track are measured as deltas from lt. We
     want to play any event that was late (or on time): that
     occurred between lt and now. This is the case when the delta time
     is less than or equal to (now - lt).

     There may be many such events, each measured as a delta from the
     previous one. For example, we might have

                    now = 17
       1 1  2   5   |
       -A-B- -C- - -v- -D
      . : . : . : . : . :
      ^
      |
      lt = 10

      We want to emit events A-C, and reduce the delta time on D to 2,
      then continue with lt=now. To do so, we call the period of time
      left to emit the 'gap'; this begins as now - lt = 7.

      We then emit any events with delta time less than the gap,
      reducing the gap as we do so. (We can think of this as also
      updating lt. Instead we just set lt to now when we finish
      with the gap.)

      When the gap is too small to include the next event, we reduce
      its delta time by the remaining gap amount to restore the
      representation invariant for the cursor. *)
  fun nowevents { lt, evts } =
      let
          (* returns the events that are now. modifies evts ref *)
          fun ne gap ((dt, (label, evt)) :: rest) =
              if dt <= gap
              then (label, evt) :: ne (gap - dt) rest

              (* the event is not ready yet. it must be measured as a
                 delta from 'now' *)
              else (evts := (dt - gap, (label, evt)) :: rest; nil)

            (* song will end on next trip *)
            | ne _ nil = (evts := nil; nil)

          (* sets evts to the tail, returns now events *)
          val ret = ne (!now - !lt) (!evts)
      in
          (* up to date *)
          lt := !now;
          ret
      end

  (* It turns out this offset is just a modification to the the delta
     for the first event. If we are pushing the cursor into the past,
     then the offset will be negative, which corresponds to a larger
     delta (wait longer). If we're going to the future, then we're
     reducing the delta. The delta could become negative. If so, we
     are skipping those events. The nowevents function gives us the
     events that are occurring now or that have already passed, so if
     we call that and discard them, our cursor will be at the appropriate
     future position. *)
  fun cursor off nil = { lt = ref (!now), evts = ref nil }
    | cursor off ((d, e) :: song) = 
      let val c = { lt = ref 0, evts = ref ((d - off, e) :: song) }
      in
          ignore (nowevents c);
          c
      end

  fun look (c as { lt = _, evts }) =
      let in
          (* get rid of anything that has passed *)
          ignore (nowevents c);
          !evts
      end

  fun init () =
      let in
          update();
          started := !now
      end

  (* shadowing for export *)
  val now = fn () => !now - !started
end
