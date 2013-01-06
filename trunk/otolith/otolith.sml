
structure Otolith =
struct

  exception Quit
  open Constants

  val fillscreen = _import "FillScreenFrom" private :
      Word32.word Array.array -> unit ;

  val ctr = ref 0
  val pixels = Array.array(WIDTH * HEIGHT, 0wxFFAAAAAA : Word32.word)
  val rc = ARCFOUR.initstring "anything"

  val tesselation = Tesselation.tesselation { x0 = 3, y0 = 3,
                                              x1 = WIDTH - 3, y1 = HEIGHT - 3 }

  val TESSELATIONLINES = Draw.mixcolor (0wxAA, 0wxAA, 0wx99, 0wxFF)

  (* PERF: draws edges twice *)
  fun drawtesselation () =
      let
          val triangles = Tesselation.triangles tesselation
          fun drawline (a, b) =
              let val (x0, y0) = Tesselation.N.coords a
                  val (x1, y1) = Tesselation.N.coords b
              in
                  Draw.drawline (pixels, x0, y0, x1, y1, TESSELATIONLINES)
              end

          fun drawone t =
              let val (a, b, c) = Tesselation.T.nodes t
              in
                  drawline (a, b);
                  drawline (b, c);
                  drawline (c, a)
              end
      in
          app drawone triangles
      end

  val start = Time.now()
  fun keypress () =
      case SDL.pollevent () of
          NONE => ()
        | SOME SDL.E_Quit => raise Quit
        | SOME (SDL.E_KeyDown { sym = SDL.SDLK_ESCAPE }) => raise Quit
        | _ => ()

  fun loop () =
      let
          val () = keypress ()

          val () = Draw.randomize pixels
          val () = drawtesselation ()
          (* val () = Draw.scanline_postfilter pixels *)
          val () = fillscreen pixels
          val () = ctr := !ctr + 1
      in
          if !ctr mod 1000 = 0
          then
              let
                  val now = Time.now ()
                  val sec = Time.toSeconds (Time.-(now, start))
                  val fps = real (!ctr) / Real.fromLargeInt (sec)
              in
                  print (Int.toString (!ctr) ^ " (" ^
                         Real.fmt (StringCvt.FIX (SOME 2)) fps ^ ")\n")
              end
          else ();
          loop()
      end

  val () = loop ()

end