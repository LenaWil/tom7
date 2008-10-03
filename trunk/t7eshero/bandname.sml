structure BandName =
struct

    (* nouns that pluralize with +s *)
    val regular_nouns =
        ["tongue",
         "doctor",
         "face",
         "melon",
         "committee",
         "dissertation",
         "mint",
         "crab",
         "square",
         "warning",
         "toast",
         "missile",
         "walk",
         "element",
         "chaperone",
         "engagement",
         "bridge",
         "villain",
         "decomposition",
         "lifeguard",
         "stomach",
         "darkside",
         "combo-meal"]

(* nouns paired with their plurals *)
    val irregular_nouns =
         [("fish", "fishes"),
          ("penalty", "penalties")]

    val adjectives = Vector.fromList
        ["facial",
         "living",
         "erudite",
         "hyperanalytical",
         "forgotten",
         "secret",
         "twice-cooked",
         "industrial",
         "plastic",
         "cosmopolitan",
         "jet-set",
         "exact",
         "fresh",
         "better",
         "expired"]

    val nouns = Vector.fromList (irregular_nouns @ map (fn s => (s, s ^ "s")) regular_nouns)

    fun cap s = CharVector.tabulate (size s,
                                     fn 0 => Char.toUpper (String.sub(s, 0)) 
                                      | n => String.sub(s, n))

    fun random_vec v = Vector.sub(v, Random.random_int () mod Vector.length v)
    fun random_Noun () = cap (#1 (random_vec nouns))
    fun random_Nouns () = cap (#2 (random_vec nouns))
    fun random_Adjective () = cap (random_vec adjectives)

    val forms = Vector.fromList
        [fn () => "The " ^ random_Nouns (),
         fn () => random_Adjective () ^ " " ^ random_Nouns (),
         fn () => random_Adjective () ^ " " ^ random_Noun (),
         fn () => random_Adjective () ^ " " ^ random_Nouns (),
         fn () => random_Adjective () ^ " " ^ random_Noun (),
         fn () => "The " ^ random_Adjective (),
         fn () => "The " ^ random_Adjective () ^ " " ^ 
                  Int.toString (1 + Random.random_int () mod 9)]

    fun random_name () = random_vec forms ()
         
        
end
