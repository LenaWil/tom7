(* Common datatype and constant definitions for T7eshero. *)
structure Hero =
struct

  (* Merely having this code linked in means that mlton dies
     during initialization. (Even though it's dead code.) *)
  fun messagebox s =
      let val f = TextIO.openAppend("/tmp/t7es.txt")
      in
 ()
          (* TextIO.output(f, s ^"\n");
          TextIO.closeOut(f) *)
      end

  fun messagebox s = print (s ^ "\n")


end