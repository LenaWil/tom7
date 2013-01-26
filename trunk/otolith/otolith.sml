
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

  val DRAG_DISTANCE = 5
  val SPLIT_DISTANCE = 5

  (* Link an object to the frozen node. Adds this node as a key,
     setting the positions "smartly" (right now they are just copied
     from the first key). *)
  fun linkobject (node : Areas.node) =
    case Screen.objectswithin (Screen.objs (!screen))
                              (!mousex, !mousey) of
      nil => eprint "press when mouse is near an object to link."
    | (obj : Screen.obj, key) :: _ =>
        if Obj.iskey obj node
        then eprint "already linked to this object"
        else
          let
            fun newcoords (onode : Obj.node) =
              let val (x, y) = Obj.N.coords onode key
              in (x, y)
              end
          in
            Obj.addkey obj newcoords (node : Obj.key)
          end

  val MOUSECIRCLE = Draw.mixcolor (0wxFF, 0wxAA, 0wx33, 0wxFF)
  val CLOSESTCIRCLE = Draw.mixcolor (0wx44, 0wx44, 0wx44, 0wxFF)
  val DRAGGING = Draw.mixcolor (0wxFF, 0wxFF, 0wx00, 0wxFF)
  val FROZEN = Draw.mixcolor (0wxFF, 0wxFF, 0wxFF, 0wxFF)

  val ACTIONTEXT = Draw.mixcolor (0wx44, 0wx66, 0wx22, 0wxFF)
  val ACTIONTEXTHI = Draw.mixcolor (0wx55, 0wxAA, 0wx22, 0wxFF)

  fun closestedgewithin n =
    let
      val nsq = n * n
      val (n1, n2, x, y) =
        Areas.closestedge (Screen.areas (!screen)) () (!mousex, !mousey)
    in
      if IntMaths.distance_squared ((!mousex, !mousey), (x, y)) <= nsq
      then SOME (n1, n2, x, y)
      else NONE
    end

  datatype decoration =
    (* x, y, radius, color *)
      Circle of int * int * int * Word32.word
    (* color, x, y, text *)
    | Text of Word32.word * int * int * string

  fun drawdecoration (Circle (x, y, r, c)) =
    Draw.drawcircle (pixels, x, y, r, c)
    | drawdecoration (Text (c, x, y, s)) =
    Draw.drawtextcolor (pixels, Font.pxfont, c, x, y, s)

  (* Returns the actions that are possible based on the current
     mouse position and state. The actions can either be taken (by
     running the function) or drawn (by interpreting the data structure). *)
  fun get_lmb_actions (x, y) =
    (* If we're holding control, then the only thing we can do is
       freeze/unfreeze areas nodes. *)
    if !holdingcontrol
    then
        let
          fun disequal (old, new) =
            let
              val ot = case old of
                SOME n => let val (x, y) = Areas.N.coords n ()
                          in [Text (ACTIONTEXTHI, x - 18, y - 14, "Unfreeze")]
                          end
              | NONE => []
              val nt = case new of
                SOME n => let val (x, y) = Areas.N.coords n ()
                          in [Text (ACTIONTEXTHI, x - 18, y - 11, "Freeze")]
                          end
              | NONE => []
            in
              (ot @ nt, (fn () => frozennode := new))
            end
        in
          case (!frozennode,
                Areas.getnodewithin
                (Screen.areas (!screen)) () (x, y) 5) of
              (SOME n, SOME nn) => if EQUAL = Areas.N.compare (n, nn)
                                   then ([], ignore)
                                   else disequal (SOME n, SOME nn)
            | (NONE, NONE) => ([], ignore)
            | (old, new) => disequal (old, new)
        end

      else if !holdingshift
      then
        case !frozennode of
          SOME key => ([], ignore) (* XXX allow splitting and dragging objects too. *)
        | NONE =>
          case (Areas.getnodewithin (Screen.areas (!screen)) ()
                (!mousex, !mousey) DRAG_DISTANCE,
                closestedgewithin SPLIT_DISTANCE) of
            (NONE, SOME (_, _, x, y)) =>
              let
                fun split () =
                  (if Option.isSome (closestedgewithin SPLIT_DISTANCE)
                   then
                     case Areas.splitedge (Screen.areas (!screen)) () (x, y) of
                       NONE => ()
                     | SOME n =>
                         let in
                           draggingnode := SOME n;
                           ignore (Areas.N.trymove n () (x, y))
                         end
                   else ())
              in
                ([Circle (x, y, 3, CLOSESTCIRCLE),
                  Text (ACTIONTEXTHI, x - 13, y - 11, "add")],
                 split)
              end
          | _ => ([], ignore)

      else
        (* No modifiers. *)

        case !frozennode of
          (* XXX TODO: drag object nodes if frozen. *)
          SOME key => ([], ignore)
        | NONE =>
            (case Areas.getnodewithin (Screen.areas (!screen)) () (x, y) 5 of
               NONE => ([], ignore)
             | SOME node => ([Text (ACTIONTEXTHI, x - 13, y - 11, "drag")],
                              fn () => draggingnode := SOME node))

  (* XXX wrong name / organization *)
  fun drawareaindicators () =
    let

    in
      if Option.isSome (!draggingnode)
      then Draw.drawcircle (pixels, !mousex, !mousey, 5, MOUSECIRCLE)
      else ();

      if !mousedown
      then ()
      else let val (decorations, _) = get_lmb_actions (!mousex, !mousey)
           in app drawdecoration decorations
           end;

      (*
      (case !draggingnode of
           NONE => ()
         | SOME n =>
               let val (nx, ny) = Areas.N.coords n ()
               in
                   Draw.drawcircle (pixels, nx, ny, 6, DRAGGING)
               end);
      *)

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

  (* The work is done by get_lmb_actions so that the indicators
     and actions are in sync. Here we just apply the action function. *)
  fun leftmouse (x, y) =
    let val (_, action) = get_lmb_actions (x, y)
    in action ()
    end

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

    | keydown SDL.SDLK_l =
      (case !frozennode of
         NONE => eprint "Freeze a node with ctrl-click first."
       | SOME node => linkobject node)

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
          (* val () = Render.drawareacolors (pixels, Screen.areas (!screen)) *)
          val () = Render.drawareas (pixels, Screen.areas (!screen))
          val () = Render.drawobjects (pixels, !screen, !frozennode)
          val () = drawareaindicators ()

          (* test... *)
          val () = Draw.blit { dest = (WIDTH, HEIGHT, pixels),
                               src = Images.tinymouse,
                               srcrect = NONE,
                               dstx = !mousex,
                               dsty = !mousey }

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
  val () = SDL.show_cursor false
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