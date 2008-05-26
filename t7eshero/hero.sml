(* Common datatype definitions for T7eshero. *)
structure Hero =
struct

  exception Hero of string

  datatype bar =
      Measure
    | Beat
    | Timesig of int * int

  datatype state =
      Future
    | Missed
    | Hit of int ref (* animation frame *)

  (* ... ? *)
  datatype input =
      FingerDown of int
    | FingerUp of int
    | Commit of int list

end