
structure Prelude =
struct

  (* XXX would be preferable for this to be
     conditionally compiled or in the C code
     or something. *)
  val () = Port.setTopLevelHandler
      (fn e =>
       let
           val mb_ = _import "MessageBoxA" :
               MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
       in
           mb_(MLton.Pointer.null,
               exnName e ^ ": " ^ exnMessage e ^ "\000",
               "unhandled exception\000", MLton.Pointer.null);
           Port.defaultTopLevelHandler e
       end)

  val root = (FSUtil.chdir_excursion
              (CommandLine.name())
              (fn _ =>
               OS.FileSys.getDir ()))

  val () = Posix.FileSys.chdir root

end

(* When running without a console on some platforms (e.g. mingw),
   print will raise an exception. Redefine print so that it *)

val print_works =
    let
        val v = SDL.version()
    in
        (* unfortunately this cannot be the empty string, or it
           is optimized out *)
        print "Welcome to Tom 7 Entertainment System Hero.\n";
        print ("SDL version: " ^
               Int.toString (#major v) ^ "." ^
               Int.toString (#minor v) ^ "#" ^
               Int.toString (#patch v) ^ "\n");
        true
    end handle _ => false

(*
val () =
    let
        val mb_ = _import "MessageBoxA" :
            MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
    in
        mb_(MLton.Pointer.null,
            (if print_works then "print works\000" else "print not works\000"),
            "unhandled exception\000", MLton.Pointer.null)
    end
*)

(* Shadow the global print function. There are other ways to
   print that would fail too, but this is the only one we use. *)
val print = fn s => if print_works then print s else ()

val () = if Womb.detect ()
         then print "Womb detected.\n"
         else print "No womb detected.\n"