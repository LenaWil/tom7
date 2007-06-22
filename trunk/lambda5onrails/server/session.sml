(* A session is a running instance of a program.
   Each session has a unique integer that identifies it.
   
   *)

structure Session :> SESSION =
struct

  datatype session = S of { id : int }

  (* A session is no longer valid *)
  exception Expired
  exception Session of string

  fun id (S { id }) = id
  fun getsession _ = NONE (* XXX *)

  fun sockets () = nil (* XXX *)

  (* XXX *)
  fun closed _ = ()
  fun packet _ = ()

end
