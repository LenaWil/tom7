structure Render (* :> XX RENDER *) =
struct

  open Constants

  val TESSELATIONLINES = Draw.mixcolor (0wx44, 0wx44, 0wx55, 0wxFF)
  val TESSELATIONNODES = Draw.mixcolor (0wx66, 0wx66, 0wx77, 0wxFF)
  val TESSELATIONSEGMENT = Vector.fromList [TESSELATIONLINES, 0w0]

  val rc = ARCFOUR.initstring "render"
  fun byte () = ARCFOUR.byte rc
  fun byte32 () = Word32.fromInt (Word8.toInt (byte ()))

  structure Areas = Screen.Areas
  structure Obj = Screen.Obj

  structure AEM = Areas.EM
  fun drawareas (pixels, s : Screen.areas) =
    let
      val triangles = Areas.triangles s
      val nodes = Areas.nodes s

      (* Edges can appear in two triangles. Don't draw them twice. *)
      val drawn : unit AEM.map ref = ref AEM.empty

      fun drawnode n =
          let val (x, y) = Areas.N.coords n ()
          in Draw.drawcircle (pixels, x, y, 2, TESSELATIONNODES)
          end

      fun drawline (a, b) =
          case AEM.find (!drawn, (a, b)) of
              SOME () => ()
            | NONE =>
          let val (x0, y0) = Areas.N.coords a ()
              val (x1, y1) = Areas.N.coords b ()
          in
              Draw.drawlinewith (pixels, x0, y0, x1, y1, TESSELATIONSEGMENT);
              drawn := AEM.insert (!drawn, (a, b), ())
          end

      fun drawtriangle t =
          let val (a, b, c) = Areas.T.nodes t
          in
              drawline (a, b);
              drawline (b, c);
              drawline (c, a)
          end
    in
      app drawtriangle triangles;
      app drawnode nodes
    end

  fun filltriangle (pixels, (a, b, c), color) =
    let val { x0, y0, x1, y1 } = IntMaths.trianglebounds (a, b, c)
      (* XXX bound to screen. *)
    in
      (* PERF. There are obviously much faster ways to do this
         known to mankind since 0 AD. *)
      Util.for y0 y1
      (fn y =>
       Util.for x0 x1
       (fn x =>
        if IntMaths.pointinside (a, b, c) (x, y)
        then Array.update (pixels, y * WIDTH + x, color)
        else ()))
    end

  fun drawareacolors (pixels, s : Screen.areas) =
    let
      fun drawtriangle t =
          let
            val (a, b, c) = Areas.T.nodes t
            val a = Areas.N.coords a ()
            val b = Areas.N.coords b ()
            val c = Areas.N.coords c ()
          in
            filltriangle (pixels,
                          (a, b, c),
                          Draw.mixcolor (byte32 (), byte32 (), byte32 (),
                                         0wxFF))
          end
    in
      app drawtriangle (Areas.triangles s)
    end

  (* XXX it makes sense to have a large set of colors for different
     configurations, especially *)
  val OBJECTLINES = Draw.mixcolor (0wx44, 0wx44, 0wx55, 0wxFF)
  val ACTIVEOBJECTLINES = Draw.mixcolor (0wxAA, 0wxAA, 0wxAA, 0wxFF)

  val OBJECTNODES = Draw.mixcolor (0wx66, 0wx66, 0wx77, 0wxFF)


  val LINKLINES = Draw.mixcolor (0wx44, 0wx11, 0wx11, 0wxFF)
  val LINKSEGMENT = Vector.fromList [LINKLINES, 0w0, 0w0]

  val ACTIVELINKLINES = Draw.mixcolor (0wx88, 0wx22, 0wx22, 0wxFF)
  val ACTIVELINKSEGMENT = Vector.fromList [ACTIVELINKLINES, LINKLINES, 0w0]

  (* Draw an object in all its configurations.

     We draw a tenuous line from each configured node of the object to
     the node that is associated with that configuration. *)
  structure OEM = Obj.EM
  fun drawobjectall (pixels, screen : Screen.screen,
                     frozen : Areas.node option, obj : Screen.obj) : unit =
    let
      val triangles = Obj.triangles obj
      val nodes = Obj.nodes obj
      val keys = Obj.keys obj

      fun isfrozen k =
        case frozen of
          NONE => false
        | SOME kk => EQUAL = Areas.N.compare (k, kk)

      (* Edges can appear in two triangles. Don't draw them twice. *)
      val drawn : unit OEM.map ref = ref OEM.empty

      fun drawnode n =
        app (fn k =>
             let val (x, y) = Obj.N.coords n k
                 (* So that we can draw a line to the configuring node
                    in the areas *)
                 val (cx, cy) = Areas.N.coords k ()

                 val linksegment =
                   if isfrozen k
                   then ACTIVELINKSEGMENT
                   else LINKSEGMENT
             in
                 Draw.drawlinewith (pixels, cx, cy, x, y, linksegment);
                 Draw.drawcircle (pixels, x, y, 2, OBJECTNODES)
             end) keys

      (* XXX should draw frozen key last, because otherwise we may
         draw dim lines over it. *)
      fun drawline (a, b) =
        case OEM.find (!drawn, (a, b)) of
            SOME () => ()
          | NONE =>
            let in
              drawn := OEM.insert (!drawn, (a, b), ());
              (app (fn k =>
                    let val (x0, y0) = Obj.N.coords a k
                        val (x1, y1) = Obj.N.coords b k
                        val objectlines =
                          if isfrozen k
                          then ACTIVEOBJECTLINES
                          else OBJECTLINES
                    in
                        Draw.drawline (pixels, x0, y0, x1, y1, objectlines)
                    end) keys)
            end

      fun drawtriangle t =
        let val (a, b, c) = Obj.T.nodes t
        in
            drawline (a, b);
            drawline (b, c);
            drawline (c, a)
        end

    in
        app drawtriangle triangles;
        app drawnode nodes
    end

  (* XXX allow one to be the focus. Draw in different colors, etc. *)
  fun drawobjects (pixels, screen as { areas, objs }, frozen) =
    let
      fun oneobject obj = drawobjectall (pixels, screen, frozen, obj)
    in
      app oneobject objs
    end

end
