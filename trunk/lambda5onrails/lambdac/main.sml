structure QuietDownNJ = struct end

(*
val outf = Params.param ""
    (SOME ("-o",
           "Name of bytecode output (relative to input file dir)")) "outf"
*)

val _ =
    case Params.docommandline () of
        [input] => Compile.compile input
      | _ =>
            let in
                print ("LAMBDAC version " ^ Version.version ^ "\n\n");
                print "Usage: lambdac file.ml5\n\n";
                print (Params.usage ())
            end

