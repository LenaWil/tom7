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

  (* create a new session, running the program given by name
     and sending the initial data over the given socket *)
  val new        : Network.sock -> string -> unit

  (* an incoming socket for pushing or pulling at the supplied session id *)
  val push       : Network.sock -> int -> unit
  val pull       : Network.sock -> int -> unit

  (* network events *)
  val closed     : Network.sock -> unit
  val packet     : Network.packet * Network.sock -> unit

  (* do work if desired *)
  val step       : unit -> unit

end
