(* XXX this is now inside SDL itself *)

signature SDLIMAGE =
sig
  
  val load : string -> SDL.surface

end

