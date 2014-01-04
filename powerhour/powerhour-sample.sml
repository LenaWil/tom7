(* Power-Hour sampling approach. Unlike the code in powerhour.sml, we
   are not trying to enumerate all possible power hours. Instead, we
   are trying to explore the space (e.g. randomly) to establish that
   certain possibilities are possible. The expectation is that for
   very powerful BMnL games (e.g. 100 cup states) and small
   possibility radixes (e.g. 2 players in 60 minutes) that we'd
   efficiently establish the existence of games covering the
   entire matrix. Of course, p players in BM8L can achieve any
   result (because one player can), so this is mostly useful
   when p is small but the number of cup states is < 8. Specifically,
   we hope to either show that BM6L or BM7L covers the grid for
   two-player games, tightening that bound.

   Because of this use, it's not critical that we can generate
   all possible legal games, nor that we do so uniformly. We also don't
   care about shots wasted, prefering to just optimize for throughput.
*)

structure PH =
struct
  structure MT = MersenneTwister

  val MINUTES = 60

  (* Types that define Power Hour Machines, which
     completely describe a power hour algorithm. *)
  type cup = int
  (* Number of cup states, not really the number of cups. For BMML,
     should be 3. *)
  val NCUPS = 6
  val NPLAYERS = 3

  val cxpointfile = "checkpoint-" ^ Int.toString MINUTES ^ "m-" ^
      Int.toString NPLAYERS ^ "p-" ^
      Int.toString NCUPS ^ "s.tf"

  val FILLED = 0

  val ALWAYS_START_CUP = false

  (* What a player does on a turn when he sees a state other than None.
     (In None, the only legal action is to not drink and not pass.)
     After drinking at most once, he can pass the cup to any player in
     a state of his choice, but:
      - If the cup is filled and we didn't drink, it stays
        filled.
      - The result of the round cannot have more than one
        cup in a given location.
     Note that it is normal for the player to pass to himself. *)
  type action = int * cup

  (* The starting state for the player, and the three actions that can
     be specified. Note that in the no-cup case, the only legal action
     is to not drink and not pass, so this is not represented.

     We don't do the lazy expansion of rules like in powerhour.sml,
     as we will be generating these randomly and can just make concrete
     ones from the start. *)
  datatype player = P of { start : cup option,
                           (* length NCUPS *)
                           rules : action vector }

  type machine = player list

  fun toexample (m : machine, plans : bool vector list) : SamplesTF.example =
      let
          val together : (player * bool vector) list = ListUtil.wed m plans
          fun one (P { start, rules } : player,
                   bv : bool vector) : SamplesTF.player =
              let
                  val bl = Vector.foldr op:: nil bv
                  val rl = Vector.foldr op:: nil rules
                  val rulesdrink : (bool * action) list = ListUtil.wed bl rl
              in
                  SamplesTF.P
                  { start = start,
                    rules = map (fn (b, (dest, state)) =>
                                 (b, dest, state)) rulesdrink }
              end
      in
          SamplesTF.E { players = map one together }
      end

  exception Unimplemented

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
              the rule might never actually execute.
              (PS. this exactness is not necessary in the
              sampling approach, so consider simplifying.)
              *)
           mustdrink0 : bool array,
           (* How many times was each rule executed (and
              thus could drink?) Remember to check the
              mustdrink0 bit. *)
           ruleexecuted : int array vector,
           (* What round is it? 0-59 *)
           round : int ref }

  (* How many did each player drink? *)
  type result = int vector

  (* PERF *)
  fun makesim (m : machine) =
      let
          val players = Vector.fromList m
          val n = Vector.length players
      in
          S { cups = ref (Array.fromList (map (fn P { start, ... } =>
                                               start) m)),
              players = players,
              mustdrink0 = Array.array (n, false),
              ruleexecuted = Vector.tabulate (n, (fn _ =>
                                                  Array.array(NCUPS, 0))),
              round = ref 0 }
      end

  exception Illegal of string

  val totalsteps = ref (0 : IntInf.int)
  (* Evaluate one step of the simulation. Raises Illegal if
     two or more cups end up in the same position. *)
  fun step (S { cups, players, mustdrink0, ruleexecuted, round }) =
      let
        val newcups = Array.array (Array.length (!cups), NONE)

        fun oneplayer (i, P { rules, ... }) =
          case Array.sub (!cups, i) of
              NONE => ()
            | SOME now =>
              let
                val (dest, next) = Vector.sub (rules, now)
                val rulecounts_for_player = Vector.sub (ruleexecuted, i)
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
      in
          totalsteps := !totalsteps + 1;
          Vector.appi oneplayer players;
          cups := newcups;
          round := !round + 1
      end

  (* Generate a random game. We don't care that much about having a uniform
     distribution (which would need to be defined anyway) nor generating
     every possible weird game. However, missing too many games could
     interfere with us establishing bounds. Main thing we want to do is
     avoid exploring games that will obviously crash at runtime, but
     effort avoiding this may be misplaced, since these games are quickly
     filtered out during simulation.

     So let's start with the simplest thing, which is to just fill in
     every free slot uniformly at random. *)
  val mt = MT.initstring ("powerhour" ^ Time.toString (Time.now ()))
  fun randomgame () =
      let
          (* Generate a random cup state in [0, ncups) *)
          fun randomcup () =
              MT.random_nat mt NCUPS
          fun randomstart () =
              if ALWAYS_START_CUP then SOME (randomcup ())
              else
                (* PERF could just generate 1 number *)
                (* XXX set this really high since the bottom-right
                   half of the matrix can only be reached if both
                   players have cups! *)
                case MT.random_nat mt 32 (* (NCUPS + 1) *) of
                    0 => NONE
                  | _ => SOME (randomcup ())

          fun randomplayer () =
              MT.random_nat mt NPLAYERS

          fun randomrule () : action =
              (randomplayer (), randomcup ())

          fun randomrules () : action vector =
              (* PERF way to do this directly? *)
              Vector.tabulate
              (NCUPS, fn _ => randomrule ())

          fun oneplayer _ =
              P { start = randomstart (),
                  rules = randomrules () }
      in
          List.tabulate (NPLAYERS, oneplayer)
      end

  fun drinks_cmp (drinks, dd) =
      Util.lex_vector_order Int.compare (drinks, dd)

  structure RM = SplayMapFn(type ord_key = result
                            val compare = drinks_cmp)

  fun revexample (SamplesTF.E { players }) =
      SamplesTF.E { players = rev players }

  fun writedb (db : (SamplesTF.example * IntInf.int) RM.map) =
      let
          val () = TextIO.output(TextIO.stdErr, "Writing " ^
                                 cxpointfile ^ "\n")
          fun vtol v = Vector.foldr op:: nil v
          val db = RM.listItemsi db
          val db = map (fn (v, (ex, count)) =>
                        (vtol v, ex, IntInf.toString count)) db
          val db = SamplesTF.DB { entries = db }
      in
          SamplesTF.DB.tofile cxpointfile db;
          TextIO.output(TextIO.stdErr, "... done\n")
      end

  fun readdb () : (SamplesTF.example * IntInf.int) RM.map =
      case (SamplesTF.DB.maybefromfile cxpointfile handle _ => NONE) of
          NONE => RM.empty
        | SOME (SamplesTF.DB { entries }) =>
              let val m = ref RM.empty
              in
                  app (fn (drinks, example, count) =>
                       let val count = Option.valOf (IntInf.fromString count)
                           val drinks = Vector.fromList drinks
                       in
                           m := RM.insert (!m, drinks, (example, count))
                       end) entries;
                  !m
              end

  (* For readout while running. One for benchmarking is at the bottom. *)
  val startseconds = Time.toSeconds (Time.now ())
  fun sampleloop () =
    let
        (* We load the existing database (if any) on startup and write it
           back periodically, or whenever we make progress.

           The map contains an arbitrary example machine that produces
           the claimed result, in SampleTF format. The IntInf is the
           count of times we inserted something with that outcome. *)
        val done = ref (readdb ())

        (* These are session-level *)
        val nillegal = ref (0 : IntInf.int)
        val nok = ref (0 : IntInf.int)
        val nsamples = ref (0 : IntInf.int)

        fun pow n 0 = 1
          | pow n m = n * pow n (m - 1)
        (* +1 because there is a cell for 0 drinks as well as 60 *)
        val totalcells = pow (MINUTES + 1) NPLAYERS
        val filledcells = ref (RM.numItems (!done))
        (* Value of filled cells last time we wrote the database. *)
        val lastfilledcells = ref (!filledcells)
        val lastwrite = ref (Time.toSeconds (Time.now ()))
        val () =
            if !filledcells > 0
            then TextIO.output (TextIO.stdErr,
                                "Read database with " ^
                                Int.toString (!filledcells) ^ "/" ^
                                Int.toString totalcells ^ " already found\n")
            else TextIO.output (TextIO.stdErr,
                                "Starting with fresh empty database.\n")

        fun account () =
           let in
               nsamples := !nsamples + 1;
               if !nsamples mod 1000000 = 0
               then
                   let
                       val nowseconds = Time.toSeconds (Time.now ())
                       val secs = nowseconds - startseconds
                       val sps = Real.fromLargeInt (!totalsteps) /
                           Real.fromLargeInt secs
                       val gps = Real.fromLargeInt (!nsamples) /
                           Real.fromLargeInt secs
                       val legal = Real.fromLargeInt (!nok * 100) /
                           Real.fromLargeInt (!nok + !nillegal)
                       val filled = real (!filledcells * 100) /
                           real totalcells
                   in
                       if ((!filledcells > !lastfilledcells) andalso
                           nowseconds - !lastwrite > 120)
                          orelse
                          nowseconds - !lastwrite > 30 * 60
                       then
                           let in
                               writedb (!done);
                               lastfilledcells := !filledcells;
                               lastwrite := nowseconds
                           end
                       else ();
                       TextIO.output
                       (TextIO.stdErr, "#" ^ IntInf.toString (!nsamples) ^
                        " " ^ Real.fmt (StringCvt.FIX (SOME 0)) sps ^
                        " states/sec" ^
                        " " ^ Real.fmt (StringCvt.FIX (SOME 0)) gps ^
                        " config/sec" ^
                        " " ^ Real.fmt (StringCvt.FIX (SOME 2)) legal ^
                        "% legal" ^
                        " " ^ Real.fmt (StringCvt.FIX (SOME 3)) filled ^
                        "% filled" ^
                        "\n")
                   end
               else ()
           end

        fun add_example (m, plans) dr =
            case RM.find (!done, dr) of
                NONE =>
                    let in
                        filledcells := 1 + !filledcells;
                        done := RM.insert (!done, dr, (toexample (m, plans), 1))
                    end
              | SOME (old, n) => done := RM.insert (!done, dr, (old, n + 1))

        (* PERF
           When I add (x, y, z) I also can just add (y, x, z) and so
           on.  But better yet would be to put in some normal form
           like (x <= y <= z) so that we keep the map and (especially)
           the .tf file small. *)
        fun add_example_perms (m, plans) drinks =
            (* XXX maybe unique permutations? This may overcount the
               diagonal, depending on your perspective.

               XXX, also, the example needs to be permuted too. Here
               we just store the same one. (This is easy to recover
               from after the fact if we wanted to.) *)
            let val perms = ListUtil.permutations drinks
            in app (fn d => add_example (m, plans) (Vector.fromList d)) perms
            end

        (* We executed m abstractly, and mustdrink0 / ruleexecuted
           tell us how many drinks we can drink. Each cell in ruleexecuted
           says how many times the corresponding rule was excuted. So
           we have drinks = d_1 * re_1 + ... + d_ncups * re_ncups total
           drinks, where d_i is always 1 or 0. if mustdrink0 is 0 for a
           player, then d_1 must be 1 (sorry, confusion between 0-indexed
           and 1-indexed here). *)
        fun add_metaresult m { mustdrink0, ruleexecuted } =
           let
               (* XXX this is constant *)
               val nplayers = Array.length mustdrink0
               (* Each player can choose which rules drink independently,
                  which is part of what reduces the space here so much.

                  For the player, produce a list of pairs; the first is
                  the num drank in [0, 60] and the second is the
                  NCUPS-length vector of bools for whether the nth rule
                  should drink. No duplicates. *)
               fun oneplayer i =
                 let
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
                   in add_example_perms (m, plans) outcome
                   end
           in
               allcomb doone nil players
           end

        fun process () =
            let val m = randomgame ()
                fun simulate (s as S { round = ref round, mustdrink0,
                                       ruleexecuted, cups, ... }) =
                  if round = MINUTES
                  then
                      let in
                          nok := 1 + !nok;
                          add_metaresult m ({ mustdrink0 = mustdrink0,
                                              ruleexecuted = ruleexecuted });
                          account ()
                      end
                  else
                     let in
                         step s;
                         simulate s
                     end
            in
              (simulate (makesim m)
               handle Illegal str =>
                   let in
                       nillegal := 1 + !nillegal;
                       account ()
                   end);

              if !filledcells < totalcells
              then process()
              else !done
            end
    in
        process()
    end

   val start_time = Time.now()
   val (db : (SamplesTF.example * IntInf.int) RM.map) = sampleloop()
   val () = writedb db
   val end_time = Time.now()

   val () = TextIO.output
       (TextIO.stdErr,
        "Total steps " ^ IntInf.toString (!totalsteps) ^ ". Took " ^
        (IntInf.toString (Time.toMilliseconds end_time -
                          Time.toMilliseconds start_time)) ^ " ms\n")
end
