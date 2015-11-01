(* Per-song records and medals. These are stored within the player's
   Profile. *)
signature RECORD =
sig
    exception Record of string

    type record =
        { percent : int,
          misses : int,
          (* XXX dance distance.. *)
          medals : Hero.medal list }

    (* Compare records for the same song.
       Lesser means better (i.e. fewer misses) *)
    val cmp : record * record -> order

    (* serialize *)
    val tostring : record -> string
    val fromstring : string -> record
end