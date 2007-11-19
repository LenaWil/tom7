structure QuietDownNJ = struct end

(*   we generate multiple files, so -o doesn't really make sense *)
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
                print ("ML5/pgh version " ^ Version.version ^ "\n\n");
                print "Usage: ml5pgh file.ml5\n\n";
                print (Params.usage ())
            end

