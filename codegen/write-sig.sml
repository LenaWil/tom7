
signature WRITE =
sig

  exception Write of string


  (* write base c
     
     Writes a series of files (one for each world)
     containing the ready-to-run code in c. The files
     are named base_world.ext, where ext is the
     appropriate extension for the worldkind. *)
  val write : string -> (string * Codegen.code) list -> unit

end
