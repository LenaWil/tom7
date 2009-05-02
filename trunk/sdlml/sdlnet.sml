
structure SDLNet =
struct
    
    exception SDLNet of string

    (* XXX call GetError. How do you make a SML string out of a C pointer? *)
    fun geterror_ () = "(geterror unimplemented)"

    val initialized = ref false
    fun init() =
        let val init_ = _import "SDLNet_Init" : unit -> int ;
        in
            if !initialized
            then raise SDLNet "already initialized"
            else ();
            (case init_ () of
                 0 => ()
               | _ => raise SDLNet ("init: " ^ geterror_ ()));
            initialized := true
        end

    fun quit() =
        let val quit_ = _import "SDLNet_Quit" : unit -> int ;
        in
            if !initialized
            then ()
            else raise SDLNet "quit: not initialized";
            quit_ ();
            initialized := false
        end

    (* A resolved address. Sorry, IPv4-ever. *)
    type address = Word32.word

    (* val resolvehost : string -> address *)
    fun resolvehost s =
        let
            val rh_ = _import "ml_resolvehost" : string * Word32.word ref -> int ;
            val addr = ref 0w0
        in
            if rh_ (s ^ "\000", addr) = 0
            then !addr
            else raise SDLNet ("couldn't resolve " ^ s ^ ": " ^ geterror_())
        end

    fun resolveip w =
        let
            val ri_ = _import "ml_resolveip" :
                Word32.word * char Array.array * int -> int ;

            (* XXX is there word on the longest a DNS entry can be? *)
            val MAX = 1024
            val a = Array.array (MAX, #" ")
        in
            case ri_ (w, a, MAX) of
                ~1 => raise SDLNet ("resolveip: " ^ geterror_ ())
              | n => CharVector.tabulate (n, fn i => Array.sub(a, i))
        end

end