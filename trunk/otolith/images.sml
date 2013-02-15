structure Images =
struct

  exception Images

  type image = int * int * Word32.word Array.array
  (* XXX should have different animation modes,
     wait on frame, etc. *)
  type anim = image Vector.vector

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

  fun loadanim (base, ext, lo, hi) : anim =
     Vector.tabulate (hi - lo + 1,
                    fn i => loadimage (base ^
                                       Int.toString (lo + i) ^
                                       ext))

  val pxfont = loadimage "pxfont.png"

  (* val testcursor = loadimage "testcursor.png" *)
  val tinymouse = loadimage "tinymouse.png"

  val mapcell = loadimage "mapcell.png"
  val mapcellnone = loadimage "mapcellnone.png"

  val runleft = loadanim ("run", ".png", 1, 10)

  fun numframes (v : anim) : int = Vector.length v
  fun getframe (v : anim, i) : image = Vector.sub (v, i)

end
