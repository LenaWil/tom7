
(* Removes the dictionary invariant.
   See dict.sml for details. *)

signature UNDICT =
sig

  exception UnDict of string
  
  val undict : CPS.world -> CPS.cexp -> CPS.cexp

end