structure JSEval :> JSEVAL =
struct
    
    exception JSEval of string

    open Javascript

    type ('a, 'b) hash = ('a * 'b) list

    datatype object =
        O of (object hash
      | S of string
      | R of real
        
        
    fun execprog (Program.T st) =
        
            


    fun execute (p : Program.t) =
        let
            val start = Time.now ()

            val _ = execprog p

            val stop = Time.now ()
        in
            print ("Time to evaluate: " ^
                   Time.toString (Time.- (stop, start)) ^ "\n");
            ()
        end

end
