
structure ShowMachine =
struct
  val minutesp = Params.param "60" (SOME ("-minutes",
                                        "Number of minutes.")) "minutes"
  val statesp = Params.param "3" (SOME ("-states",
                                        "Number of cup states.")) "states"
  val playersp = Params.param "2" (SOME ("-players",
                                        "Number of players.")) "players"

  structure IIM = SplayMapFn(type ord_key = IntInf.int
                             val compare = IntInf.compare)

  exception Illegal
  fun go drinks =
  let
    val MINUTES = Params.asint 60 minutesp
    val NSTATES = Params.asint 7 statesp
    val NPLAYERS = Params.asint 2 playersp

    val drinks = map (fn s =>
                      case Int.fromString s of
                          NONE => (TextIO.output(TextIO.stdErr,
                                                 "Only integers on the command line.");
                                   raise Illegal)
                        | SOME i => i) drinks

    val cxpointfile = "checkpoint-" ^ Int.toString MINUTES ^ "m-" ^
        Int.toString NPLAYERS ^ "p-" ^
        Int.toString NSTATES ^ "s.tf"

    val () = print ("Looking up [" ^
                    StringUtil.delimit ", " (map Int.toString drinks) ^
                    "] in " ^ cxpointfile ^ "...\n")

    val SamplesTF.DB { entries = db } = SamplesTF.DB.fromfile cxpointfile
    exception Illegal
    val totalcount = ref (0 : IntInf.int)
    fun setct (_, _, s) =
        case IntInf.fromString s of
            NONE => raise Illegal
          | SOME i => totalcount := !totalcount + i
    val () = app setct db

    fun get (key, ex, count) = key = drinks

    fun tostring pl =
      let
          fun ctos c = "C" ^ Int.toString c
          fun cotos NONE = "(none)"
            | cotos (SOME c) = ctos c
          fun oneplayer (SamplesTF.P { start, rules }, i) =
              Int.toString i ^ ". Start: " ^ cotos start ^ "\n" ^
              String.concat (ListUtil.mapi (fn ((drink, dest, state), c) =>
                                            "  on " ^ ctos c ^
                                            (if drink
                                             then " =>+ "
                                             else " =>  ") ^
                                            ctos state ^ " @" ^
                                            Int.toString dest ^ "\n") rules)

      in
          String.concat (ListUtil.mapi oneplayer pl)
      end

  in
    case List.find get db of
        NONE => print "Not found.\n"
      | SOME (_, SamplesTF.E { players }, ct) =>
        let
            val c = valOf (IntInf.fromString ct)
            val d = Real.fromLargeInt (!totalcount) / Real.fromLargeInt c
        in
           print ("This outcome happened " ^ ct ^
                  "/" ^ IntInf.toString (!totalcount) ^ " times.\n");
           print ("That's 1/" ^
                  Real.fmt (StringCvt.FIX (SOME 0)) d ^ "!\n");
           print ("Example plan:\n" ^
                  tostring players ^ "\n")
        end
  end
end

val () = Params.main ("Pass the list of drink values as " ^
                      "command-line argumemts.") ShowMachine.go
