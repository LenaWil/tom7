
structure PH =
struct

  (* Types that define Power Hour Machines, which
     completely describe a power hour algorithm. *)
  datatype cup = Up | Down | Filled

  (* What a player does on a turn when he sees a state other than None.
     (In None, the only legal action is to not drink and not pass.)
     After drinking at most once, he can pass the cup to any player in
     a state of his choice, but:
      - If the cup is filled and we didn't drink, it stays
        filled.
      - The result of the round cannot have more than one
        cup in a given location.
     Note that it is normal for the player to pass to himself. *)

  type action = { drink : bool,
                  place : int * cup }

  (* The starting state for the player, and the three actions that can
     be specified. Note that in the None case, the only legal action
     is to not drink and not pass, so this is not represented. *)
  datatype player = P of { start : cup option,
                           up : action,
                           down : action,
                           filled : action }

  type machine = player list

  datatype simulation =
    S of { cups : cup option array ref,
           (* Never changes during simulation *)
           players : player vector,
           (* How many drinks has the player consumed? *)
           drinks : int array,
           (* What round is it? 0-59 *)
           round : int ref }

  fun makesim (m : machine) =
    S { cups = ref (Array.fromList (map (fn P { start, ... } => start) m)),
        players = Vector.fromList m,
        drinks = Array.fromList (map (fn _ => 0) m),
        round = ref 0 }

  exception Illegal of string
  fun step (S { cups, players, drinks, round }) =
      let
          val newcups = Array.array (Array.length (!cups), NONE)
          fun oneplayer (i, P { up, down, filled, ... }) =
              case Array.sub (!cups, i) of
                  NONE => ()
                | SOME now =>
                  let
                      val { drink, place as (dest, next) } =
                          case now of
                              Up => up
                            | Down => down
                            | Filled => filled
                  in
                      (if drink
                       then Array.update (drinks, i,
                                          Array.sub (drinks, i) + 1)
                       else ());
                      (case Array.sub (newcups, dest) of
                          NONE => Array.update (newcups, dest, SOME next)
                        | SOME _ =>
                              raise (Illegal ("2+ cups at pos " ^
                                              Int.toString dest)))
                  end

      in
          Vector.appi oneplayer players;
          cups := newcups;
          round := !round + 1
      end

  datatype result =
      Finished of { drinks: int Array.array,
                    waste: int }
    | Error of { rounds : int, msg : string }

  fun exec (m : machine) =
    let
        val sim = makesim m
        fun oneround (s as S { round = ref 60, drinks, cups, ... }) =
            let
                (* Glasses filled at the end are waste. *)
                val waste = Array.foldl (fn (SOME Filled, b) => 1 + b
                                          | (_, b) => b) 0 (!cups)
            in
                Finished { drinks = drinks, waste = waste }
            end
          | oneround (s as S { round = ref round, ... }) =
            (step s; oneround s)
                 handle Illegal str => Error { rounds = round,
                                               msg = str }
    in
        oneround sim
    end

end
