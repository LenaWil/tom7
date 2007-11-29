
(* Implementation of the Port structure for any compiler. *)
structure Port =
struct

  (* no exn history ever available *)
  fun exnhistory _ = nil

  (* since fast_eq is an underapproximation, we can safely always say no *)
  fun fast_eq _ = false

end