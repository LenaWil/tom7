
val () = print "Hello.\n";

local
    val init = _import "initgame" : unit -> unit ;
    val fs = _import "FillScreen2x" : unit -> unit ;
    val ctr = ref 0
in
    val start = Time.now()
    fun loop () =
        let
            val () = fs ()
            val () = ctr := !ctr + 1
        in
            if !ctr mod 1000 = 0
            then
                let
                    val now = Time.now ()
                    val sec = Time.toSeconds (Time.-(now, start))
                    val fps = real (!ctr) / Real.fromLargeInt (sec)
                in
                    print (LargeInt.toString sec ^ " (" ^
                           Real.fmt (StringCvt.FIX (SOME 2)) fps ^ ")\n")
                end
            else ();
            loop()
        end

    val () = loop ()
end
