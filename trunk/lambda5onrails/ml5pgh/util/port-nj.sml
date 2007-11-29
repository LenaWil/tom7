
(* the Port structure for SML/NJ *)
structure Port =
struct 

  val exnhistory = SMLofNJ.exnHistory

  (* SML/NJ might have something like this. *)
  (* since fast_eq is an underapproximation, we can safely always say no *)
  fun fast_eq _ = false

end