(* TODO improvements:
   - don't directly enumerate games that can
     be separated into non-interacting components.
*)

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
     is to not drink and not pass, so this is not represented.

     Actions are options so that we can generate classes of players
     that are underspecified, for efficiency. The machine is illegal
     if during simulation we need to use an action that is not present,
     but we don't generate such machines when exploring the possibilities.
     *)
  datatype player = P of { start : cup option,
                           up : action option,
                           down : action option,
                           filled : action option }

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

  exception Unspecified of int * cup
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
                          case (case now of
                                    Up => up
                                  | Down => down
                                  | Filled => filled) of
                              NONE => raise Unspecified (i, now)
                            | SOME a => a
                  in
                      (if drink
                       then Array.update (drinks, i,
                                          Array.sub (drinks, i) + 1)
                       else ());
                      (case Array.sub (newcups, dest) of
                          NONE => Array.update (newcups, dest, SOME next)
                        | SOME _ =>
                              raise (Illegal ("2+ cups"
                                              (* ^ " at pos " ^ Int.toString dest *))))
                           handle Subscript => raise Illegal ("out of bounds")
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

   val r = exec [P { start = SOME Up,
                     up = SOME { drink = true, place = (0, Up) },
                     down = NONE,
                     filled = NONE }]

   fun combine l k = List.concat (map k l)

   (* Returns a list of all the possible games with that
      many players *)
   fun allgames radix =
       let
           val cups = [Up, Down, Filled]
           val startplayers =
               combine (NONE :: map SOME cups)
               (fn start =>
                [P { start = start, up = NONE, down = NONE, filled = NONE }])

           val startgames =
               let
                   fun gg 0 = [nil]
                     | gg n =
                       let val rest = gg (n - 1)
                       in
                           combine startplayers
                           (fn p =>
                            map (fn l => p :: l) rest)
                       end
               in
                   gg radix
               end
       in
           startgames
       end

  fun result_cmp (Finished _, Error _) = LESS
    | result_cmp (Error _, Finished _) = GREATER
    | result_cmp (Finished { drinks, waste },
                  Finished { drinks = dd, waste = ww }) =
      (case Int.compare (waste, ww) of
           EQUAL => Util.lex_array_order Int.compare (drinks, dd)
         | ord => ord)
    | result_cmp (Error { rounds, msg },
                  Error { rounds = rr, msg = mm }) =
      (case Int.compare (rounds, rr) of
           EQUAL => String.compare (msg, mm)
         | ord => ord)

  structure RM = SplayMapFn(type ord_key = result
                            val compare = result_cmp)

  fun execexpand games =
    let
        (* These are used for expanding underspecified players. *)
        local
            val radix = (case games of
                             h :: _ => length h
                           | nil => 0)
            val cups = [Up, Down, Filled]
            val indices = List.tabulate (radix, fn i => i)
            val placements =
                combine indices (fn i =>
                                 combine cups (fn c =>
                                               [(i, c)]))
        in
            val upplans =
                combine [true, false]
                (fn d =>
                 combine placements
                 (fn p => [SOME { drink = d, place = p }]))
            val downplans = upplans
            val filledplans =
                combine placements
                (fn p => [SOME { drink = true, place = p}]) @
                combine indices
                (fn i =>
                 [SOME { drink = false, place = (i, Filled) }])
        end

        (* These are games that need to be explored. *)
        val queue = ref games

        val done = ref (RM.empty : machine list RM.map)
        val did = ref (0 : IntInf.int)
        fun add_result m r =
           case RM.find (!done, r) of
              NONE => (done := RM.insert (!done, r, nil); add_result m r)
            | SOME l => (did := !did + 1;
                         if !did mod 100000 = 0
                         then TextIO.output (TextIO.stdErr, "Did " ^ IntInf.toString (!did) ^
                                             " currently " ^ Int.toString (length (!queue)) ^
                                             "\n")
                         else ();
                         (* XXX only keeping the newest... *)
                         done := RM.insert (!done, r, [m] (* :: l *)))

        exception Bug
        fun process () =
          case !queue of
              nil => !done
            | m :: t =>
            let
                (*
                val () = print (Int.toString (length (!queue)) ^
                                " left in queue\n")
                *)
                val () = queue := t
                fun simulate (s as S { round = ref 60, drinks, cups, ... }) =
                  let
                      (* Glasses filled at the end are waste. *)
                      val waste = Array.foldl (fn (SOME Filled, b) => 1 + b
                                                | (_, b) => b) 0 (!cups)
                  in
                     add_result m (Finished { drinks = drinks, waste = waste })
                  end
                  | simulate (s as S { round = ref round, ... }) =
                     let in
                         (* print (Int.toString round ^ "\n"); *)
                         step s;
                         simulate s
                     end
                       handle Illegal str =>
                         add_result m (Error { rounds = round, msg = str })
                      | Unspecified (i, c) =>
                         (* If we hit an unspecified thing,
                            expand it with all the things
                            that could be there. *)
                         queue :=
                         combine (case c of
                                      Up => upplans
                                    | Down => downplans
                                    | Filled => filledplans)
                         (fn plan =>
                          [ListUtil.mapi
                           (fn (player as P { start,
                                              up, down,
                                              filled }, idx) =>
                            let
                                fun replaceif cup field =
                                    if cup = c
                                    then if Option.isSome field
                                         then raise Bug
                                         else plan
                                    else field
                            in
                                if idx = i
                                then P {start = start,
                                        up = replaceif Up up,
                                        down = replaceif Down down,
                                        filled = replaceif Filled filled }
                                else player
                            end)
                           m
                           ]) @ !queue
            in
               simulate (makesim m);
               process()
            end

    in
        process()
    end

