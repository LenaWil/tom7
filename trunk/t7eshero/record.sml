(* Per-song records and medals *)
structure Record :> RECORD =
struct
  exception Record of string

  type record =
      { percent : int,
        misses : int,
        medals : Hero.medal list }

  fun cmp ({ percent = _, misses = missa, medals = meda },
           { percent = _, misses = missb, medals = medb }) =
      case Int.compare (missa, missb) of
          EQUAL =>
              let
                  val meda = ListUtil.sort Hero.medal_cmp meda
                  val medb = ListUtil.sort Hero.medal_cmp medb
              in
                  List.collate Hero.medal_cmp (meda, medb)
              end
        | ord => ord

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
    | mfromstring s = raise Record ("bad medal [" ^ s ^ "]")

  fun totf { percent, misses, medals } =
    (ProfileTF.R { percent = percent, misses = misses,
                   medals = map mtostring medals })

  fun fromtf (ProfileTF.R { percent, misses, medals }) =
    { percent = percent, misses = misses,
      medals = map mfromstring medals }

end