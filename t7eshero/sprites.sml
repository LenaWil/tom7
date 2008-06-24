structure Sprites =
struct

  val width = 256
  val height = 600
  val screen = SDL.makescreen (width, height)

  val () = Hero.messagebox (Posix.FileSys.getcwd ())

  (* distance of nut (on-tempo target bar) from bottom of screen *)
  val NUTOFFSET = 127

  fun requireimage s =
    case (SDL.Image.load s) handle _ => NONE of
      NONE => (Hero.messagebox ("couldn't open " ^ s ^ "\n");
               raise Hero.Hero "couldn't open required file")
    | SOME p => p

  fun requireimage2x f =
      let val s = requireimage f
      in
          SDL.surf2x s
          before SDL.freesurface s
      end

  val solid = requireimage "testgraphics/solid.png"

  val configure  = requireimage "testgraphics/configure.png"
  val background = requireimage "testgraphics/background.png"
  val backlite   = requireimage "testgraphics/backlite.png"

  val guitar = requireimage2x "testgraphics/guitar.png"
  val press = requireimage2x "testgraphics/press.png"
  val press_ok = requireimage2x "testgraphics/press_ok.png"
  val strum_down = requireimage2x "testgraphics/strum_down.png"
  val strum_up = requireimage2x "testgraphics/strum_up.png"

  val new = requireimage "testgraphics/new.png"

  val matchmedal = requireimage "testgraphics/matchmedal.png"
  val pokeymedal = requireimage "testgraphics/pokeymedal.png"
  val pluckymedal = requireimage "testgraphics/pluckymedal.png"

      (* FIXME *)
  val stoicmedal = requireimage "testgraphics/pluckymedal.png"
  val snakesmedal = requireimage "testgraphics/pluckymedal.png"

  val stars = Vector.fromList
      [requireimage "testgraphics/greenstar.png",
       requireimage "testgraphics/redstar.png",
       requireimage "testgraphics/yellowstar.png",
       requireimage "testgraphics/bluestar.png",
       requireimage "testgraphics/orangestar.png"]

  val hammers = Vector.fromList
      [requireimage "testgraphics/greenhammer.png",
       requireimage "testgraphics/redhammer.png",
       requireimage "testgraphics/yellowhammer.png",
       requireimage "testgraphics/bluehammer.png",
       requireimage "testgraphics/orangehammer.png"]

  val zaps = Vector.fromList
      [requireimage "testgraphics/zap1.png",
       requireimage "testgraphics/zap1.png",
       requireimage "testgraphics/zap2.png",
       requireimage "testgraphics/zap2.png",
       requireimage "testgraphics/zap3.png",
       requireimage "testgraphics/zap3.png",
       requireimage "testgraphics/zap4.png", (* XXX hack attack *)
       requireimage "testgraphics/zap4.png"]

  val missed = requireimage "testgraphics/missed.png"

  val fingers = Vector.tabulate(Hero.FINGERS, 
                                (fn i =>
                                 requireimage ("testgraphics/finger" ^ Int.toString i ^ ".png")))

  val title = requireimage "testgraphics/title.png"
  val humps = Vector.fromList(map requireimage ["testgraphics/hump1.png",
                                                "testgraphics/hump2.png",
                                                "testgraphics/hump3.png",
                                                "testgraphics/hump4.png"])

  val STARWIDTH = SDL.surface_width (Vector.sub(stars, 0))
  val STARHEIGHT = SDL.surface_height (Vector.sub(stars, 0))
  val ZAPWIDTH = SDL.surface_width (Vector.sub(zaps, 0))
  val ZAPHEIGHT = SDL.surface_height (Vector.sub(zaps, 0))
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val blackfade = requireimage "testgraphics/blackfade.png"

  val blackall = SDL.alphadim blackfade (* just to copy size *)
                   handle SDL.SDL s => (Hero.messagebox s; raise Hero.Hero s)
  val () = SDL.clearsurface(blackall, SDL.color (0w0, 0w0, 0w0, 0w255))
             handle SDL.SDL s => Hero.messagebox s

  structure SmallFont = 
  FontFn (val surf = requireimage "testgraphics/fontsmall.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          val width = 6
          val height = 6
          val styles = 6
          val overlap = 0
          val dims = 3)

  structure SmallFont3x = 
  FontFn (val surf = requireimage "testgraphics/smallfont3x.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          val width = 18
          val height = 18
          val styles = 6
          val overlap = 0
          val dims = 3)

  structure FontSmall = 
  FontFn (val surf = requireimage "testgraphics/font.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *) ^ Chars.chars
          val width = 9
          val height = 16
          val styles = 7
          val overlap = 1
          val dims = 3)

  structure Font = 
  FontFn (val surf = requireimage "testgraphics/fontbig.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *) ^ Chars.chars
          val width = 18
          val height = 32
          val styles = 7
          val overlap = 2
          val dims = 3)

  structure FontHuge = 
  FontFn (val surf = requireimage "testgraphics/fonthuge.png"
          val charmap =
          " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
          "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *) ^ Chars.chars
          val width = 27
          val height = 48
          val styles = 7
          val overlap = 3
          val dims = 3)

  (* PERF probably not being used; bigger than I thought *)
  structure FontMax = 
  FontFn (val surf = requireimage "testgraphics/fontmax.png"
          val charmap =
          " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
          "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *) ^ Chars.chars
          val width = 27 * 2
          val height = 48 * 2
          val styles = 7
          val overlap = 3 * 2
          (* 18mb per image! *)
          val dims = 1)

end
