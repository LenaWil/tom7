
(* the Port structure for SML/NJ *)
structure Port =
struct 

  val exnhistory = MLton.Exn.history

  val fast_eq = MLton.eq

end