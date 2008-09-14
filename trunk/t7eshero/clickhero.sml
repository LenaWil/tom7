(* Common datatype and constant definitions for T7eshero. *)
structure Hero =
struct

  exception Hero of string
  exception Exit

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

  datatype difficulty =
      Real
  (* XXX ... *)

  (* To earn a medal, you have to get at least 90% on the song. *)
  datatype medal = 
      (* Got 100% *)
      PerfectMatch
    (* Averaged at least 0.25 m/s dancing *)
    | Snakes
    (* Less than 0.02 m/s (?) average dancing *)
    | Stoic
    (* Only strummed upward. *)
    | Plucky
    (* Only strummed downward. *)
    | Pokey
    (* never hammered a note (hard to measure?) *)
    | AuthenticStrummer
    (* never strummed a hammer note *)
    | AuthenticHammer

  val FINGERS = 5

  fun messagebox s =
      let val f = TextIO.openAppend("/tmp/t7es.txt")
      in
          TextIO.output(f, s ^"\n");
          TextIO.closeOut(f)
      end

  fun messagebox s = print (s ^ "\n")

  (* Comment this out on Linux and OSX, or it will not link *)
(*
  local
      val mb_ = _import "MessageBoxA" : MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
  in
      fun messagebox s = mb_(MLton.Pointer.null, s ^ "\000", "Message!\000", 
                             MLton.Pointer.null)
  end
*)
end