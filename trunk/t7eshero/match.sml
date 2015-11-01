structure Match :> MATCH =
struct
  val EPSILON = 150
  val Hero = Hero.Hero

  infixr 9 `
  fun a ` b = a b

  datatype scoreevt =
      SE of { (* audio tracks that are gated by this event *)
              gate : int list,
              state : Hero.state ref,
              idx : int,
              hammered : bool,
              (* sorted ascending *)
              soneme : int list }
    | SE_BOGUS

  val streaksize = ref 0
  fun streak () = !streaksize
  fun endstreak () = streaksize := 0

  (* These should describe what kind of track an event is drawn from *)
  datatype label =
      Music of Sound.inst * int
    | Score of scoreevt
    | Control
    | Bar of Hero.bar

  fun state (SE { state, ... }) = !state
    | state  SE_BOGUS = raise Hero "Bogus"
  fun setstate SE_BOGUS _ = raise Hero "set bogus"
    | setstate (SE { state, ... }) s = state := s

  fun hammered (SE { hammered, ... }) = hammered
    | hammered SE_BOGUS = raise Hero "hammer bogus"

  structure GA = GrowArray
  (* The matching array is

     song events on this axis; one column per event ......
    |
    |
    |
    |
    v

    input events on the vertical axis, one row per input.

     *)
  (* This is a growarray of Arrays (vectors?), each of length
     equal to the number of events in the song.

     Absolute time, the event, the dp score (= streak, #misses).
     *)
  val matching = GA.empty () : (int * Hero.input * (bool * int) array) GA.growarray

  (* contains all of the scoreevts in the song *)
  val song = ref (Vector.fromList nil) : (int * scoreevt) vector ref

  (* commit notelists must be in sorted (ascending) order *)
  datatype howsame = Equal | NeedStreak | NotEqual
  fun same (Hero.Commit nil, SE _) = NotEqual
    | same (Hero.Commit nl, SE { soneme = [one], ... }) =
      if List.last nl = one then Equal else NotEqual
    | same (Hero.Commit nl, SE { soneme, ... }) = if nl = soneme then Equal else NotEqual

    | same (Hero.FingerDown n, SE { soneme = [one], hammered = true, ... }) =
         if n = one then NeedStreak else NotEqual
    | same (Hero.FingerUp n, SE { soneme = [one], hammered = true, ... }) =
         if n = one then NeedStreak else NotEqual

    | same (_, SE_BOGUS) = raise Hero "bogus same??"
    | same (_, SE _) = NotEqual

  (* This is the heart of T7esHero. Process a piece of input by adding
     a new row to the matrix. *)
  fun input (now, input) =
      let
          val current_length = GA.length matching
          val prevrow =
              if current_length = 0
              then (* no inputs, so you've missed this many events *)
                   (fn x => (false, x))
              else
                  let val (_, _, a) = GA.sub matching (current_length - 1)
                  in (fn i => Array.sub(a, i))
                  end

          (* PERF
             This is pretty inefficient. We really only need to look at
             a fraction of it because most of the comparisons are refuted
             by being out of epsilon range. Oh, well. Surprisingly, this
             performs pretty well in practice, I guess because the songs
             are all pretty short. *)
          (* PERF doesn't need to be initialized here *)
          val nsong = Vector.length (!song)
          val new = Array.array (nsong, (false, ~1))

          val () =
          Util.for 0 (nsong - 1)
          (fn i =>
           let
               val (t, se) = Vector.sub(!song, i)
               val up = prevrow i
               val (upleft, left) =
                   if i > 0
                   then (prevrow (i - 1), Array.sub(new, i - 1))
                   else ((false, 0), (false, 0))

               val didhit =
               (* OK, so we're comparing the input event against
                  the ith event in the score. First thing is,
                  if the input and the event are not within
                  epsilon of one another, it's definitely a miss. *)
                   if Int.abs (t - now) <= EPSILON
                   then same (input, se)
                   else NotEqual

               (* If we ever hit the note, register it as hit. It's
                  possible that this will show too many successes in
                  some cases, but it's just for display purposes. *)
               val () = if didhit = Equal orelse
                          (didhit = NeedStreak andalso #1 upleft)
                        then
                            ((* messagebox ("hit! t: " ^ Int.toString t ^
                                         ", now: " ^ Int.toString now); *)
                             case se of
                                 SE { state, ... } =>
                                     (case !state of
                                          Hero.Hit _ => ()
                                        | _ => (streaksize := !streaksize + 1;
                                                state := Hero.Hit (ref 0)))
                               | SE_BOGUS => raise Hero "whaaa??")
                        else ()

               (* less here means "better" *)
               fun less ((s1, i1), (s2, i2)) =
                   case Int.compare (i1, i2) of
                       LESS => true
                     | GREATER => false
                     | EQUAL => s1 andalso (not s2)

               fun min (val1, val2, val3) =
                   if less(val1, val2)
                   then (if less(val1, val3)
                         then val1
                         else val3)
                   else (if less(val2, val3)
                         then val2
                         else val3)

               val best =
               case input of
                   Hero.Commit nl =>
                       if didhit = Equal
                       then min ((* hit! *)
                                 (true, #2 upleft),
                                 (false, #2 left + 1),
                                 (false, #2 up + 1))
                       else min ((false, #2 upleft + 1),
                                 (false, #2 left + 1),
                                 (false, #2 up + 1))

                 | Hero.FingerDown nl =>
                       if didhit = NeedStreak
                       then min ((* hit! *)
                                 if #1 upleft
                                 then (true, #2 upleft)
                                 else (false, #2 upleft + 1),
                                 (* decide to skip *)
                                 (false, #2 left + 1),
                                 (* ignore: off streak but no penalty *)
                                 (false, #2 up))
                       else min ((false, #2 upleft + 1),
                                 (false, #2 left + 1),
                                 (* safe to ignore always, but breaks streak *)
                                 (false, #2 up))

                 (* Same as finger down, but doesn't break streak *)
                 | Hero.FingerUp nl =>
                       if didhit = NeedStreak
                       then min ((* hit! *)
                                 if #1 upleft
                                 then (true, #2 upleft)
                                 else (false, #2 upleft + 1),
                                 (* decide to skip *)
                                 (false, #2 left + 1),
                                 (* ignore: off streak but no penalty *)
                                 (#1 up, #2 up))
                       else min ((false, #2 upleft + 1),
                                 (false, #2 left + 1),
                                 (* safe to ignore always *)
                                 (#1 up, #2 up))
                           (*
                 (* XXX currently ignoring all other input! *)
                 | _ => min ((false, #2 upleft + 1),
                             (false, #2 left + 1),
                             (* consume input, doing nothing *)
                             up)
                           *)
           in
               Array.update(new, i, best)
           end)
      in
          GA.append matching (now, input, new)
      end


  (* Once the matrix is complete, the total number of
     misses is the value in the bottom-right cell. (We
     must accout for all song events and input events.)

     When we're on-line, we should only look at the
     matrix that has passed the point of no return.

     It's ... hmm, maybe it's easier to just do this
     in our failloop.

     *)

 (* When the song is over, we want to report off-line
    stats for the postmortem and high score table. *)
  fun stats tracks =
      let
          (* This is the generous version from gameplay.
             It allows us to hit two notes with one strum! *)
          val (hit, total) =
              foldl (fn ((delta, evt), (hit, total)) =>
                     (case evt of
                          (_, MIDI.NOTEON(_, _, 0)) => (hit, total)
                        | (Score (SE { state = ref state, ... }), MIDI.NOTEON _) =>
                              (case state of
                                   (* XXX could measure average/total latency here. *)
                                   Hero.Hit _ => (hit + 1, total + 1)
                                 | Hero.Missed => (hit, total + 1)
                                 | Hero.Future =>
                                       (* only in early exit scenarios. *)
                                       (hit, total + 1)
(*
                                       let in
                                           Hero.messagebox "future: impossible!";
                                           raise Hero "impossible!"
                                       end *))
                       | _ => (hit, total))) (0, 0) tracks
      in
          { misses = total - hit, (* XXX *)
            percent = (hit, total)

            }
      end


  (* fun misses t = 0 *)

  fun initialize (PREDELAY, SLOWFACTOR, gates, track) =
      (* let's do *)
      let
          val () = GA.clear matching
          val () = endstreak ()

          (* Add scorevent holders so we can update them later. *)
          val track = map (fn (d, e) => (d, (ref SE_BOGUS, e))) track

          (* For the purpose of matching we don't care about
             note lengths at all (phew) so we don't care about
             NOTEOFF events. *)
          val starts = MIDI.filter (fn (_, MIDI.NOTEON(_, _, 0)) => false
                                     | (_, MIDI.NOTEON _) => true
                                     | _ => false) track

          fun makeabsolute idx total ((d, evt) :: rest) =
              let
                  fun now ((0, evt) :: more) =
                      let val (nows, laters) = now more
                      in (evt :: nows, laters)
                      end
                    | now l = (nil, l)

                  fun get (_, MIDI.NOTEON (ch, n, vel)) = n
                    | get _ = raise Hero "impossible"

                  val (nows, laters) = now rest
                  val nows = evt :: nows

                  val soneme = ListUtil.sort Int.compare ` map get nows

                  val se = SE { gate = gates,
                                state = ref Hero.Future,
                                idx = idx,
                                hammered =
                                  (case nows of
                                       [(_, MIDI.NOTEON (_, _, vel))] => vel <= 64
                                     | _ => false),
                                soneme = soneme }

                  (* they all share the same scoreevt *)
                  val () = app (fn (s, _) => s := se) nows
              in
                  (* XXX hack: since we get this before slowing, we need to multiply
                     here too. we need a better treatment of tempo anyway, so we can
                     live with this for now. We also later add a predelay in there...
                     *)
                  (PREDELAY + SLOWFACTOR * (total + d), se) ::
                    makeabsolute (idx + 1) (total + d) laters
              end
            | makeabsolute _ _ nil = nil

          val () = song := Vector.fromList (makeabsolute 0 0 starts)
          val track = map (fn (d, (ref se, e)) => (d, (Score se, e))) track
      in
          (* PERF *)
          app (fn (d, (Score SE_BOGUS, MIDI.NOTEON(_, _, vel))) =>
               (if vel > 0 then raise Hero ("at " ^ Int.toString d ^ " bogus!") else ())
               | _ => ()) track;
          track
      end

  (* XXX should probably limit the number of columns... *)
  fun dump () =
      let
          val f = TextIO.openOut "dump.txt"

          fun setos (SE { soneme, state, ... }) =
                     (case !state of
                          Hero.Hit _ => "O"
                        | Hero.Missed => "X"
                        | _ => "") ^ StringUtil.delimit "" (map Int.toString soneme)
            | setos SE_BOGUS = "?!?"

          (* the song.. *)
          val s = "" :: "" :: map (fn (x, se) =>
                                   setos se ^
                                   (if hammered se
                                    then "#"
                                    else "") ^
                                   "\n@" ^ Int.toString x)
                                   (Vector.foldr op:: nil (!song))

          fun intos (Hero.Commit nl) = StringUtil.delimit "" (map Int.toString nl)
            | intos (Hero.FingerDown f) = "v" ^ Int.toString f
            | intos (Hero.FingerUp f) = "^" ^ Int.toString f

          (* the inputs and scores... *)
          val tab = ref nil
          val () =
              Util.for 0 (GA.length matching - 1)
              (fn i =>
               let
                   val (when, input, arr) = GA.sub matching i
                   val l = Array.foldr op:: nil arr
               in
                   tab :=
                   (intos input :: ("@" ^ Int.toString when) ::
                    map (fn (b, misses) =>
                         (if b then "!"
                          else "") ^ Int.toString misses) l) :: !tab
               end)

          val fulltab = (s :: rev (!tab))
          val trunctab = map (fn l =>
                              if List.length l > 40
                              then List.take(l, 40)
                              else l) fulltab
          val trunctab = if List.length trunctab > 192
                         then List.take(trunctab, 192)
                         else trunctab
      in
          StringUtil.writefile "dump.txt" `
          StringUtil.table 999999
          trunctab
      end
end
