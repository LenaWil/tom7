(* The SDL_Net library provides a simple uniform networking library. *)
signature SDLNET =
sig

    exception SDLNet of string

    (* Raises SDLNet on failure *)
    val init : unit -> unit
    val quit : unit -> unit

    (* A resolved address. *)
    type address

    (* raises SDLNet on failure *)
    val resolvehost : string -> address
    val resolveip : address -> string

    structure TCP =
    struct
        type sock
        (* open address port *)
        val connect : address -> int -> tcpsock
        val closesock : tcpsock -> unit
        (* Returns the address and port *)
        val getpeeraddress : tcpsock -> address * int
        val send : tcpsock -> string -> unit
        val sendarray : tcpsock -> { array : word Array.array,
                                     start : int,
                                     num : int option } -> unit
        val sendvec : tcpsock -> { array : word Vector.vector,
                                   start : int,
                                   num : int option } -> unit
        (* TODO: TCP_Accept *)
        (* TODO: TCP_Listen *)
    end


end
