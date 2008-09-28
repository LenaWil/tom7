

  val mb_ = _import "MessageBoxA" : MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
  val () = mb_(MLton.Pointer.null, "Click.\000", "\000", MLton.Pointer.null)

  (* Merely having this code linked in means that mlton dies
     during initialization. (Even though it's dead code.) *)

  fun g s = print s
