
val () = print "Hello.\n";

local
    (* If you get link errors about __imp, it's probably because you
       didn't import with "private" (or "public") visibility. It seems
       the default is now to expect a DLL to provide the symbol, which
       is what __imp is about. *)
    val init = _import "InitGame" private : unit -> unit ;
    val fs = _import "FillScreen2x" private : unit -> unit ;
    val ctr = ref 0
in
    val _ = init ()
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
