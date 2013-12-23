(* TODO improvements:
   - don't directly enumerate games that can
     be separated into non-interacting components.

   - Pow Pow Power Hour Machines

   - Make execution indifferent to the drink rule.
     Instead just compute a linear combination like
     a * drink_up + b * drink_down + c * drink_filled
     where drink_x is either 1 or 0.
*)

structure PH =
struct

  (* XXX should be 60 *)
  val MINUTES = 60

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
     be specified. Note that in the no-cup case, the only legal action
     is to not drink and not pass, so this is not represented.

     Actions are optional so that we can generate classes of players
     that are underspecified, for efficiency. If during simulation we
     use an action that is not present, we explode it to all the possibilities
     in that slot and start over. *)
  datatype player = P of { start : cup option,
                           up : action option,
                           down : action option,
                           filled : action option }

  type machine = player list

  (* Database of partial searches, so that we can store and resume
     a search. We need to store two things:

      - what machines have already been searched
      - what outcomes are possible, with one witness for each
        outcome.

     There are jillions of possible machines (there are
     something like (4*2n*3*2n*3*2n*3)^n for n players, depending
     on whether you count illegal ones like don't drink and flip
     upside-down), so we don't want to store this as a normal set.
 *)
  structure DB =
  struct
      (* XXX I guess I didn't implement it *)

  end

  datatype simulation =
    S of { (* Cup state in each slot. *)
           cups : cup option array ref,
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

  exception Unspecified of (int * cup) list
  exception Illegal of string

  val totalsteps = ref (0 : IntInf.int)
  (* Evaluate one step of the simulation. Raises Illegal if
     two or more cups end up in the same position. Raises Unspecified
     if we need to use a rule but it's not currently filled in. *)
  fun step (S { cups, players, drinks, round }) =
      let
        val newcups = Array.array (Array.length (!cups), NONE)

        (* Delay raising the Unspecified option because if this
           state is going to be illegal anyway, it will potentially
           save us lots of work. *)
        val unspecified = ref nil : (int * cup) list ref

        fun oneplayer (i, P { up, down, filled, ... }) =
          case Array.sub (!cups, i) of
              NONE => ()
            | SOME now =>
              let
                val c = case now of
                    Up => up
                  | Down => down
                  | Filled => filled
              in
                case c of
                    NONE =>
                    let in
                        unspecified := (i, now) :: !unspecified
                        (* Execution is doomed now, but
                           we hope we might raise Illegal
                           instead *)
                    end
                  | SOME { drink, place as (dest, next) } =>
                    let in
                        (if drink
                         then Array.update (drinks, i,
                                            Array.sub (drinks, i) + 1)
                         else ());

                         (* Note: Not checking the illegal action
                            where it's filled but I pass without drinking.
                            execexpand should not generate this rule. *)
                        (case Array.sub (newcups, dest) of
                           NONE => Array.update (newcups, dest, SOME next)
                         | SOME _ => raise Illegal "2+ cups")
                             (* ^ " at pos " ^ Int.toString dest *)
                             handle Subscript => raise Illegal "out of bounds"
                    end
              end
      in
          totalsteps := !totalsteps + 1;
          Vector.appi oneplayer players;
          (case !unspecified of
               nil => ()
             | l => raise Unspecified l);
          cups := newcups;
          round := !round + 1
      end

  datatype result =
      Finished of { drinks: int Array.array,
                    waste: int }
    | Error of { rounds : int, msg : string }

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

  fun combine l k = List.concat (map k l)

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

  (* For readout while running. One for benchmarking is at the bottom. *)
  val startseconds = Time.toSeconds (Time.now ())
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

        val done = ref (RM.empty : (machine * IntInf.int) RM.map)
        val did = ref (0 : IntInf.int)
        val minq = ref (length (!queue))

        (* Note: only keeping the newest, and counting how many we had. *)
        fun add_result m r =
           let in
               did := !did + 1;
               if !did mod 100000 = 0
               then
                   let val lq = length (!queue)
                       val secs = Time.toSeconds (Time.now()) - startseconds
                       val sps = Real.fromLargeInt (!totalsteps) /
                           Real.fromLargeInt secs
                       val gps = Real.fromLargeInt (!did) /
                           Real.fromLargeInt secs
                   in
                       minq := Int.min(!minq, lq);
                       TextIO.output (TextIO.stdErr, "#" ^ IntInf.toString (!did) ^
                                      " queue " ^ Int.toString lq ^
                                      " min " ^ Int.toString (!minq) ^
                                      (* " " ^ gametostring m ^ *)
                                      " " ^ Real.fmt (StringCvt.FIX (SOME 0)) sps ^
                                      " states/sec" ^
                                      " " ^ Real.fmt (StringCvt.FIX (SOME 0)) gps ^
                                      " config/sec" ^
                                      "\n")
                   end
               else ();
               case RM.find (!done, r) of
                   NONE => done := RM.insert (!done, r, (m, 1))
                 | SOME (old, n) => done := RM.insert (!done, r, (old, n + 1))
           end

        exception Bug
        fun process () =
          case !queue of
              nil => !done
            | m :: t =>
            let
                val () = queue := t
                fun simulate (s as S { round = ref round, drinks, cups, ... }) =
                  if round = MINUTES
                  then
                      let
                          (* Glasses filled at the end are waste. *)
                          val waste = Array.foldl (fn (SOME Filled, b) => 1 + b
                                                    | (_, b) => b) 0 (!cups)
                      in
                         add_result m (Finished { drinks = drinks, waste = waste })
                      end
                  else
                     let in
                         step s;
                         simulate s
                     end
                       handle Illegal str =>
                         add_result m (Error { rounds = round, msg = str })
                      | Unspecified l =>
                         let
                             (* Take a list of machines, and specify all
                                unspecified positions in the list l.
                                Each is a player index and the cup that
                                we need a rule for. Returns all such
                                assignments. *)
                             fun fillout nil ms = ms
                               | fillout ((i, c) :: rest) ms =
                                 combine
                                 (case c of
                                      Up => upplans
                                    | Down => downplans
                                    | Filled => filledplans)
                                 (fn plan =>
                                  combine ms
                                  (fn m =>
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
                                    m]))
                         in
                             queue := fillout l [m] @ !queue
                         end
            in
               simulate (makesim m);
               process()
            end

    in
        process()
    end

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
           fun showone (res, (g, n)) =
               print (restostring res ^ ": " ^
                      IntInf.toString n ^ " game(s) like " ^
                      gametostring g ^ "\n")
       in
           app showone l
       end

   structure ILM = SplayMapFn(type ord_key = int list
                              val compare = Util.lex_list_order Int.compare)

   fun writepossible f res =
       let
           fun tolist a = Array.foldr op:: nil a
           (* Set (as map to int) of unique possible outcomes. Need to
              dedup here because we don't care how many beers are wasted *)
           val unique = ref (ILM.empty : unit ILM.map)
           fun one (Finished { drinks, waste = _ }, _) =
               unique := ILM.insert (!unique, tolist drinks, ())
             | one _ = ()
           val () = app one res
           fun prone (drinks, ()) =
               StringUtil.delimit ","
               (map Int.toString drinks) ^ "\n"
           val strings = map prone (ILM.listItemsi (!unique))
           val contents = String.concat strings
           val n = length strings
       in
           StringUtil.writefile f contents;
           TextIO.output (TextIO.stdErr,
                          "Wrote " ^ Int.toString n ^ " possibilities to " ^ f ^ "\n")
       end

   val numplayers = 3

   val g = allgames numplayers
   val () = TextIO.output (TextIO.stdErr,
                           "There are " ^ Int.toString (length g) ^
                           " games before splitting.\n")
   val start_time = Time.now()
   val executed = (execexpand g)
   val end_time = Time.now()
   val res = RM.listItemsi executed
   val () = show res
   val () = writepossible ("possible-" ^ Int.toString numplayers ^ ".txt") res
   val () = TextIO.output (TextIO.stdErr,
                           "Total steps " ^ IntInf.toString (!totalsteps) ^ ". Took " ^
                           (IntInf.toString (Time.toMilliseconds end_time -
                                             Time.toMilliseconds start_time)) ^ " ms\n")
end
