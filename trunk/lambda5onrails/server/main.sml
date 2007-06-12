
val () = 
    case Params.docommandline () of
        nil => 
          (let in
             Web.go ()
           end handle e => print (Web.message e)
             )
      | _ =>
          let in
            print "\nThis program takes no arguments.\n\n";
            print (Params.usage ())
          end
