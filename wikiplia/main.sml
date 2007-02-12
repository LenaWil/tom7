
val () = 
    case Params.docommandline () of
        nil => 
          (let in
             Initial.init ();
             Web.go ()
           end handle RawNetwork.RawNetwork s => print ("network error: " ^ s ^ "\n")
                    | Parse.Parse s => print ("parse error: " ^ s ^ "\n")
             )
      | _ =>
          let in
            print "\nThis program takes no arguments.\n\n";
            print (Params.usage ())
          end
