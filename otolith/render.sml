structure Render (* :> XX RENDER *) =
struct

  open Constants

  val TESSELATIONNODES = Draw.mixcolor (0wx66, 0wx66, 0wx77, 0wxFF)

  val rc = ARCFOUR.initstring "render"
  fun byte () = ARCFOUR.byte rc
  fun byte32 () = Word32.fromInt (Word8.toInt (byte ()))

  structure Areas = Screen.Areas
  structure Obj = Screen.Obj

  structure AEM = Areas.EM
  fun drawareas (pixels, s : Screen.areas, segment) =
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
              Draw.drawlinewith (pixels, x0, y0, x1, y1, segment);
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

  val areacolors = Vector.fromList
    [Draw.hexcolor 0wx21917b,
     Draw.hexcolor 0wx217be6,
     Draw.hexcolor 0wx217b2d,
     Draw.hexcolor 0wx7b7921,
     Draw.hexcolor 0wx7ba121,
     Draw.hexcolor 0wx7b2121,
     Draw.hexcolor 0wx7b21b1]

  fun drawareacolors (pixels, s : Screen.areas) =
    let
      val r = ref 0
      fun drawtriangle t =
        let
          val (a, b, c) = Areas.T.nodes t
          val a = Areas.N.coords a ()
          val b = Areas.N.coords b ()
          val c = Areas.N.coords c ()
        in
          filltriangle (pixels,
                        (a, b, c),
                        Vector.sub (areacolors, !r));
          r := (!r + 1) mod Vector.length areacolors
        end
    in
      app drawtriangle (Areas.triangles s)
    end


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
                     frozen : Areas.node option, obj : Screen.obj,
                     color) : unit =
    let
      (* Mix 50% with black to darken. *)
      val darkcolor = Draw.blendtwocolors (Draw.hexcolor 0w0, color)
      (* If something is frozen, then increase contrast even more. *)
      val darkcolor =
        case frozen of
          NONE => darkcolor
        | SOME _ => Draw.blendtwocolors (Draw.hexcolor 0w0, darkcolor)

      val triangles = Obj.triangles obj
      val nodes = Obj.nodes obj
      val keys = Obj.keys obj

      (* Put frozen key last (if any) so bright lines draw on top *)
      val keys =
        case frozen of
          NONE => keys
        | SOME k =>
            (if Obj.iskey obj k
             then
               List.filter (fn kk => not (Areas.N.eq (k, kk))) keys @
               [k]
             else keys)

      fun isfrozen k =
        case frozen of
          NONE => false
        | SOME kk => Areas.N.eq (k, kk)

      (* Edges can appear in two triangles. Don't draw them twice. *)
      val drawn : unit OEM.map ref = ref OEM.empty

      fun drawnode n =
        app (fn k =>
             let
               val (x, y) = Obj.N.coords n k
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

      fun drawline (a, b) =
        case OEM.find (!drawn, (a, b)) of
          SOME () => ()
        | NONE =>
          let in
            drawn := OEM.insert (!drawn, (a, b), ());

            app (fn k =>
                  let
                    val (x0, y0) = Obj.N.coords a k
                    val (x1, y1) = Obj.N.coords b k
                    val objectlines =
                      if isfrozen k
                      then color
                      else darkcolor
                  in
                    Draw.drawline (pixels, x0, y0, x1, y1, objectlines)
                  end) keys
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
  val objectcolors = Vector.fromList
    [Draw.hexcolor 0wx5191fb,
     Draw.hexcolor 0wx51fbe6,
     Draw.hexcolor 0wx51fb5d,
     Draw.hexcolor 0wxfbf951,
     Draw.hexcolor 0wxfba151,
     Draw.hexcolor 0wxfb5151,
     Draw.hexcolor 0wxfb51b1]

  fun drawobjects (pixels, screen as { areas, objs }, frozen) =
    let
      fun oneobject (obj, i) =
        drawobjectall (pixels, screen, frozen, obj,
                       Vector.sub (objectcolors, i mod Vector.length objectcolors))
    in
      ListUtil.appi oneobject objs
    end

end
