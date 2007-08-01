structure QuietDownNJ = struct end

val outf = Params.param ""
    (SOME ("-o",
           "Name of bytecode output (relative to input file dir)")) "outf"

val _ =
    case Params.docommandline () of
        [input] => OS.Process.exit(Compile.compile input (!outf))
      | _ =>
            let in
                print ("LAMBDAC version " ^ Version.version ^ "\n\n");
                print "Usage: lambdac file.ml5\n\n";
                print (Params.usage ())
            end

structure T =
struct
  fun test s = Compile.compile s "test.out"
end
