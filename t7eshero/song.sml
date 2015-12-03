structure Song :> SONG =
struct

  (* allow fast forwarding into the future *)
  val skip = ref 0
  val nnow = ref 0
  val started = ref 0

  (* XXX not clear we want a direct dependency on SDL here, but fairly
     easy to change later. *)
  fun update () = nnow := (Word32.toInt (SDL.getticks ()) + !skip)
  fun fast_forward n = skip := !skip + n

  fun now () = !nnow - !started


  type gameevt = Match.label * MIDI.event
  type 'evt cursor = { lt : int ref, evts : (int * 'evt) list ref,
                       orig : (int * 'evt) list, loop : bool }
  fun lag { lt = ref n, evts = _, orig = _, loop = _ } = now() - n

  fun peek { lt, evts, orig = _, loop = _ } = (now (), !lt, !evts)

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
  fun nowevents { lt, evts, orig, loop } =
    let
      (* returns the events that are now. modifies evts ref *)
      fun ne gap ((dt, evt) :: rest) =
        if dt <= gap
        then evt :: ne (gap - dt) rest

        (* the event is not ready yet. it must be measured as a
           delta from 'now' *)
        else (evts := (dt - gap, evt) :: rest; nil)

        | ne gap nil =
        if loop
        then (evts := orig; ne gap orig)
        (* song will end on next trip *)
        else (evts := nil; nil)

      (* sets evts to the tail, returns now events *)
      val ret = ne (now() - !lt) (!evts)
    in
      (* up to date *)
      lt := now();
      ret
    end

  (* Done if there are no more events, and we are not looping forever. *)
  fun done { lt, evts = ref nil, orig, loop = false } = true
    | done _ = false

  (* It turns out this offset is just a modification to the the delta
     for the first event. If we are pushing the cursor into the past,
     then the offset will be negative, which corresponds to a larger
     delta (wait longer). If we're going to the future, then we're
     reducing the delta. The delta could become negative. If so, we
     are skipping those events. The nowevents function gives us the
     events that are occurring now or that have already passed, so if
     we call that and discard them, our cursor will be at the
     appropriate future position. *)
  fun cursor' l off nil = { lt = ref (now()), evts = ref nil,
                            orig = nil, loop = l }
    | cursor' l off ((d, e) :: song) =
      let val c = { lt = ref 0, evts = ref ((d - off, e) :: song),
                    orig = song, loop = l }
      in
        ignore (nowevents c);
        c
      end

  fun cursor x = cursor' false x
  fun cursor_loop x = cursor' true x

  (* XXX how to look past the end of the song when looping? *)
  fun now_and_look (c as { lt = _, evts, orig = _, loop = _ }) =
    let val nows = nowevents c
    in (nows, !evts)
    end

  fun look c = #2 (now_and_look c)

  fun init () =
    let in
      update();
      skip := 0;
      started := !nnow
    end

  fun rewind { lt : int ref, evts : (int * 'evt) list ref,
               orig : (int * 'evt) list, loop : bool } =
    let in
      lt := now();
      evts := orig
    end

end
