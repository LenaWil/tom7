(* incomplete; needs to be included and then the flags 
   (consecutive integers) provided! *)
signature FLAG =
sig
   type flag
   type flags
   val flags : unit -> flags
   val check : flags -> flag -> bool
   val set : flags -> flag -> unit
   val clear : flags -> flag -> unit
end