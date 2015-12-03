structure Sprites =
struct

  val width = 800
  val height = 600

  (* game area *)
  val gamewidth = 256
(*
  val width = 256
  val height = 600
  val screen = SDL.makescreen (width, height) *)

(*  val screen = SDL.makefullscreen (width, height) *)
      (* XXX control by commandline flag *)
(*
  val FORCE_FULLSCREEN = true
  val screen =
      case SDL.platform of
          SDL.OSX => SDL.makefullscreen (width, height)
        | _ => if FORCE_FULLSCREEN
               then SDL.makefullscreen (width, height)
               else SDL.makescreen (width, height)
*)
  val screen = SDL.makescreen (width, height)

  val () = Hero.messagebox (Posix.FileSys.getcwd ())

  (* distance of nut (on-tempo target bar) from bottom of screen *)
  val NUTOFFSET = 127
  val GRAPHICS = "graphics/"

  fun requireimage s =
    case (SDL.loadimage (FSUtil.dirplus GRAPHICS s)) handle _ => NONE of
      NONE => (Hero.messagebox ("couldn't open " ^ s ^ "\n");
               raise Hero.Hero "couldn't open required file")
    | SOME p => p

  fun requireimage2x f =
    let val s = requireimage f
    in
      SDL.Util.surf2x s
      before SDL.freesurface s
    end

  val hugebig = requireimage2x "hugebig.png"
  val saskrotch = requireimage2x "saskrotch.png"
  val fatbaby = requireimage2x "fatbaby.png"

  val solid = requireimage "solid.png"

  val configure  = requireimage "configure.png"
  val background = requireimage "background.png"
  val backlite   = requireimage "backlite.png"

  val guitar = requireimage "guitar.png"
  val drums = requireimage "drums.png"
  val guitar2x = requireimage2x "guitar.png"
  val drums2x = requireimage2x "drums.png"
  val punch = requireimage "punch.png"
  val kick = requireimage "kick.png"
  val arrow_down = requireimage2x "arrow_down.png"
  val arrow_up = requireimage2x "arrow_up.png"

  val press = requireimage2x "press.png"
  val press_ok = requireimage2x "press_ok.png"
  val strum_down = requireimage2x "strum_down.png"
  val strum_up = requireimage2x "strum_up.png"

  val new = requireimage "new.png"

  val matchmedal = requireimage "matchmedal.png"
  val pokeymedal = requireimage "pokeymedal.png"
  val pluckymedal = requireimage "pluckymedal.png"
  val stoicmedal = requireimage "stoicmedal.png"
  val snakesmedal = requireimage "snakesmedal.png"

  fun medalg Hero.PerfectMatch = matchmedal
    | medalg Hero.Snakes = snakesmedal
    | medalg Hero.Stoic = stoicmedal
    | medalg Hero.Plucky = pluckymedal
    | medalg Hero.Pokey = pokeymedal
    | medalg Hero.AuthenticStrummer = press_ok (* XXX *)
    | medalg Hero.AuthenticHammer = press_ok (* XXX *)

  fun medal1 Hero.PerfectMatch = "Perfect"
    | medal1 Hero.Snakes = "Snakes!"
    | medal1 Hero.Stoic = "Stoic."
    | medal1 Hero.Plucky = "Plucky!"
    | medal1 Hero.Pokey = "Pokey!"
    | medal1 Hero.AuthenticStrummer = "Authentic"
    | medal1 Hero.AuthenticHammer = "Authentic"

  fun medal2 Hero.PerfectMatch = "Match!"
    | medal2 Hero.Snakes = ""
    | medal2 Hero.Stoic = ""
    | medal2 Hero.Plucky = ""
    | medal2 Hero.Pokey = ""
    | medal2 Hero.AuthenticStrummer = "Strummer"
    | medal2 Hero.AuthenticHammer = "Hammer"


  val stars = Vector.fromList
      [requireimage "greenstar.png",
       requireimage "redstar.png",
       requireimage "yellowstar.png",
       requireimage "bluestar.png",
       requireimage "orangestar.png"]

  val hammers = Vector.fromList
      [requireimage "greenhammer.png",
       requireimage "redhammer.png",
       requireimage "yellowhammer.png",
       requireimage "bluehammer.png",
       requireimage "orangehammer.png"]

  val zaps = Vector.fromList
      [requireimage "zap1.png",
       requireimage "zap1.png",
       requireimage "zap2.png",
       requireimage "zap2.png",
       requireimage "zap3.png",
       requireimage "zap3.png",
       requireimage "zap4.png", (* XXX hack attack *)
       requireimage "zap4.png"]

  val missed = requireimage "missed.png"

  val fingers = Vector.tabulate(Hero.FINGERS,
                                (fn i =>
                                 requireimage ("finger" ^ Int.toString i ^ ".png")))

  val title = requireimage "title.png"
  val humps = Vector.fromList(map requireimage ["hump1.png",
                                                "hump2.png",
                                                "hump3.png",
                                                "hump4.png"])

  val STARWIDTH = SDL.surface_width (Vector.sub(stars, 0))
  val STARHEIGHT = SDL.surface_height (Vector.sub(stars, 0))
  val ZAPWIDTH = SDL.surface_width (Vector.sub(zaps, 0))
  val ZAPHEIGHT = SDL.surface_height (Vector.sub(zaps, 0))
  val greenhi = requireimage "greenhighlight.png"
  val blackfade = requireimage "blackfade.png"

  val blackall = SDL.Util.alphadim blackfade (* just to copy size *)
                   handle SDL.SDL s => (Hero.messagebox s; raise Hero.Hero s)
  val () = SDL.clearsurface(blackall, SDL.color (0w0, 0w0, 0w0, 0w255))
             handle SDL.SDL s => Hero.messagebox s

  structure SmallFont =
  FontFn (val surf = requireimage "fontsmall.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          val width = 6
          val height = 6
          val styles = 6
          val overlap = 0
          val dims = 3)

  structure SmallFont3x =
  FontFn (val surf = requireimage "smallfont3x.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
          val width = 18
          val height = 18
          val styles = 6
          val overlap = 0
          val dims = 3)

  structure FontSmall =
  FontFn (val surf = requireimage "font.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *) ^ Chars.chars
          val width = 9
          val height = 16
          val styles = 7
          val overlap = 1
          val dims = 3)

  structure Font =
  FontFn (val surf = requireimage "fontbig.png"
          val charmap =
              " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
              "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *) ^ Chars.chars
          val width = 18
          val height = 32
          val styles = 7
          val overlap = 2
          val dims = 3)

  structure FontHuge =
  FontFn (val surf = requireimage "fonthuge.png"
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
  FontFn (val surf = requireimage "fontmax.png"
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

val () = print "Sprites initialized.\n"
