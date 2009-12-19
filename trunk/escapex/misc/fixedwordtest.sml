
(* we assume these bits and numbers are correct *)
functor TestFixed(val bits : int
                  val num : int
                  structure W : WORD
                  structure F : FIXEDWORDVEC where type word = W.word) =
struct

    fun twoto 0 = 1
      | twoto n = 2 * twoto (n - 1)
    val maxword = twoto bits - 1

    exception Test

    fun test () =
        let
            val a = [List.tabulate (num, fn _ => W.fromInt maxword)]
            val b = [List.tabulate (num, fn _ => W.fromInt 1)]
            val n = [List.tabulate (num, fn _ => W.fromInt 0)]
            val h = ListUtil.permutations (List.tabulate (num, fn x =>
                                                          if x mod 2 = 0
                                                          then W.fromInt 0
                                                          else W.fromInt maxword))
            val u = ListUtil.permutations (List.tabulate (num, fn x =>
                                                          if x mod 2 <> 0
                                                          then W.fromInt 0
                                                          else W.fromInt maxword))

            val z = ListUtil.permutations (List.tabulate (num, fn x =>
                                                          W.fromInt ((x * x + 1) mod maxword)))
(*
            val b = ListUtil.permutations [W.fromInt 0x11, W.fromInt 0x1, W.fromInt 0x0,
                                           W.fromInt 1, W.fromInt 2, W.fromInt 3]
*)
        (* test for all permutations *)
            fun onelist h =
                let
                    val v = F.fromList h
                    val l = F.foldr op:: nil v
                in
                    if ListUtil.all2 op= h l
                    then ()
                    else (print "\nin:\n";
                          app (fn x => print (W.toString x ^ " ")) h;
                          print "\nrep:\n";
                          print (F.tostring v ^ "\n");
                          print "\nout:\n";
                          app (fn x => print (W.toString x ^ " ")) l;
                          print "FAIL!\n"; raise Test)
                end
                
        in
            app onelist b;
            app onelist a;
            app onelist n;
            app onelist h;
            app onelist u;
            app onelist z;
            print "ok.\n"
        end

    val () = test ()

end