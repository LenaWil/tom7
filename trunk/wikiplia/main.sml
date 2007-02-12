
  fun message (Eval.Abort s) = "abort: " ^ s
    | message (Web.Web s) = "web: " ^ s
    | message e = "?:" ^ exnMessage e

val () = 
    case Params.docommandline () of
        nil => 
          (let in
             Initial.init ();
             (* Web.go () *)

             (let
                val res = 
                  case Eval.eval (DB.head "") of
                    Bytes.String s => s
                  | _ => "(complex data)"
              in
                print ("Result: [" ^ res ^ "]\n")
              end handle e => print ("ERROR:\n  " ^ message e ^ "\n"))
                
           end handle RawNetwork.RawNetwork s => print ("network error: " ^ s ^ "\n")
                    | Parse.Parse s => print ("parse error: " ^ s ^ "\n")
             )
      | _ =>
          let in
            print "\nThis program takes no arguments.\n\n";
            print (Params.usage ())
          end
