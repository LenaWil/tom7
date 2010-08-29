
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

  val mousex = ref 0
  val mousey = ref 0

  val savex = ref 0
  val savey = ref 0

  exception Done

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
             | E_MouseDown { button = _, x, y, ... } =>
                   let in
                       savex := x;
                       savey := y
                   end
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

  fun drawpolygon () =
      let
          val num = Array.length (#vertices polygon)
          val c = color (0w255, 0w255, 0w255, 0w200)
      in
          Util.for 0 (num - 1)
          (fn i =>
           let val i2 = if i = num - 1
                        then 0
                        else i + 1
               val (x, y) = vectoscreen (Array.sub(#vertices polygon, i))
               val (xx, yy) = vectoscreen (Array.sub(#vertices polygon, i2))
           in
               SDL.drawline (screen, x, y, xx, yy, c)
           end)
      end

  fun drawmouse () =
      let
          val xf = BDDMath.identity_transform ()
          val pt = vec2 (toworld (!mousex, !mousey))
              
          (* Colliding? *)
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
          
          drawsave ();
          drawpolygon ();
          drawcircle ();
          drawmouse ();

          flip screen;

          key ();
          delay 1;
          loop ()
      end



  val () = loop ()

end

