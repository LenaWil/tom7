(* Per-song records and medals *)
signature RECORD =
sig
    exception Record of string

    type record =
        { percent : int,
          misses : int,
          (* XXX dance distance.. *)
          medals : Hero.medal list }

    (* serialize *)
    val tostring : record -> string
    val fromstring : string -> record
end