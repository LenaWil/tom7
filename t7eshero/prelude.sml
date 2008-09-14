
structure Prelude =
struct

  local
      val mb_ = _import "MessageBoxA" : MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
  in
      fun messagebox s = mb_(MLton.Pointer.null, s ^ "\000", "Message!\000", 
                             MLton.Pointer.null)
      val () = messagebox "Prelude."
      val () = raise Match
  end

  val root = (FSUtil.chdir_excursion 
              (CommandLine.name())
              (fn _ =>
               OS.FileSys.getDir ()))

  val () = Posix.FileSys.chdir root

end