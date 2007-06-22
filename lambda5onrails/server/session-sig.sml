(* A session is a running instance of a program.
   Each session has a unique integer that identifies it.
   
   *)

signature SESSION =
sig

  type session

  (* A session is no longer valid *)
  exception Expired
  exception Session of string

  val id         : session -> int
  val getsession : int -> session option

  (* get all the active sockets *)
  val sockets    : unit -> Network.sock list

  (* network events *)
  val closed     : Network.sock -> unit
  val packet     : Network.packet * Network.sock -> unit

end
