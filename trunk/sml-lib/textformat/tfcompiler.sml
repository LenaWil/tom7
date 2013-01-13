
structure TFCompiler =
struct
  fun eprint s = TextIO.output(TextIO.stdErr, s)

  structure D = DescriptionParser

  fun go file =
    let
        val s = StringUtil.readfile file
        val (D.D messages) = D.parse s
    in
        ()
    end


  val () = Params.main1 "Takes a single argument, the input .tfdesc file." go
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               D.DescriptionParser s => eprint s
             | SimpleTok.SimpleTok s => eprint s
             | _ => ());
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n";
          OS.Process.exit OS.Process.failure
      end

end
