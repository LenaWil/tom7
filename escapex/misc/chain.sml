
(* Chaining is a way of improving the memory performance of
   Retract at the cost of time performance. What it does is
   to represent states as deltas from other states. This
   (usually) means that the representation is much smaller.
   However, equivalence checking becomes much less efficient
   because of the need to apply the deltas to find the
   actual state.

   This functor takes a GAME (with some extra functions)
   and produces an equivalent GAME with a chained 
   representation.
*)

functor ChainGame(include GAME) :> GAME =
struct

  (* TODO *)

end
