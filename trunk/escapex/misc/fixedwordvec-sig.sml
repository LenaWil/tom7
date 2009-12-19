signature FIXEDWORDVEC =
sig

    type word
    eqtype vector
        
    val sub : vector * int -> word
    val tabulate : int * (int -> word) -> vector
    (* val foldl : (word * 'b -> 'b) -> 'b -> word vector -> 'b *)
    val foldr : (word * 'b -> 'b) -> 'b -> vector -> 'b
    (* always returns a constant, but takes the vector for compatibility with 
       the VECTOR signature *)
    val length : vector -> int
    val fromList : word list -> vector
    val exists : (word -> bool) -> vector -> bool
    val findi : (int * word -> bool) -> vector -> (int * word) option

    val hash : vector -> Word32.word

    (* as bits *)
    val tostring : vector -> string

end
