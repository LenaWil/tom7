
structure BDDTest =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:

  structure U = Util
  open SDL
  structure Util = U

  val WIDTH = 800
  val HEIGHT = 600
  val screen = makescreen (WIDTH, HEIGHT)

  val METERS_PER_PIXEL = 0.01
  fun tometers d = real d * METERS_PER_PIXEL
  fun toworld (xp, yp) =
      let
          val xp = xp - 400
          val yp = yp - 300
      in
          (tometers xp, tometers yp)
      end

     
  (* Put the origin of the world at WIDTH / 2, HEIGHT / 2.
     make the viewport show 8 meters by 6. *)
  val PIXELS_PER_METER = 100
  fun topixels d = d * real PIXELS_PER_METER
  fun toscreen (xm, ym) =
      let
          val xp = topixels xm
          val yp = topixels ym
      in
          (Real.round xp + 400,
           Real.round yp + 300)
      end

  fun vectoscreen v = toscreen (vec2xy v)
  fun screentovec (x, y) = vec2 (toworld (x, y))

  val circle = { radius = 0.3,
                 p = vec2 (1.0, 0.3) }

  val polygon = BDDPolygon.polygon 
      (map screentovec (rev [(225, 280),
                             (295, 124),
                             (185, 36),
                             (136, 51),
                             (116, 330)]))

  (* roughly centered around screen origin *)
  val familiar = BDDPolygon.polygon
      (map screentovec (rev [(377, 268),
                             (386, 321),
                             (418, 329),
                             (428, 305)]))

  val frot = ref 0.0

  val mousex = ref 0
  val mousey = ref 0

  val savex = ref 0
  val savey = ref 0

  exception Done

  val rightmouse = ref false

  fun key () =
      case pollevent () of
          NONE => ()
        | SOME evt =>
           case evt of
               E_KeyDown { sym = SDLK_ESCAPE } => raise Done
             | E_MouseMotion { state : mousestate, x : int, y : int, ... } =>
                   let in 
                       mousex := x;
                       mousey := y
                   end
             | E_MouseDown { button = 1, x, y, ... } =>
                   let in
                       savex := x;
                       savey := y
                   end

             (* right mouse *)
             | E_MouseDown { button = 3, ... } =>
                   rightmouse := true
             | E_MouseUp { button = 3, ... } => 
                   rightmouse := false
             | _ => ()

  fun drawcircle () =
      let
          (* drawcircle surf x y radius color
             draws a circle (not filled)
             *)
          val (x, y) = toscreen (vec2xy (#p circle))
          val r = Real.round (topixels (#radius circle))
      in
          SDL.drawcircle (screen,
                          x, y, r,
                          color (0w255, 0w255, 0w255, 0w255))
      end

  fun drawpolygonat (xf, polygon) =
      let
          val num = Array.length (#vertices polygon)
          val c = color (0w255, 0w255, 0w255, 0w200)

          val { center, ... } = BDDPolygon.compute_mass (polygon, 1.0)
          val (cx, cy) = vectoscreen (xf @*: center)
      in
          Util.for 0 (num - 1)
          (fn i =>
           let val i2 = if i = num - 1
                        then 0
                        else i + 1
               val (x, y) = vectoscreen (xf @*: Array.sub(#vertices polygon, i))
               val (xx, yy) = vectoscreen (xf @*: Array.sub(#vertices polygon, i2))
           in
               SDL.drawline (screen, x, y, xx, yy, c)
           end);

          SDL.drawcircle (screen, cx, cy, 2, c)
      end

  fun drawpolygon polygon =
      drawpolygonat (BDDMath.identity_transform (), polygon)

  fun drawfamiliar () =
      let
          val pt = vec2 (toworld (!mousex, !mousey))
          val xf = BDDMath.transform_pos_angle (pt, !frot)
      in
          drawpolygonat (xf, familiar)
      end

  (* closest points between familiar and other objects *)
  val shapes = [BDDShape.Circle circle,
                BDDShape.Polygon polygon]
  val distance_proxies = map (fn s =>
                              (BDDDistance.shape_proxy s,
                               BDDDistance.initial_cache ())) shapes
  fun drawdists () =
      let
          val fidentity = BDDMath.identity_transform ()
          val pt = vec2 (toworld (!mousex, !mousey))
          val ffam = BDDMath.transform_pos_angle (pt, !frot)

          val fprox = BDDDistance.shape_proxy (BDDShape.Polygon familiar)

          val c = color (0w128, 0w0, 0w64, 0w255)
          val cc = color (0w255, 0w0, 0w128, 0w255)
                      
          fun one (proxy, cache) =
              let
                  (* XXX try keeping this around *)
                  (* val cache = BDDDistance.initial_cache () *)
                  val { pointa, pointb, iterations, ... } =
                      BDDDistance.distance ({ proxya = fprox,
                                              proxyb = proxy,
                                              transforma = ffam,
                                              transformb = fidentity,
                                              use_radii = true },
                                            cache)
                  val (ax, ay) = vectoscreen pointa
                  val (bx, by) = vectoscreen pointb
              in
                  print (Int.toString iterations ^ "\n");
                  SDL.drawline (screen, ax, ay, bx, by, c);
                  SDL.drawcircle (screen, ax, ay, 2, c);
                  SDL.drawcircle (screen, bx, by, 2, c)
              end
      in
          app one distance_proxies
      end

  fun drawmouse () =
      let
          val xf = BDDMath.identity_transform ()
          val pt = vec2 (toworld (!mousex, !mousey))
              
          (* Colliding? *)
          (* XXX use shapes list *)
          val c = 
              if BDDCircle.test_point (circle, xf, pt) orelse
                 BDDPolygon.test_point (polygon, xf, pt)
              then color (0w255, 0w255, 0w0, 0w0)
              else color (0w255, 0w0, 0w255, 0w0)

          val (x, y) = vectoscreen pt

          val p1 = vec2 (toworld (!savex, !savey))
          val p2 = vec2 (toworld (!mousex, !mousey))
          val input = { p1 = vec2 (toworld (!savex, !savey)),
                        p2 = vec2 (toworld (!mousex, !mousey)),
                        max_fraction = 1.0 }

          (* XXX should use shapes list *)
          (* Collide against everything. *)
          val collisions =
              List.mapPartial (fn x => x)
              [BDDCircle.ray_cast (circle, xf, input),
               BDDPolygon.ray_cast (polygon, xf, input)]

          (* Take the closest collision. *)
          val collisions = ListUtil.sort
              (fn ({ fraction = f, ... }, { fraction = ff, ... }) =>
               Real.compare (f, ff)) collisions
      in
          (* Ray *)
          (case collisions of
               nil => SDL.drawline (screen, x, y, !savex, !savey,
                                     color (0w255, 0w0, 0w0, 0w255))
             | { normal, fraction } :: _ => 
                   let
                       val d = p2 :-: p1
                       val p3 = p1 :+: (fraction *: d)
                       val (xx, yy) = vectoscreen p3
                       val p4 = p3 :+: (0.3 *: normal)
                       val (xxx, yyy) = vectoscreen p4
                   in
                       SDL.drawline (screen, x, y, xx, yy,
                                     color (0w255, 0w255, 0w0, 0w255));
                       SDL.drawline (screen, xx, yy, !savex, !savey,
                                     color (0w255, 0w66, 0w44, 0w66));
                       (* draw normal too *)
                       SDL.drawline (screen, xx, yy, xxx, yyy,
                                     color (0w255, 0w255, 0w22, 0w90))

                   end);

          (* mouse cursor *)
          SDL.drawcircle (screen, x, y, 3, c)
      end

  fun drawsave () =
      let
      in
          SDL.drawcircle (screen, !savex, !savey, 2,
                          color (0w255, 0w255, 0w255, 0w0))
      end

  fun loop () =
      let in

          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          if !rightmouse
          then (frot := !frot + 0.002;
                if !frot > 2.0 * Math.pi
                then frot := !frot - 2.0 * Math.pi
                else ())
          else ();

          drawsave ();
          drawpolygon polygon;
          drawcircle ();
          drawfamiliar ();
          drawmouse ();
          drawdists ();

          flip screen;

          key ();
          delay 1;
          loop ()
      end



  val () = loop ()

end

