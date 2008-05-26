(* This keeps track of the current state of each finger, as well as
   the state of spans (notes that have passed the nut but which haven't
   been turned off yet). It also responds to user input, passing it off
   to the Match structure. *)
(* XXX signature *)
structure State =
struct

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

end
