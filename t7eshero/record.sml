(* Per-song records and medals *)
structure Record :> RECORD =
struct
    exception Record of string

    type record =
        { percent : int,
          misses : int,
          medals : Hero.medal list }

    fun mtostring Hero.PerfectMatch = "PM"
      | mtostring Hero.Snakes = "SN"
      | mtostring Hero.Stoic = "ST"
      | mtostring Hero.Plucky = "PL"
      | mtostring Hero.Pokey = "PO"
      | mtostring Hero.AuthenticStrummer = "AS"
      | mtostring Hero.AuthenticHammer = "AH"

    fun mfromstring "PM" = Hero.PerfectMatch
      | mfromstring "SN" = Hero.Snakes
      | mfromstring "ST" = Hero.Stoic
      | mfromstring "PL" = Hero.Plucky
      | mfromstring "PO" = Hero.Pokey
      | mfromstring "AS" = Hero.AuthenticStrummer
      | mfromstring "AH" = Hero.AuthenticHammer
      | mfromstring _ = raise Record "bad medal"

    fun tostring { percent, misses, medals } =
        Int.toString percent ^ "?" ^ Int.toString misses ^ "?" ^
        Serialize.ue (Serialize.ulist (map mtostring medals))

    fun fromstring s =
        (case String.tokens Serialize.QQ s of
             [p, m, ms] =>
                 { percent = valOf (Int.fromString p),
                   misses = valOf (Int.fromString m),
                   medals = map mfromstring (Serialize.unlist (Serialize.une ms)) }
           | _ => raise Record ("bad record: " ^ s) )
             handle Option => raise Record "bad percent/misses record"

end