(* Compares traces from bddtest and box2dtest, to find the first place that
   they diverge. *)
structure BDiff =
struct

    val whitelist = [("name1-name2 Contact!", "ground-drop Contact!")]
    fun whitealize (l, r) =
        let
            fun white1 ((lpat, rpat), (l, r)) =
                let val ll = StringUtil.replace lpat "**" l
                    val rr = StringUtil.replace rpat "**" r
                in
                    if l <> ll andalso r <> rr
                    then (ll, rr)
                    else (l, r)
                end
        in
            foldl white1 (l, r) whitelist
        end

    val bdd   = Script.linesfromfile "bdd.trace"
    val box2d = Script.linesfromfile "box2d.trace"

    (* SML uses ~ for negative sign, weird *)
    val bdd = map (StringUtil.replace "~" "-") bdd

    val CONTEXT = 5

    (* Normalize -0.0000 to 0.0000; these aren't exactly the same but probably
       not the source of bugs. *)
    val bdd = map (StringUtil.replace "-0.0000" "0.0000") bdd
    val box2d = map (StringUtil.replace "-0.0000" "0.0000") box2d

    fun find_difference (step, line, same) nil nil = print "Same trace.\n"
      | find_difference (step, line, same) nil (h :: _) = print ("BDD ended. Box2D: " ^ h ^ "\n")
      | find_difference (step, line, same) (h :: _) nil = print ("Box2D ended. BDD: " ^ h ^ "\n")
      | find_difference (step, line, same) (ldd :: restdd) (l2d :: rest2d) =
        let val (ldd, l2d) = whitealize (ldd, l2d)
        in
          if ldd <> l2d
          then
              let
                  fun recent 0 _ = ()
                    | recent _ nil = print "(start.)\n"
                    | recent n (h :: t) =
                      let in
                          recent (n - 1) t;
                          print ("Same: " ^ h ^ "\n")
                      end
                  val () = recent CONTEXT same

                  val () = print ("Difference at line " ^ Int.toString line ^ ":\n" ^
                                  "Box2D: " ^ l2d ^ "\n" ^
                                  "BDD:   " ^ ldd ^ "\n")
              in
              ()
              end
          else
          let
              (* XXX determine step. *)
          in
              find_difference (step, line + 1, ldd :: same) restdd rest2d
          end
        end

    val () = print (Int.toString (length bdd) ^ " lines from BDD. " ^ 
                    Int.toString (length box2d) ^ " lines from Box2d.\n")

    val () = find_difference (0, 0, nil) bdd box2d

end