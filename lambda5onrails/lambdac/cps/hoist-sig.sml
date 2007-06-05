
(* Hoists closure-converted code to the top level.
   See hoist.sml for details. *)

signature HOIST =
sig

  exception Hoist of string
  
  (* hoist an expression, creating a program.
     the world must be a constant, given as a string *)
  val hoist : CPS.world -> CPS.cexp -> CPS.program

end