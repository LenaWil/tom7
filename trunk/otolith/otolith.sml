
structure Otolith =
struct

  exception Quit
  open Constants

  fun eprint s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val fillscreen = _import "FillScreenFrom" private :
      Word32.word Array.array -> unit ;

  val ctr = ref 0
  val pixels = Array.array(WIDTH * HEIGHT, 0wxFFAAAAAA : Word32.word)
  val rc = ARCFOUR.initstring "anything"

  (* TODO: This needs to become some kind of screen or world type. *)
  (* Tesselation itself is mutable, but sometimes we want to swap the
     entire tesselation out, like in undo or save/load. *)
  val tesselation =
      ref (Tesselation.tesselation { x0 = 0, y0 = 0,
                                     x1 = WIDTH - 1, y1 = HEIGHT - 1 })
  val objects : Object.object list ref = ref nil

  val TESSELATIONLINES = Draw.mixcolor (0wx44, 0wx44, 0wx55, 0wxFF)
  val TESSELATIONNODES = Draw.mixcolor (0wx66, 0wx66, 0wx77, 0wxFF)

  (* PERF: draws edges twice *)
  fun drawtesselation () =
      let
          val triangles = Tesselation.triangles (!tesselation)
          val nodes = Tesselation.nodes (!tesselation)

          fun drawnode n =
              let val (x, y) = Tesselation.N.coords n
              in Draw.drawcircle (pixels, x, y, 2, TESSELATIONNODES)
              end

          fun drawline (a, b) =
              let val (x0, y0) = Tesselation.N.coords a
                  val (x1, y1) = Tesselation.N.coords b
              in
                  Draw.drawline (pixels, x0, y0, x1, y1, TESSELATIONLINES)
              end

          fun drawtriangle t =
              let val (a, b, c) = Tesselation.T.nodes t
              in
                  drawline (a, b);
                  drawline (b, c);
                  drawline (c, a)
              end
      in
          app drawtriangle triangles;
          app drawnode nodes
      end

  fun drawobject (obj : tesselation) =

  (* Always in game pixels. The event loop scales down x,y before
     calling any of these functions. *)
  val mousex = ref 0
  val mousey = ref 0
  val holdingshift = ref false
  val holdingcontrol = ref false

  val mousedown = ref false
  val draggingnode = ref NONE : Tesselation.node option ref
  val frozennode = ref NONE : Tesselation.node option ref

  val MOUSECIRCLE = Draw.mixcolor (0wxFF, 0wxAA, 0wx33, 0wxFF)
  val CLOSESTCIRCLE = Draw.mixcolor (0wx44, 0wx44, 0wx44, 0wxFF)
  val DRAGGING = Draw.mixcolor (0wxFF, 0wxFF, 0wx00, 0wxFF)
  val FROZEN = Draw.mixcolor (0wxFF, 0wxFF, 0wxFF, 0wxFF)
  fun drawindicators () =
      let
          val (n1, n2, x, y) =
              Tesselation.closestedge (!tesselation) (!mousex, !mousey)
      in
          Draw.drawcircle (pixels, !mousex, !mousey, 5, MOUSECIRCLE);
          Draw.drawcircle (pixels, x, y, 3, CLOSESTCIRCLE);
          (case !draggingnode of
               NONE => ()
             | SOME n =>
                   let val (nx, ny) = Tesselation.N.coords n
                   in
                       Draw.drawcircle (pixels, nx, ny, 6, DRAGGING)
                   end);

          (case !frozennode of
               NONE => ()
             | SOME n =>
                   let val (nx, ny) = Tesselation.N.coords n
                   in
                       (* XXX don't always use circle *)
                       Draw.drawcircle (pixels, nx, ny, 7, FROZEN)
                   end);
          ()
      end

  val WORLDFILE = "world.tf"

  fun savetodisk () =
      WorldTF.S.tofile WORLDFILE (Tesselation.toworld (!tesselation))

  fun loadfromdisk () =
      let in
          tesselation := Tesselation.fromworld (WorldTF.S.fromfile WORLDFILE);
          eprint ("Loaded world from " ^ WORLDFILE ^ "\n")
      end
      handle Tesselation.Tesselation s =>
              eprint ("Error loading from " ^ WORLDFILE ^ ": " ^
                      s ^ "\n")
           | WorldTF.Parse s =>
              eprint ("Error parsing " ^ WORLDFILE ^ ": " ^ s ^ "\n")
           | IO.Io _ => ()

  fun mousemotion (x, y) =
      case !draggingnode of
          NONE => ()
        | SOME n => ignore (Tesselation.N.trymove n (x, y))

  fun leftmouse (x, y) =
      if !holdingcontrol
      then frozennode := Tesselation.getnodewithin (!tesselation) (x, y) 5

      else if !holdingshift
      then
          case Tesselation.splitedge (!tesselation) (x, y) of
              NONE => ()
            | SOME n => (Tesselation.check (!tesselation);
                         draggingnode := SOME n;
                         ignore (Tesselation.N.trymove n (x, y)))

      else draggingnode := Tesselation.getnodewithin (!tesselation) (x, y) 5

  fun leftmouseup (x, y) = draggingnode := NONE

  (* XXX TODO *)
  fun updatecursor () = ()

  val start = Time.now()

  fun keydown SDL.SDLK_ESCAPE =
      let in
          (* For now, always save. XXX reconsider this
             once the world becomes valuable... *)
          savetodisk();
          raise Quit
      end
    | keydown SDL.SDLK_LSHIFT =
      (holdingshift := true;
       updatecursor ())

    | keydown SDL.SDLK_LCTRL =
      (holdingcontrol := true;
       updatecursor ())

    | keydown _ = ()

  fun keyup SDL.SDLK_LSHIFT =
      (holdingshift := false;
       updatecursor ())

    | keyup SDL.SDLK_LCTRL =
      (holdingcontrol := false;
       updatecursor ())

    | keyup _ = ()

  fun events () =
      case SDL.pollevent () of
          NONE => ()
        | SOME evt =>
           case evt of
               SDL.E_Quit => raise Quit
             | SDL.E_KeyDown { sym } => keydown sym
             | SDL.E_KeyUp { sym } => keyup sym
             | SDL.E_MouseMotion { state : SDL.mousestate,
                                   x : int, y : int, ... } =>
                   let
                       val x = x div PIXELSCALE
                       val y = y div PIXELSCALE
                   in
                       mousex := x;
                       mousey := y;
                       mousemotion (x, y)
                   end
             | SDL.E_MouseDown { button = 1, x, y, ... } =>
                   let
                       val x = x div PIXELSCALE
                       val y = y div PIXELSCALE
                   in
                       leftmouse (x, y)
                   end
             | SDL.E_MouseUp { button = 1, x, y, ... } =>
                   let
                       val x = x div PIXELSCALE
                       val y = y div PIXELSCALE
                   in
                       mousedown := false;
                       leftmouseup (x, y)
                   end
             | SDL.E_MouseDown { button = 4, ... } =>
                   let in
                       eprint "scroll up"
                   end

             | SDL.E_MouseDown { button = 5, ... } =>
                   let in
                       eprint "scroll down"
                   end
             | _ => ()

  fun loop () =
      let
          val () = events ()

          val () = Draw.randomize_loud pixels
          val () = drawtesselation ()
          val () = drawindicators ()
          (* val () = Draw.scanline_postfilter pixels *)
          val () = Draw.mixpixel_postfilter 0.25 0.8 pixels
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
                  eprint (Int.toString (!ctr) ^ " (" ^
                          Real.fmt (StringCvt.FIX (SOME 2)) fps ^ ")")
              end
          else ();
          loop()
      end

  val () = loadfromdisk ()
  val () = loop ()
      handle Quit => ()
           | e =>
          let in
              (case e of
                   Tesselation.Tesselation s => eprint ("Tesselation: " ^ s)
                 | _ => ());

              app eprint (MLton.Exn.history e)
          end
end