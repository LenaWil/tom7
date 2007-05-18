
(* Hoists closure-converted code to the top level.
   See hoist.sml for details. *)

signature HOIST =
sig

  exception Hoist of string
  
  val hoist : CPS.world -> CPS.cexp -> CPS.cexp

end