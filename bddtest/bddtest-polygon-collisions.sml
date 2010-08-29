structure BDDTest =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:

  structure U = Util
  open SDL
  structure Util = U

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

  val WIDTH = 800
  val HEIGHT = 600
  val screen = makescreen (WIDTH, HEIGHT)

  val () = SDL.show_cursor false

  val METERS_PER_PIXEL = 0.01
  fun tometers d = real d * METERS_PER_PIXEL
  fun toworld (xp, yp) =
      let
          val xp = xp - 400
          val yp = yp - 300
      in
          (tometers xp, tometers yp)
      end

  val DRAW_DISTANCES = true
  val DRAW_RAYS = true
  val DRAW_COLLISIONS = true

  (* 0xRRGGBB *)
  fun hexcolor c =
      let
          val b = c mod 256
          val g = (c div 256) mod 256
          val r = ((c div 256) div 256) mod 256
      in
          SDL.color (Word8.fromInt r, 
                     Word8.fromInt g,
                     Word8.fromInt b,
                     0w255)
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
                          hexcolor 0xFFFFFF)
      end

  fun drawpolygonat (xf, polygon, c) =
      let
          val num = Array.length (#vertices polygon)

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
      drawpolygonat (BDDMath.identity_transform (), polygon, hexcolor 0xFFFFA0)

  fun drawfamiliar () =
      let
          val pt = vec2 (toworld (!mousex, !mousey))
          val xf = BDDMath.transform_pos_angle (pt, !frot)
      in
          drawpolygonat (xf, familiar, hexcolor 0xFFFFFF)
      end

  (* closest points between familiar and other objects *)
  val shapes = [BDDShape.Circle circle,
                BDDShape.Polygon polygon]
  val distance_proxies = map (fn s =>
                              (BDDDistance.shape_proxy s,
                               BDDDistance.initial_cache ())) shapes
  fun drawdists () =
      if DRAW_DISTANCES
      then
      let
          val fidentity = BDDMath.identity_transform ()
          val pt = vec2 (toworld (!mousex, !mousey))
          val ffam = BDDMath.transform_pos_angle (pt, !frot)

          val fprox = BDDDistance.shape_proxy (BDDShape.Polygon familiar)

          val c = hexcolor 0x0033FF
          val cc = hexcolor 0x0077FF
                      
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
                  (* print (Int.toString iterations ^ "\n"); *)
                  SDL.drawline (screen, ax, ay, bx, by, c);
                  SDL.drawcircle (screen, ax, ay, 2, c);
                  SDL.drawcircle (screen, bx, by, 2, c)
              end
      in
          app one distance_proxies
      end
      else ()

  fun drawcollisions () =
      if DRAW_COLLISIONS
      then
      let
          val pt = vec2 (toworld (!mousex, !mousey))
          val fident = BDDMath.identity_transform ()
          val ffam = BDDMath.transform_pos_angle (pt, !frot)
          val { point_count,
                typ, local_point, local_normal, points,
                ... } =
              BDDCollision.collide_polygon_and_circle (familiar, ffam,
                                                       circle, fident)
      in
          if point_count = 0
          then ()
          else
              let 
                  (* It's in local coordinates to the familiar *)
                  val w = ffam @*: local_point
                  val (x, y) = vectoscreen w

                  val (xn, yn) = vectoscreen 
                      (ffam @*: (local_point :+: 0.2 *: local_normal))

                  val { local_point = lp2, ... } = Array.sub(points, 0)
                  val (xx, yy) = vectoscreen (fident @*: lp2)
              in
                  SDL.drawline (screen, x, y, xn, yn, hexcolor 0x771234);
                  SDL.drawcircle (screen, x, y, 2, hexcolor 0xFF5678);
                  SDL.drawcircle (screen, xx, yy, 2, hexcolor 0x5678FF)
              end
      end
      else ()

  exception FAILURE
  fun drawpolycollisions () =
      if DRAW_COLLISIONS
      then
      let
          val pt = vec2 (toworld (!mousex, !mousey))
          val fident = BDDMath.identity_transform ()
          val ffam = BDDMath.transform_pos_angle (pt, !frot)
          val { point_count,
                typ, local_point, local_normal, points,
                ... } =
              BDDCollision.collide_polygons (familiar, ffam,
                                             polygon, fident)
      in
          if point_count = 0
          then ()
          else
              let 
                  val (xf, xff) = case typ of
                      BDDTypes.E_FaceA => (ffam, fident)
                    | BDDTypes.E_FaceB => (fident, ffam)
                    | _ => raise FAILURE

                  (* val () = print "COLLIDE.\n" *)
                  (* It's in local coordinates to the familiar *)
                  val w = xf @*: local_point
                  val (x, y) = vectoscreen w

                  val (xn, yn) = vectoscreen 
                      (xf @*: (local_point :+: 0.2 *: local_normal))

                  fun onepoint { local_point = lp2, ... } =
                      let val (xx, yy) = vectoscreen (xff @*: lp2)
                      in
                          SDL.drawcircle (screen, xx, yy, 2, hexcolor 0x5678FF)
                      end
              in
                  SDL.drawline (screen, x, y, xn, yn, hexcolor 0x771234);
                  SDL.drawcircle (screen, x, y, 2, hexcolor 0xFF5678);
                  Array.app onepoint points
              end
      end
      else ()

  fun drawrays () =
      if DRAW_RAYS
      then 
      let
          val xf = BDDMath.identity_transform ()
          val pt = vec2 (toworld (!mousex, !mousey))
              
          (* Colliding? *)
          (* XXX use shapes list *)
          val c = 
              if BDDCircle.test_point (circle, xf, pt) orelse
                 BDDPolygon.test_point (polygon, xf, pt)
              then hexcolor 0xFF0000
              else hexcolor 0x00FF00

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
                                    hexcolor 0x442244)
             | { normal, fraction } :: _ => 
                   let
                       val d = p2 :-: p1
                       val p3 = p1 :+: (fraction *: d)
                       val (xx, yy) = vectoscreen p3
                       val p4 = p3 :+: (0.3 *: normal)
                       val (xxx, yyy) = vectoscreen p4
                   in
                       SDL.drawline (screen, x, y, xx, yy,
                                     hexcolor 0x442244);
                       SDL.drawline (screen, xx, yy, !savex, !savey,
                                     hexcolor 0xFF00FF);
                       (* draw normal too *)
                       SDL.drawline (screen, xx, yy, xxx, yyy,
                                     hexcolor 0xFF2290)
                   end);

          (* mouse cursor *)
          (* SDL.drawcircle (screen, x, y, 3, c) *)
          ()
      end
      else ()

  fun drawsave () =
      let
      in
          SDL.drawcircle (screen, !savex, !savey, 2,
                          hexcolor 0xFFFF00)
      end

  fun drawaabbs () =
      let
          fun one shape =
            let
                val xf = BDDMath.identity_transform ()
                val { lowerbound, upperbound } = 
                    BDDShape.compute_aabb (shape, xf)
                    
                val (x0, y0) = vectoscreen lowerbound
                val (x1, y1) = vectoscreen upperbound
            in
                SDL.drawbox (screen, x0, y0, x1, y1, hexcolor 0x323232)
            end
      in
          app one shapes
      end

  fun drawinstructions () =
      let
      in
          Font.draw 
          (screen, 1, 1, 
           "^3BoxDiaDia test^<. ^1left mouse^< to cast ray. ^1right^< to rotate familiar.")
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

          drawaabbs ();

          drawsave ();
          drawpolygon polygon;
          drawcircle ();
          drawfamiliar ();
          drawrays ();
          drawdists ();
          drawcollisions ();
          drawpolycollisions ();

          drawinstructions ();

          flip screen;

          key ();
          delay 1;
          loop ()
      end



  val () = loop ()

end

