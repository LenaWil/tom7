structure Sprites =
struct

  val width = 256
  val height = 600
  val screen = SDL.makescreen (width, height)

  (* distance of nut (on-tempo target bar) from bottom of screen *)
  val NUTOFFSET = 127

  fun requireimage s =
    case (SDL.Image.load s) handle _ => NONE of
      NONE => (Hero.messagebox ("couldn't open " ^ s ^ "\n");
               raise Hero.Hero "couldn't open required file")
    | SOME p => p

  val solid = requireimage "testgraphics/solid.png"

  val background = requireimage "testgraphics/background.png"
  val backlite   = requireimage "testgraphics/backlite.png"

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
      [requireimage "zap1.png",
       requireimage "zap1.png",
       requireimage "zap2.png",
       requireimage "zap2.png",
       requireimage "zap3.png",
       requireimage "zap3.png",
       requireimage "zap4.png", (* XXX hack attack *)
       requireimage "zap4.png"]

  val missed = requireimage "testgraphics/missed.png"
  val hit = requireimage "testgraphics/hit.png"

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
  val robobox = requireimage "testgraphics/robobox.png"

  val blackall = SDL.alphadim blackfade (* just to copy size *)
                   handle SDL.SDL s => (Hero.messagebox s; raise Hero.Hero s)
  val () = SDL.clearsurface(blackall, SDL.color (0w0, 0w0, 0w0, 0w255))
             handle SDL.SDL s => Hero.messagebox s

  structure Font = 
  FontFn (val surf = requireimage "testgraphics/fontbig.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          (* CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 
             BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
          val width = 18
          val height = 32
          val styles = 6
          val overlap = 2
          val dims = 3)

  structure FontHuge = 
  FontFn (val surf = requireimage "testgraphics/fonthuge.png"
          val charmap =
          " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
          "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          (* CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 
             BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
          val width = 27
          val height = 48
          val styles = 6
          val overlap = 3
          val dims = 3)

  structure FontMax = 
  FontFn (val surf = requireimage "testgraphics/fontmax.png"
          val charmap =
          " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
          "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          (* CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 
             BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
          val width = 27 * 2
          val height = 48 * 2
          val styles = 6
          val overlap = 3 * 2
          (* 18mb per image! *)
          val dims = 1)

end
