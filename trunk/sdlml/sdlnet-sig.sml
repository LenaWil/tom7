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

        

end
