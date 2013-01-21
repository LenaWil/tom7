
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

  structure Areas = Screen.Areas
  structure Obj = Screen.Obj

  (* TODO: This needs to become some kind of screen or world type. *)
  (* XXX: Does there only need to be one screen tesselation? Why not
     just give every object its own tesselation? *)
  (* Tesselation itself is mutable, but sometimes we want to swap the
     entire tesselation out, like in undo or save/load. *)
  val screen : Screen.screen ref = ref (Screen.starter ())
  (* val objects : Object.object list ref = ref nil *)

  (* Always in game pixels. The event loop scales down x,y before
     calling any of these functions. *)
  val mousex = ref 0
  val mousey = ref 0
  val holdingshift = ref false
  val holdingcontrol = ref false

  val mousedown = ref false
  val draggingnode = ref NONE : Areas.node option ref
  val frozennode = ref NONE : Areas.node option ref

  (* XXX should probably make it more configurable than this,
     like allow dragging a box or entering some kind of triangle
     strip clicking thing... *)
  fun addobject node =
    let
      val (x0, y0) = (Int.min(!mousex, WIDTH - 25),
                      Int.min(!mousey, WIDTH - 25))
      val (x1, y1) = (x0 + 20, y0 + 20)
    in
      eprint "Add object..";
      screen := Screen.addrectangle (!screen) node (x0, y0, x1, y1)
    end

  val MOUSECIRCLE = Draw.mixcolor (0wxFF, 0wxAA, 0wx33, 0wxFF)
  val CLOSESTCIRCLE = Draw.mixcolor (0wx44, 0wx44, 0wx44, 0wxFF)
  val DRAGGING = Draw.mixcolor (0wxFF, 0wxFF, 0wx00, 0wxFF)
  val FROZEN = Draw.mixcolor (0wxFF, 0wxFF, 0wxFF, 0wxFF)

  fun drawareaindicators () =
      let
          val s = Screen.areas (!screen)
          val (n1, n2, x, y) =
              Areas.closestedge s () (!mousex, !mousey)
      in
          Draw.drawcircle (pixels, !mousex, !mousey, 5, MOUSECIRCLE);
          Draw.drawcircle (pixels, x, y, 3, CLOSESTCIRCLE);
          (case !draggingnode of
               NONE => ()
             | SOME n =>
                   let val (nx, ny) = Areas.N.coords n ()
                   in
                       Draw.drawcircle (pixels, nx, ny, 6, DRAGGING)
                   end);

          (case !frozennode of
               NONE => ()
             | SOME n =>
                   let val (nx, ny) = Areas.N.coords n ()
                   in
                       (* XXX don't always use circle *)
                       Draw.drawcircle (pixels, nx, ny, 7, FROZEN)
                   end);
          ()
      end

  val WORLDFILE = "world.tf"

  (* XXX into Screen stuff *)
  fun savetodisk () =
      WorldTF.S.tofile WORLDFILE (Screen.toworld (!screen))

  fun loadfromdisk () =
      screen := Screen.fromworld (WorldTF.S.fromfile WORLDFILE)
      handle Screen.Screen s =>
              eprint ("Error loading " ^ WORLDFILE ^ ": " ^ s ^ "\n")
           | WorldTF.Parse s =>
              eprint ("Error parsing " ^ WORLDFILE ^ ": " ^ s ^ "\n")
           | IO.Io _ => ()

  fun mousemotion (x, y) =
      (* XXX should case on what kinda node it is..? *)
      case !draggingnode of
          NONE => ()
        | SOME n => ignore (Areas.N.trymove n () (x, y))

  fun leftmouse (x, y) =
      (* Only areas nodes. *)
      if !holdingcontrol
      then frozennode := Areas.getnodewithin (Screen.areas (!screen)) () (x, y) 5

      (* XXX allow splitting and dragging objects *)
      else if !holdingshift
      then
          case Areas.splitedge (Screen.areas (!screen)) () (x, y) of
              NONE => ()
            | SOME n => ((* Tesselation.check (!tesselation); *)
                         draggingnode := SOME n;
                         ignore (Areas.N.trymove n () (x, y)))

      else draggingnode := Areas.getnodewithin (Screen.areas (!screen)) () (x, y) 5

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

    (* Need much better keys... *)
    | keydown SDL.SDLK_o =
      (case !frozennode of
         NONE => eprint "Freeze a node with ctrl-click first."
       | SOME node => addobject node)

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
          val () = Render.drawareas (pixels, Screen.areas (!screen))
          val () = Render.drawobjects (pixels, !screen)
          val () = drawareaindicators ()
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
                   Screen.Screen s => eprint ("Screen: " ^ s)
                 | _ => ());

              app eprint (MLton.Exn.history e)
          end
end