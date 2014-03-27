structure MergeStreets =
struct

  exception MergeStreets of string

  structure StringMap = SplayMapFn(type ord_key = string
                                   val compare = String.compare)
  fun ++r = r := (1 + !r : IntInf.int)

  fun incrementby m k x =
    case StringMap.find (m, k) of
      NONE => StringMap.insert (m, k, x)
    | SOME n => StringMap.insert (m, k, n + x)

  fun run nil =
    print "There should be at least one file on the command-line.\n"
    | run l =
    let
      val names = ref (StringMap.empty : IntInf.int StringMap.map)

      fun onefile f =
        let
          val () = print ("Reading " ^ f ^ "...\n")
          val lines = Script.linesfromfile f
          fun oneline s =
            case String.fields (StringUtil.ischar #"\t") s of
              [count, name] =>
                (case IntInf.fromString count of
                   SOME count => names := incrementby (!names) name count
                 | NONE => print ("Unparseable int in: " ^ s ^ "\n"))
            | _ => print ("Ignored line " ^ s ^ "\n")
        in
          app oneline lines
        end

      val () = app onefile l
      val fo = TextIO.openOut "merged-counts.txt"
    in
      TextIO.output(TextIO.stdErr, "Writing names and counts...");
      StringMap.appi (fn (name, count) =>
                      let in
                        TextIO.output (fo, IntInf.toString count ^ "\t" ^ name ^ "\n")
                      end) (!names);
      TextIO.closeOut fo
    end

end


val () = Params.main "The state-counts.txt files, all on the command line." MergeStreets.run