(*

   (* Returns a list of all the possible games with that
      many players *)
   fun allgames radix =
       let
           val cups = [Up, Down, Filled]
           val indices = List.tabulate (radix, fn i => i)
           val placements =
               combine indices (fn i =>
                                combine cups (fn c =>
                                              [(i, c)]))
           val plans =
               combine [true, false]
               (fn d =>
                combine placements
                (fn p => [SOME { drink = d, place = p }]))

           val players =
               combine (NONE :: map SOME cups)
               (fn start =>
                combine plans
                (fn u =>
                 combine plans
                 (fn d =>
                  combine plans
                  (fn f =>
                   [P { start = start, up = u, down = d, filled = f}]
                   ))))
           val () = print ("There are " ^
                           Int.toString (length players) ^
                           " different players.\n")
           (* Get all combinations of n players *)
           fun get 0 = [nil]
             | get n =
                 let val rest = get (n - 1)
                 in
                     combine players
                     (fn player =>
                      map (fn l => player :: l) rest)
                 end

           val res = get radix
           val () = print ("There are " ^
                           Int.toString (length res) ^
                           " different games.\n")
       in
           res
       end
*)

   fun collate l =
       let
           val l = ListUtil.mapto exec l
           val l = map (fn (a, b) => (b, a)) l
           val l = ListUtil.stratify result_cmp l
       in
           l
       end

   fun ctos Up = "U"
     | ctos Down = "D"
     | ctos Filled = "F"

   fun atos { drink, place = (w,a) } =
       ctos a ^
       (if drink then "*" else "") ^
       "@" ^ Int.toString w

   fun aotos NONE = "?"
     | aotos (SOME a) = atos a

   fun playertostring (P { start, up, down, filled }) =
       "(start " ^
       (case start of
            NONE => "_"
          | SOME c => ctos c) ^ ", " ^
       StringUtil.delimit " " (map (fn (c, a) => ctos c ^ "=>" ^ aotos a)
                               [(Up, up), (Down, down), (Filled, filled)]) ^
       ")"

   fun gametostring g =
       "[" ^ StringUtil.delimit "," (map playertostring g) ^ "]"

   fun restostring (Finished { drinks, waste }) =
       "[" ^
       StringUtil.delimit "," (map Int.toString
                               (Array.foldr op:: nil drinks)) ^
       "] wasting " ^
       Int.toString waste
     | restostring (Error { rounds, msg }) =
       "In " ^ Int.toString rounds ^ " round(s): " ^ msg

   fun show l =
       let
           fun showone (res, g) =
               print (restostring res ^ ": " ^
                      Int.toString (length g) ^ " game(s) like " ^
                      gametostring (hd g) ^ "\n")
       in
           app showone l
       end

 (*   val () = show (collate (allgames 2)) *)

   val g = allgames 3
   val () = print ("There are " ^ Int.toString (length g) ^
                   " games before splitting.\n")
   val () = show (RM.listItemsi (execexpand g))

end
