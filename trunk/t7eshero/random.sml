structure Random =
struct
    (* XXX no idea if this is even a mediocre pseudorandom number generator *)
  (* XXX use MTrandom instead, which should be fast enough for these purposes. *)
    local val seed = ref (Word32.fromInt
                          (IntInf.toInt
                           (Time.toMilliseconds (Time.now ()) mod 0x7FFFFFF7)))
    in
        fun random () =
            let
                val () = seed := Word32.xorb(!seed, 0wxF13844F5)
                val () = seed := Word32.*(!seed, 0wx7773137)
                val () = seed := Word32.+(!seed, 0wx7654321)
            in
                seed := !seed + 0w1;
                !seed
            end
        fun random_int () =
            Word32.toInt (Word32.andb(random (), 0wx7FFFFFFF))
        fun random_bool () = 0w0 = Word32.andb(0wx000008000, random ())

    end
end

val () = print "Random initialized.\n"
