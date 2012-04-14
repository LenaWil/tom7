structure BDDTest =
struct

(*
  val prefix = Params.param ""
      (SOME ("-prefix", "")) "prefix"

  val num = Params.param "0"
      (SOME ("-num", "Number of frames in input.")) "num"
      
  val suffix = 

  val padto = Params.param "6"
      (SOME ("-padto", "Number of digits of padding in numeric part."

  val frames = Params.param "0"
      (SOME ("-frames", "Write this many iterations to PNG series, " ^
             "then stop.")) "frames"
*)
  structure U = Util
  open SDL
  structure Util = U
  structure FU = FrameUtil
  structure WP = Waypoints

(*
  structure Font = FontFn
  (val surf = Images.requireimage "font.png"
   val charmap =
       " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
       "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* " *)
   val width = 9
   val height = 16
   val styles = 6
   val overlap = 1
   val dims = 3)
*)

  exception Done

  fun padname s n = s ^ (StringUtil.padex #"0" ~4 (Int.toString n)) ^ ".png"

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  fun start f =
    let 
      val waypoints = WP.loadfile f
      val cache = FrameCache.create_pattern
	  { max = WP.num waypoints,
	    prefix = WP.prefix waypoints,
	    padto = WP.padto waypoints,
	    first = WP.start waypoints,
	    suffix = WP.suffix waypoints }
      val WIDTH = FrameCache.width cache
      val HEIGHT = FrameCache.height cache
      val screen = makescreen (WIDTH, HEIGHT)

      val cur = ref 0
      fun show () =
	  let val f = FrameCache.get cache (!cur)
	      val s = SDL.unpixels (WIDTH, HEIGHT, f)
	  in
	      SDL.blitall (s, screen, 0, 0);
	      SDL.flip screen;
	      SDL.freesurface s
	  end

      val () = show ()


      fun loop () =
	  let
	      (* XXX *)
	  in
	      (case pollevent () of
		   NONE => ()
		 | SOME evt =>
		       case evt of
			   E_KeyDown { sym = SDLK_ESCAPE } => raise Done
			 | _ => ());
	      SDL.delay 1;
	      loop ()
	  end

    in
      eprint ("Loaded waypoints from " ^ f ^ "\n");
      loop ()
    end

  val () = Params.main1 "Give waypoint file to edit." start
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               FrameCache.FrameCache s => eprint ("cache: " ^ s)
             | FrameUtil.FrameUtil s => eprint ("frameutil: " ^ s)
	     | WP.Waypoints s => eprint ("waypoints: " ^ s)
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end

end

