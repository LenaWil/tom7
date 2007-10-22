
fun message e =
  (case e of
     RawNetwork.RawNetwork s => "rn: " ^ s
   | Child.Child s => "child: " ^ s
   | _ => exnMessage e)

val () = 
    case Params.docommandline () of
        nil => 
          (let in
               Loop.init ();
               Loop.loop nil
           end handle e => print ("ERROR: " ^ message e ^ "\n")
             )
      | _ =>
          let in
            print "\nThis program takes no arguments.\n\n";
            print (Params.usage ())
          end
