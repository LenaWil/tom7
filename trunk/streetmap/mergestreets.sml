structure MergeStreets =
struct

  val CANONICALIZE = true

  exception MergeStreets of string

  structure StringMap = SplayMapFn(type ord_key = string
                                   val compare = String.compare)
  fun ++r = r := (1 + !r : IntInf.int)

  fun canonicalize s =
    let
      val l = String.tokens (StringUtil.ischar #" ") s

      fun is_stopword nil _ = false
        | is_stopword (h :: t) hh = h = hh orelse is_stopword t hh

      val front = nil
      val back = ["Street", "Avenue", "Road", "Drive", "Place",
                  "Lane", "Boulevard", "Court", "Circle",
                  "Terrace", "Way", "Loop",
                  (* Usually bad data but obvious what to do: *)
                  "Cir", "Ln", "Dr", "Ave", "St"]

      (* Get rid of stopwords from the front *)
      val (_, l) = ListUtil.partitionaslongas (is_stopword front) l

      (* Reverse and do the same; put back *)
      val (_, l) = ListUtil.partitionaslongas (is_stopword back) (rev l)
      val l = rev l

    in
      StringUtil.delimit " " l
    end

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
                   SOME count =>
                     let val name = if CANONICALIZE
                                    then canonicalize name
                                    else name
                     in
                       names := incrementby (!names) name count
                     end
                 | NONE => print ("Unparseable int in: " ^ s ^ "\n"))
            | _ => print ("Ignored line " ^ s ^ "\n")
        in
          app oneline lines
        end

      val () = app onefile l
      val fo = TextIO.openOut "merged.txt"
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
