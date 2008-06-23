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
     space, but to just do Manhattan distance. *)
  val dancept = GA.empty() : real GA.growarray

  (* XXX should time-limit this so that we don't give advantage to *)
  fun dance (axis, r) =
      let
          val () = if GA.has dancept axis
                   then ()
                   else GA.update dancept axis 0.0
      in
          dancedist := !dancedist + Real.abs(GA.sub dancept axis - r);
          GA.update dancept axis r
      end

  fun reset () = Util.for 0 (Hero.FINGERS - 1) (fn i => 
                                                let in
                                                    dancedist := 0.0;
                                                    GA.clear dancept;
                                                    Array.update(fingers, i, false);
                                                    Array.update(spans, i, false)
                                                end)

end
