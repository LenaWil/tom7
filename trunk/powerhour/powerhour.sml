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
  type cup = int
  val FILLED = 0
  val NCUPS = 10

  (* What a player does on a turn when he sees a state other than None.
     (In None, the only legal action is to not drink and not pass.)
     After drinking at most once, he can pass the cup to any player in
     a state of his choice, but:
      - If the cup is filled and we didn't drink, it stays
        filled.
      - The result of the round cannot have more than one
        cup in a given location.
     Note that it is normal for the player to pass to himself. *)

  type action = { place : int * cup }

  (* The starting state for the player, and the three actions that can
     be specified. Note that in the no-cup case, the only legal action
     is to not drink and not pass, so this is not represented.

     Actions are optional so that we can generate classes of players
     that are underspecified, for efficiency. If during simulation we
     use an action that is not present, we explode it to all the possibilities
     in that slot and start over. *)
  datatype player = P of { start : cup option,
                           (* length NCUPS *)
                           rules : action option vector }

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
           (* For each player, true if the player must
              drink the count in slot zero (which is
              the FILLED cup state). This begins false,
              but if we ever try to pass a non-filled
              cup when executing the FILLED rule, we
              set it to true. We could also just inspect
              the rule at 0, but that is not exact because
              the rule might never actually execute. *)
           mustdrink0 : bool array,
           (* How many times was each rule executed (and
              thus could drink?) Remember to check the
              mustdrink0 bit. *)
           ruleexecuted : int array vector,
           (* What round is it? 0-59 *)
           round : int ref }

  (* PERF *)
  fun makesim (m : machine) =
      let
          val players = Vector.fromList m
          val n = Vector.length players
      in
          S { cups = ref (Array.fromList (map (fn P { start, ... } => start) m)),
              players = players,
              mustdrink0 = Array.array (n, false),
              ruleexecuted = Vector.tabulate (n, (fn _ => Array.array(NCUPS, 0))),
              round = ref 0 }
      end

  exception Unspecified of (int * cup) list
  exception Illegal of string

  val totalsteps = ref (0 : IntInf.int)
  (* Evaluate one step of the simulation. Raises Illegal if
     two or more cups end up in the same position. Raises Unspecified
     if we need to use a rule but it's not currently filled in. *)
  fun step (S { cups, players, mustdrink0, ruleexecuted, round }) =
      let
        val newcups = Array.array (Array.length (!cups), NONE)

        (* Delay raising the Unspecified option because if this
           state is going to be illegal anyway, it will potentially
           save us lots of work. *)
        val unspecified = ref nil : (int * cup) list ref

        fun oneplayer (i, P { rules, ... }) =
          case Array.sub (!cups, i) of
              NONE => ()
            | SOME now =>
              let
                val c = Vector.sub (rules, now)
                val rulecounts_for_player = Vector.sub (ruleexecuted, i)
              in
                case c of
                    NONE =>
                    let in
                        unspecified := (i, now) :: !unspecified
                        (* Execution is doomed now, but
                           we hope we might raise Illegal
                           instead *)
                    end
                  | SOME { place as (dest, next) } =>
                    let
                        (* This rule executed, so increment the count *)
                        val oldcount = Array.sub (rulecounts_for_player, now)
                    in
                        Array.update (rulecounts_for_player, now, oldcount + 1);

                        (* If this was the filled cup rule, see if it means
                           we had to drink. *)
                        (if now = FILLED andalso next <> FILLED
                         then Array.update (mustdrink0, i, true)
                         else ());

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
      Finished of { drinks: int vector,
                    waste: int }
    | Error of { rounds : int, msg : string }

(*
  fun ctos Up = "U"
    | ctos Down = "D"
    | ctos Filled = "F"
*)
  fun ctos 0 = "F"
    | ctos 1 = "D"
    | ctos 2 = "U"
    | ctos n = "X" ^ Int.toString n

  fun atos { place = (w, a) } =
      ctos a ^
      (* (if drink then "*" else "") ^ *)
      "@" ^ Int.toString w

  fun aotos NONE = "?"
    | aotos (SOME a) = atos a

  fun playertostring (P { start, rules }) =
      let fun vtol v =
          Vector.foldri (fn (a, b, c) => (a : cup, b : action option) :: c) nil v
      in
          "(start " ^
          (case start of
               NONE => "_"
             | SOME c => ctos c) ^ ", " ^
          StringUtil.delimit " " (map (fn (c, a) => ctos c ^ "=>" ^ aotos a)
                                  (vtol rules)) ^
          ")"
      end

  fun gametostring g =
      "[" ^ StringUtil.delimit "," (map playertostring g) ^ "]"

  (* XXX hard to read... *)
  fun plantostring (p : bool vector list) =
      StringUtil.delimit ","
      (map (fn v =>
            CharVector.tabulate (Vector.length v,
                                 fn x =>
                                 if Vector.sub (v, x)
                                 then #"+" else #"_")) p)


  fun combine l k = List.concat (map k l)

  fun allgames radix =
      let
          val cups = List.tabulate (NCUPS, fn i => i : cup)

          val startplayers =
              combine (NONE :: map SOME cups)
              (fn start =>
               [P { start = start,
                    rules = Vector.fromList (List.tabulate (NCUPS, fn _ => NONE)) }])

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
           EQUAL => Util.lex_vector_order Int.compare (drinks, dd)
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
            val cups = List.tabulate (NCUPS, fn i => i : cup)
            val indices = List.tabulate (radix, fn i => i)
            val placements =
                combine indices (fn i =>
                                 combine cups (fn c =>
                                               [(i, c)]))
        in
            (* Once we need to expand an action it becomes this. We
               will put anything in the FILLED rule, because execution
               determines whether we must drink on that rule after the
               fact. *)
            val expandedactions =
                combine placements
                (fn p => [SOME { place = p }])
        end

        (* These are games that need to be explored. *)
        val queue = ref games

        (* The map contains an example machine along with a bit vector that
           tells us whether the player drinks on the nth rule, for each player.
           In the case that the outcome was failure, this assignment will be
           nil (any ruleset would cause failure).

           This could be folded into the machine (and it would make sense) though
           then we need another representation of machines. The IntInf is the
           count of times we inserted something with that outcome. *)
        val done = ref (RM.empty : ((machine * bool vector list) * IntInf.int) RM.map)
        val did = ref (0 : IntInf.int)
        val minq = ref (length (!queue))

        (* Note: only keeping the newest, and counting how many we had. *)
        fun add_result (m, plans) r =
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
                   NONE => done := RM.insert (!done, r, ((m, plans), 1))
                 | SOME (old, n) => done := RM.insert (!done, r, (old, n + 1))
           end

        (* We executed m abstractly, and mustdrink0 / ruleexecuted
           tell us how many drinks we can drink. Each cell in ruleexecuted
           says how many times the corresponding rule was excuted. So
           we have drinks = d_1 * re_1 + ... + d_ncups * re_ncups total
           drinks, where d_i is always 1 or 0. if mustdrink0 is 0 for a
           player, then d_1 must be 1 (sorry, confusion between 0-indexed
           and 1-indexed here). *)
        exception Unimplemented
        fun add_metaresult m { mustdrink0, ruleexecuted, waste } =
           let
               val nplayers = Array.length mustdrink0
               (* Each player can choose which rules drink independently,
                  which is part of what reduces the space here so much.

                  For the player, produce a list of pairs; the first is
                  the num drank in [0, 60] and the second is the
                  NCUPS-length vector of bools for whether the nth rule
                  should drink. No duplicates. *)
               fun oneplayer i =
                 let
                     (* Don't generate duplicates, since there's a
                        combinatorial explosion. *)
                     (* val already = Array.array(MINUTES + 1, false) *)
                     val mymust = Array.sub(mustdrink0, i)
                     val myexec = Vector.sub(ruleexecuted, i)

                     (* Returns the different totals we can achieve, along
                        with a list of bools that gives us that value.
                        May contain duplicates. *)
                     fun alltails n =
                       if n = NCUPS then [(0, nil)]
                       else
                           let val rest = alltails (n + 1)
                           in
                             case Array.sub(myexec, n) of
                               (* If we never executed the rule,
                                  there's no choice to make. We
                                  say we drink since that will
                                  satisfy mymust no matter what
                                  and help my investments in
                                  beer brewing stock. *)
                               0 => map (fn (total, dodrink) =>
                                         (total, true :: dodrink)) rest
                             | exec =>
                               (* no-drink case *)
                               (if n <> FILLED orelse not mymust
                                then map (fn (total, dodrink) =>
                                          (total, false :: dodrink)) rest
                                else []) @
                               (* drink case *)
                               map (fn (total, dodrink) =>
                                    (exec + total, true :: dodrink)) rest
                           end

                     val uniques =
                         ListUtil.sort_unique (Util.byfirst Int.compare)
                         (alltails 0)
                 in
                     (* Compact *)
                     map (fn (total, l) => (total, Vector.fromList l)) uniques
                 end

               val players = List.tabulate (nplayers, oneplayer)

               (* Takes a list of lists; applies f to every list that can
                  be made by taking one element from each list. *)
               fun allcomb f sofar (outcomes :: rest) =
                   let
                       fun one elt =
                           allcomb f (elt :: sofar) rest
                   in
                       app one outcomes
                   end
                 | allcomb f sofar nil = f (rev sofar)

               (* We get the total and plan for each player, in order *)
               fun doone tps =
                   let val (outcome, plans) = ListPair.unzip tps
                       val outcome = Vector.fromList outcome
                   in
                       add_result (m, plans) (Finished { drinks = outcome,
                                                         waste = waste })
                   end
           in
               allcomb doone nil players
           end

        exception Bug
        fun process () =
          case !queue of
              nil => !done
            | m :: t =>
            let
                val () = queue := t
                fun simulate (s as S { round = ref round, mustdrink0,
                                       ruleexecuted, cups, ... }) =
                  if round = MINUTES
                  then
                      let
                          (* Glasses filled at the end are waste. *)
                          val waste = Array.foldl (fn (SOME Filled, b) => 1 + b
                                                    | (_, b) => b) 0 (!cups)
                      in
                         add_metaresult m ({ mustdrink0 = mustdrink0,
                                             ruleexecuted = ruleexecuted,
                                             waste = waste })
                      end
                  else
                     let in
                         step s;
                         simulate s
                     end
                       handle Illegal str =>
                         add_result (m, nil) (Error { rounds = round, msg = str })
                      | Unspecified l =>
                         let
                             (* Take a list of machines, and specify all
                                unspecified positions in the list l.
                                Each is a player index and the cup that
                                we need a rule for. Returns all such
                                assignments. *)
                             fun fillout nil ms = ms
                               | fillout ((i, c) :: rest) ms =
                                 combine expandedactions
                                 (fn action =>
                                  combine ms
                                  (fn m =>
                                   [ListUtil.mapi
                                    (fn (player as P { start, rules }, idx) =>
                                     let
                                         fun replaceif (cup, value) =
                                             if cup = c
                                             then if Option.isSome value
                                                  then raise Bug
                                                  else action
                                             else value
                                     in
                                         if idx = i
                                         then P { start = start,
                                                  rules = Vector.mapi replaceif rules }
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
                               (Vector.foldr op:: nil drinks)) ^
       "] wasting " ^
       Int.toString waste
     | restostring (Error { rounds, msg }) =
       "In " ^ Int.toString rounds ^ " round(s): " ^ msg

   fun show l =
       let
           fun showone (res, ((g, plan), n)) =
               print (restostring res ^ ": " ^
                      IntInf.toString n ^ " game(s) like " ^
                      gametostring g ^ " " ^
                      plantostring plan ^ "\n")
       in
           app showone l
       end

   structure ILM = SplayMapFn(type ord_key = int list
                              val compare = Util.lex_list_order Int.compare)

   fun writepossible f res =
       let
           fun tolist a = Vector.foldr op:: nil a
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

   val numplayers = 1

   val g = allgames numplayers
   val () = TextIO.output (TextIO.stdErr,
                           "There are " ^ Int.toString (length g) ^
                           " games before splitting.\n")
   val start_time = Time.now()
   val executed = (execexpand g)
   val end_time = Time.now()
   val res = RM.listItemsi executed
   val () = show res
   val () = writepossible ("possible-" ^ Int.toString NCUPS ^ "cup-" ^
                           Int.toString MINUTES ^ "min-" ^
                           Int.toString numplayers ^ "player.txt") res
   val () = TextIO.output (TextIO.stdErr,
                           "Total steps " ^ IntInf.toString (!totalsteps) ^ ". Took " ^
                           (IntInf.toString (Time.toMilliseconds end_time -
                                             Time.toMilliseconds start_time)) ^ " ms\n")
end
