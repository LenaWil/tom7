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

  exception Done

  fun padname s n = s ^ (StringUtil.padex #"0" ~4 (Int.toString n)) ^ ".png"

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  val RED = SDL.color (0w255, 0w0, 0w0, 0w255)
  fun outline (surface, w, h, thickness, color) =
      let in
	  SDL.fillrect (surface, 0, 0, w, thickness, color);
	  SDL.fillrect (surface, 0, 0, thickness, h, color);
	  SDL.fillrect (surface, 0, h - thickness, w, thickness, color);
	  SDL.fillrect (surface, w - thickness, 0, thickness, h, color);
	  (* XXX *)
	  ()
      end

  fun start f =
    let 
      val waypoints = WP.loadfile f
      val cache = FrameCache.create_pattern
	  { max = 20,
	    prefix = WP.prefix waypoints,
	    padto = WP.padto waypoints,
	    first = WP.start waypoints,
	    suffix = WP.suffix waypoints }
      val WIDTH = FrameCache.width cache
      val HEIGHT = FrameCache.height cache
      val NUM = WP.num waypoints
      val screen = makescreen (WIDTH, HEIGHT)

      val cur = ref 0
      fun redraw () =
	  let val f = FrameCache.get cache (!cur)
	      val s = SDL.unpixels (WIDTH, HEIGHT, f)
	  in
	      SDL.blitall (s, screen, 0, 0);
	      SDL.freesurface s;

	      if WP.iswaypoint waypoints (!cur)
	      then outline (screen, WIDTH, HEIGHT, 8, RED)
	      else ();

	      Font.draw 
	      (screen, 10, 10,
	       "^3makewaypoints^<. left/right arrows to change frame.");
	      Font.draw 
	      (screen, 10, 10 + Font.height,
	       Int.toString (!cur) ^ " ^2/^< " ^ Int.toString (WP.num waypoints));

	      SDL.flip screen;
	      ()
	  end

      fun nav n =
	  let in
	      cur := Int.max (0, Int.min (!cur + n, NUM - 1));
	      redraw()
	  end

      fun pgdn () = nav 10
      fun pgup () = nav ~10
      fun prev () = nav ~1
      fun next () = nav 1

      fun space () =
	  let in
	      if WP.iswaypoint waypoints (!cur)
	      then WP.clearwaypoint waypoints (!cur)
	      else WP.setwaypoint waypoints (!cur);
	      redraw()
	  end

      fun loop () =
	  let
	      (* XXX *)
	  in
	      (case pollevent () of
		   NONE => ()
		 | SOME evt =>
		       case evt of
			   E_KeyDown { sym = SDLK_ESCAPE } => raise Done
			 | E_Quit => raise Done
			 | E_KeyDown { sym = SDLK_RIGHT } => next ()
			 | E_KeyDown { sym = SDLK_LEFT } => prev ()
			 | E_KeyDown { sym = SDLK_PAGEUP } => pgup ()
			 | E_KeyDown { sym = SDLK_PAGEDOWN } => pgdn ()
			 | E_KeyDown { sym = SDLK_SPACE } => space ()
			 | E_KeyDown { sym = SDLK_HOME } => nav (0 - NUM)
			 | E_KeyDown { sym = SDLK_END } => nav NUM
			 | _ => ());
	      SDL.delay 1;
	      loop ()
	  end

    in
      eprint ("Loaded waypoints from " ^ f ^ "\n");
      redraw ();
      loop () handle Done => WP.savefile waypoints f
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

