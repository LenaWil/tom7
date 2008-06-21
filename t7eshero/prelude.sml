
structure Prelude =
struct

  val root = (FSUtil.chdir_excursion 
              (CommandLine.name())
              (fn _ =>
               OS.FileSys.getDir ()))

  val () = Posix.FileSys.chdir root

end