structure Images =
struct

  exception Images

  type image = int * int * Word32.word Array.array

  fun loadimage f =
    case SDL.Image.load f of
      NONE => (print ("Couldn't load " ^ f ^ "\n");
               raise Images)
    | SOME surf =>
        let
          (* XXX This gets the pixel order wrong. *)
          val (width, height, pixels) = SDL.pixels32 surf
        in
          print ("Loaded " ^ f ^ " (" ^
                 Int.toString width ^
                 "x" ^
                 Int.toString height ^
                 ")\n");
          SDL.freesurface surf;
          (width, height, pixels)
        end

  val pxfont = loadimage "pxfont.png"

  (* val testcursor = loadimage "testcursor.png" *)
  val tinymouse = loadimage "tinymouse.png"

  val mapcell = loadimage "mapcell.png"
  val mapcellnone = loadimage "mapcellnone.png"

end
