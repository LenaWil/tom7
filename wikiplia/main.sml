
val () = 
    case Params.docommandline () of
        nil => Web.loop ()
      | _ =>
          let in
            print "\nThis program takes no arguments.\n\n";
            print (Params.usage ())
          end
