
val () =
    case map Int.fromString (CommandLine.arguments ()) of
        [SOME wordsize, SOME number] =>
            print (MakeFixedWord.makestruct wordsize number)
      | _ =>
            let in
                print "Usage: makefixedword wordsize number > fixedwordWxN.sml\n"
            end
