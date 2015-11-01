(* This keeps track of the current state of each finger, as well as
   the state of spans (notes that have passed the nut but which haven't
   been turned off yet). It also responds to user input, passing it off
   to the Match structure. *)
(* XXX signature *)
structure State =
struct

  structure GA = GrowArray

  (* Player input *)
  val fingers = Array.array(Hero.FINGERS, false) (* all fingers start off *)

  (* Is there a sustained note on this finger (off the bottom of the screen,
     not the nut)? *)
  val spans = Array.array(Hero.FINGERS, false) (* and not in span *)


  fun fingeron n =
      let
          fun highest i =
              if i = Hero.FINGERS
              then Match.input (Song.now (), Hero.FingerDown n)
              else
                  if Array.sub(fingers, i)
                  then ()
                  else highest (i + 1)
      in
          Array.update(fingers, n, true);
          (* if there are no fingers higher than this,
             then it can be a hammer event. *)
          highest (n + 1)
      end

  fun fingeroff n =
      let
          fun belowit i =
              if i < 0
              then ()
              else if Array.sub(fingers, i)
                   (* it's the finger below that is pulled off to *)
                   then Match.input (Song.now (), Hero.FingerUp i)
                   else belowit (i - 1)
      in
          Array.update(fingers, n, false);
          belowit (n - 1)
      end

  fun commit () =
      let
          fun theevent i =
              if i = Hero.FINGERS
              then nil
              else
                  if Array.sub(fingers, i)
                  then i :: theevent (i + 1)
                  else theevent (i + 1)
      in
          Match.input (Song.now (), Hero.Commit (theevent 0))
      end

  (* don't need to do anything, right? *)
  fun commitup () = ()

  val upstrums = ref 0
  val downstrums = ref 0
  fun upstrum () = upstrums := !upstrums + 1
  fun downstrum () = downstrums := !downstrums + 1

  val dancetime = ref 0w0
  val dancedist = ref 0.0
  (* We imagine the dancer in N-dimensional space, without any notion of
     N ahead of time. We start at the origin. We move by getting an
     update for one axis. When we move we increment dancedist by the
     length of the vector. The configured axes are guaranteed to be
     dense and small, starting from zero, so we use a growarray.

     One problem(?) with this is that guitars with more axes have an easier
     time achieving dance distance, since they have more dimensions in which
     to move. (But how many can they really have??) There are lots of other
     things that can make a guitar easier for dancing, like more sensitive
     accelerometers. What we really need is some kind of calibration step,
     but one that doesn't let you cheat...

     Actually I decided there's no point in measuring this in N-dimensional
     space, but to just do Manhattan distance. Also starting at 0 is silly
     since the accelerometers are usually centered in normal positions. *)
  val dancept = GA.empty() : real GA.growarray

  (* Beneath this, we just consider it noise. *)
  val NOISE_FILTER = 0.02
  (* XXX should time-limit this so that we don't give advantage to *)
  fun dance_now (axis, r) =
      let
          val () = if GA.has dancept axis
                   then ()
                   else GA.update dancept axis r

          val diff = Real.abs(GA.sub dancept axis - r);
      in
          if diff >= NOISE_FILTER
          then
              let in
                  print ("dance: " ^ Real.fmt (StringCvt.FIX (SOME 2)) (GA.sub dancept axis) ^
                         " -> " ^ Real.fmt (StringCvt.FIX (SOME 2)) r ^ "\n");
                  dancedist := !dancedist + diff
              end
          else ();
          GA.update dancept axis r
      end

  (* Do some temporal smoothing so that we don't catch high frequency jitters
     as dancing. We just sample once per half-second. *)
  val DANCE_FREQ = 0w500
  val lastdance = ref 0w0
  fun dance x =
      let val t = SDL.getticks ()
      in
          if t - !lastdance > DANCE_FREQ
          then
              let in
                  dance_now x;
                  lastdance := t
              end
          else ()
      end

  fun stats () =
      let
      in
          { totaldist = !dancedist,
            totaltime = real (Word32.toInt(SDL.getticks () - !dancetime)) / 1000.0,
            upstrums = !upstrums,
            downstrums = !downstrums
            }
      end

  fun reset () = Util.for 0 (Hero.FINGERS - 1) (fn i =>
                                                let in
                                                    upstrums := 0;
                                                    downstrums := 0;
                                                    dancetime := SDL.getticks ();
                                                    dancedist := 0.0;
                                                    GA.clear dancept;
                                                    Array.update(fingers, i, false);
                                                    Array.update(spans, i, false)
                                                end)

end
