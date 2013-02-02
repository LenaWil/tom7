
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


  val worldx = ref 4
  val worldy = ref 4

  (* If this fails, we start with an empty everything. *)
  val () = World.load ()

  (* Current screen at worldx,worldy. *)
  (* This ref is just for the benefit of the editor; modify the screen
     itself to make changes to the world. *)
  val screen : Screen.screen ref =
    ref (World.getorcreate (!worldx, !worldy))

  fun warptoscreen (x, y) =
    let in
      worldx := x;
      worldy := y;
      screen := World.getorcreate (x, y)
    end

  (* val objects : Object.object list ref = ref nil *)

  (* Always in game pixels. The event loop scales down x,y before
     calling any of these functions. *)
  val mousex = ref 0
  val mousey = ref 0
  (* XXX: Should probably be a mask on all keys. *)
  val holdingshift = ref false
  val holdingcontrol = ref false
  val holdingspace = ref false
  val holdingbackslash = ref false
  val holdingtab = ref false

  val mousedown = ref false

  datatype anynode =
      AreasNode of Areas.node
    | ObjNode of Screen.obj * Obj.node

  val draggingnode = ref NONE : anynode option ref
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
      screen := World.setscreen
      (!worldx, !worldy, Screen.addrectangle (!screen) node (x0, y0, x1, y1))
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
  val FLIPOLDLINE = Draw.mixcolor (0wx11, 0wx22, 0wx77, 0wxFF)
  val FLIPNEWLINE = Draw.mixcolor (0wx22, 0wx55, 0wxAA, 0wxFF)

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

  fun closestobjectedgewithin (x, y) key dist =
    case Screen.closestobjectedge (Screen.objs (!screen)) key (x, y) of
      NONE => NONE
    | SOME (obj, n1, n2, nx, ny) =>
      if IntMaths.distance_squared ((x, y), (nx, ny)) <= (dist * dist)
      then SOME (obj, n1, n2, nx, ny)
      else NONE

  datatype decoration =
    (* x, y, radius, color *)
      Circle of int * int * int * Word32.word
    (* color, x, y, text *)
    | Text of Word32.word * int * int * string
    | Line of Word32.word * (int * int) * (int * int)

  fun drawdecoration (Circle (x, y, r, c)) =
    Draw.drawcircle (pixels, x, y, r, c)
    | drawdecoration (Text (c, x, y, s)) =
    Draw.drawtextcolor (pixels, Font.pxfont, c, x, y, s)
    | drawdecoration (Line (c, (x0, y0), (x1, y1))) =
    Draw.drawline (pixels, x0, y0, x1, y1, c)

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
              (SOME n, SOME nn) => if Areas.N.eq (n, nn)
                                   then ([], ignore)
                                   else disequal (SOME n, SOME nn)
            | (NONE, NONE) => ([], ignore)
            | (old, new) => disequal (old, new)
        end

      else if !holdingshift
      then
        (* XXX do we really need this prohibition against shift-clickin'
           when there's a drag node nearby? maybe it should just suppress
           the message? *)
        case !frozennode of
          SOME key =>
            (case (Screen.objectclosestnodewithin
                   (Screen.objs (!screen)) key (x, y) 5,
                   closestobjectedgewithin (x, y) key SPLIT_DISTANCE) of
               (NONE, SOME (obj, _, _, x, y)) =>
                 let
                   fun split () =
                     case Obj.splitedge obj key (x, y) of
                       NONE => ()
                     | SOME n =>
                         let in
                           draggingnode := SOME (ObjNode (obj, n));
                           ignore (Obj.trymovenode obj n key (x, y))
                         end
                 in
                   ([Circle (x, y, 3, CLOSESTCIRCLE),
                     Text (ACTIONTEXTHI, x - 13, y - 11, "add")],
                    split)
                 end
             | _ => ([], ignore))

        | NONE =>
          case (Areas.getnodewithin (Screen.areas (!screen)) ()
                (!mousex, !mousey) DRAG_DISTANCE,
                closestedgewithin SPLIT_DISTANCE) of
            (NONE, SOME (_, _, x, y)) =>
              let
                fun split () =
                  case Areas.splitedge (Screen.areas (!screen)) () (x, y) of
                    NONE => ()
                  | SOME n =>
                      let in
                        draggingnode := SOME (AreasNode n);
                        ignore (Areas.trymovenode (Screen.areas (!screen)) n () (x, y))
                      end
              in
                ([Circle (x, y, 3, CLOSESTCIRCLE),
                  Text (ACTIONTEXTHI, x - 13, y - 11, "add")],
                 split)
              end
          | _ => ([], ignore)

      else if !holdingbackslash
      then
        (* Allows flipping a tesselation edge. *)
        case !frozennode of
          SOME key => (eprint "Flipping object edges unimplemented"; ([], ignore))
        | NONE =>
            (case Areas.closestflipedge (Screen.areas (!screen)) () (x, y) of
               NONE => ([], ignore)
             | SOME ((n1, n2), (cx, cy), (n3, n4)) =>
               let
                 val (x1, y1) = Areas.N.coords n1 ()
                 val (x2, y2) = Areas.N.coords n2 ()
                 val (x3, y3) = Areas.N.coords n3 ()
                 val (x4, y4) = Areas.N.coords n4 ()
               in
                 ([Text (ACTIONTEXTHI, x - 13, y - 11, "flip"),
                   Line (FLIPOLDLINE, (x1, y1), (x2, y2)),
                   Line (FLIPNEWLINE, (x3, y3), (x4, y4))],
                  (* XXX *)
                  (fn () =>
                   if Areas.flipedge (Screen.areas (!screen)) () (x, y)
                   then ()
                   else eprint "Failed to flip"))
               end)

      else
        (* No modifiers. *)

        (* We drag object nodes if an areas node is frozen. Otherwise we
           drag areas nodes. *)
        case !frozennode of
          SOME key =>
            (case Screen.objectclosestnodewithin
                  (Screen.objs (!screen)) key (x, y) 5 of
               NONE => ([], ignore)
             | SOME (obj, node) =>
                 ([Text (ACTIONTEXTHI, x - 13, y - 11, "drag")],
                  fn () => draggingnode := SOME (ObjNode (obj, node))))

        | NONE =>
            (case Areas.getnodewithin (Screen.areas (!screen)) () (x, y) 5 of
               NONE => ([], ignore)
             | SOME node => ([Text (ACTIONTEXTHI, x - 13, y - 11, "drag")],
                              fn () => draggingnode := SOME (AreasNode node)))

  val INSIDE = Draw.hexcolor 0wxFFEEFF

  (* Draw the objects as though the player is at (x, y).

     Find what area we're in, from Areas.
     If the object has keys for all its three triangles, then
     compute the interpolated position.

     TODO: Figure out what to do if the object doesn't have keys.
     Currently we just don't draw it, but there are multiple options
     that would make sense... *)
  fun drawinterpolatedobjects (x, y) =
    case Areas.gettriangle (Screen.areas (!screen)) (x, y) of
      NONE => ()
    | SOME ((), triangle) =>
      let
        val (a, b, c) = Areas.T.nodes triangle

        fun marknode n =
          let val (nx, ny) = Areas.N.coords n ()
          in Draw.drawcircle (pixels, nx, ny, 1, INSIDE)
          end

        (* Convert to barycentric coordinates. This basically gives a weight
           for each vertex of the triangle. Since we're inside the triangle,
           these will all be in [0.0, 1.0] and sum to 1.0. *)
        val (la, lb, lc) =
          IntMaths.barycentric (Areas.N.coords a (),
                                Areas.N.coords b (),
                                Areas.N.coords c (),
                                (x, y))

        fun oneobj obj =
          if Obj.iskey obj a andalso
             Obj.iskey obj b andalso
             Obj.iskey obj c
          then
            let

              (* Edges can appear in two triangles. Don't draw them twice. *)
              val drawn : unit Obj.EM.map ref = ref Obj.EM.empty

              (* Get the coordinates for the node by interpolating
                 between the three keys. *)
              fun transform n =
                let
                  (* These shouldn't fail because we checked that the
                     key is a key of the object above. *)
                  val (ax, ay) = Obj.N.coords n a
                  val (bx, by) = Obj.N.coords n b
                  val (cx, cy) = Obj.N.coords n c

                  val nx = Real.round (real ax * la + real bx * lb + real cx * lc)
                  val ny = Real.round (real ay * la + real by * lb + real cy * lc)
                in
                  (nx, ny)
                end

              fun drawline (d, e) =
                case Obj.EM.find (!drawn, (d, e)) of
                  SOME () => ()
                | NONE =>
                    let
                      val (x0, y0) = transform d
                      val (x1, y1) = transform e
                    in
                      drawn := Obj.EM.insert (!drawn, (d, e), ());
                      Draw.drawline (pixels, x0, y0, x1, y1, INSIDE)
                    end

              fun drawtriangle t =
                let val (d, e, f) = Obj.T.nodes t
                in
                  drawline (d, e);
                  drawline (e, f);
                  drawline (f, d)
                end

            in
              app drawtriangle (Obj.triangles obj)
            end
          else ()

      in
        marknode a;
        marknode b;
        marknode c;
        app oneobj (Screen.objs (!screen))
      end

  (* XXX wrong name / organization *)
  fun drawareaindicators () =
    let in
      if Option.isSome (!draggingnode)
      then Draw.drawcircle (pixels, !mousex, !mousey, 5, MOUSECIRCLE)
      else ();

      if !mousedown
      then ()
      else let val (decorations, _) = get_lmb_actions (!mousex, !mousey)
           in app drawdecoration decorations
           end;

      (* XXX probably only when holding some key *)
      if !holdingspace
      then drawinterpolatedobjects (!mousex, !mousey)
      else ();

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

  fun savetodisk () = World.save ()

  fun loadfromdisk () =
    let in
      World.load ();
      screen := World.getorcreate (!worldx, !worldy)
    end

  fun mousemotion (x, y) =
    (* XXX should case on what kinda node it is..? *)
    case !draggingnode of
      NONE => ()
    | SOME (AreasNode n) =>
        ignore (Areas.trymovenode (Screen.areas (!screen)) n () (x, y))
    | SOME (ObjNode (obj, n)) =>
        (case !frozennode of
           NONE => eprint "Can't move object node without frozen node"
         | SOME key => ignore (Obj.trymovenode obj n key (x, y)))

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

  fun dirkey (dx, dy) =
    if !holdingtab
    then
      let
        val nx = !worldx + dx
        val ny = !worldy + dy
      in
        if nx >= 0 andalso ny >= 0 andalso
           nx < WORLD_WIDTH andalso ny < WORLD_HEIGHT
        then warptoscreen (nx, ny)
        else eprint "can't go outside the map"
      end
    else ()

  fun keydown SDL.SDLK_ESCAPE =
    let in
      (* For now, always save. XXX reconsider this
         once the world becomes valuable... *)
      savetodisk();
      raise Quit
    end

    | keydown SDL.SDLK_SPACE =
      (holdingspace := true;
       updatecursor ())

    | keydown SDL.SDLK_LSHIFT =
      (holdingshift := true;
       updatecursor ())

    | keydown SDL.SDLK_LCTRL =
      (holdingcontrol := true;
       updatecursor ())

    | keydown SDL.SDLK_BACKSLASH =
      (holdingbackslash := true;
       updatecursor ())

    | keydown SDL.SDLK_TAB =
      (holdingtab := true;
       updatecursor())

    | keydown SDL.SDLK_UP = dirkey (0, ~1)
    | keydown SDL.SDLK_DOWN = dirkey (0, 1)
    | keydown SDL.SDLK_LEFT = dirkey (~1, 0)
    | keydown SDL.SDLK_RIGHT = dirkey (1, 0)

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

    | keyup SDL.SDLK_SPACE =
      (holdingspace := false;
       updatecursor ())

    | keyup SDL.SDLK_BACKSLASH =
      (holdingbackslash := false;
       updatecursor ())

    | keyup SDL.SDLK_TAB =
      (holdingtab := false;
       updatecursor())

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

  val TESSELATIONLINES = Draw.mixcolor (0wx44, 0wx44, 0wx55, 0wxFF)
  val TESSELATIONSEGMENT = Vector.fromList [TESSELATIONLINES, 0w0]

  val TESSELATIONLINESLOW = Draw.mixcolor (0wx2A, 0wx2A, 0wx3B, 0wxFF)
  val TESSELATIONSEGMENTLOW = Vector.fromList [TESSELATIONLINESLOW, 0w0, 0w0]

  fun loop () =
    let
      val () = events ()

      val () = Draw.randomize_loud pixels
      val () = Render.drawareacolors (pixels, Screen.areas (!screen))

      (* val () = eprint "areas" *)
      val () = Render.drawareas (pixels, Screen.areas (!screen),
                                 case !frozennode of
                                   NONE => TESSELATIONSEGMENT
                                 | SOME _ => TESSELATIONSEGMENTLOW)

      val drawobjects = true
      (* Don't draw objects if we're drawing the interpolated ones. *)
      val drawobjects = if !holdingspace
                        then false
                        else drawobjects

      (* Don't draw objects if we're flipping edges in the areas tesselation. *)
      val drawobjects = if !holdingbackslash andalso
                           not (Option.isSome (!frozennode))
                        then false
                        else drawobjects

      (* val () = eprint "objects" *)
      val () =
        if drawobjects
        then Render.drawobjects (pixels, !screen, !frozennode)
        else ()

      (* val () = eprint "indicators" *)
      val () = drawareaindicators ()

      (* Show map? *)
      val () =
        if !holdingtab
        then
          let in
            Draw.darken pixels;
            Render.drawmap (pixels, !worldx, !worldy)
          end
        else ()

      (* test... *)
      val () = Draw.blit { dest = (WIDTH, HEIGHT, pixels),
                           src = Images.tinymouse,
                           srcrect = NONE,
                           dstx = !mousex,
                           dsty = !mousey }

      val () = Draw.noise_postfilter pixels
      (* val () = Draw.scanline_postfilter pixels *)
      (* val () = Draw.mixpixel_postfilter 0.25 0.8 pixels *)
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

  val () = SDL.show_cursor false
  val () = loop ()
      handle Quit => ()
           | e =>
          let in
            (case e of
               Screen.Screen s => eprint ("Screen: " ^ s)
             | World.World s => eprint ("World: " ^ s)
             | Constants.Impossible s => eprint ("Impossible: " ^ s)
             | _ => ());

            app eprint (MLton.Exn.history e)
          end
end