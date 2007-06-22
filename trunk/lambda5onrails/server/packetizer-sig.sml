
(* a packetizer determines how to break up
   a stream of incoming bytes *)

signature PACKETIZER =
sig

    type packet

    type partialpacket

    (* empty partial packet. Each connection begins
       with ones of these on the wire. *)
    val empty : partialpacket

    (* parse old new

       take the beginning of a packet ('old') and some
       new data, then create a list of parsed packets
       (possibly none) and a new partial packet. *)
    val parse : partialpacket -> string -> packet list * partialpacket

    (* generate bytes to send out on the wire. *)
    val make : packet -> string

    val protocol : packet Network.protocol

end