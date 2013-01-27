
local
  (* If you get link errors about __imp, it's probably because you
     didn't import with "private" (or "public") visibility. It seems
     the default is now to expect a DLL to provide the symbol, which
     is what __imp is about. *)
  val init = _import "InitGame" private : unit -> unit ;
in
  val () = init ()
end

(* XXX: Consider tricks from ../toward/prelude.sml *)

val () = print "Hello.\n";