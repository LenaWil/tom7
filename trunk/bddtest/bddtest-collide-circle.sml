
structure BDDTest =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:
      
  open SDL

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

  val circle = { radius = 0.3,
                 p = vec2 (1.0, 0.3) }

  val mousex = ref 0
  val mousey = ref 0

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

  fun drawmouse () =
      let
          val xf = BDDMath.identity_transform ()
          val pt = vec2 (toworld (!mousex, !mousey))
              
          (* Colliding? *)
          val c = 
              if BDDCircle.test_point (circle, xf, pt)
              then color (0w255, 0w255, 0w0, 0w0)
              else color (0w255, 0w0, 0w255, 0w0)

          val (x, y) = vectoscreen pt
      in
          SDL.drawcircle (screen, x, y, 3, c)
      end

  fun loop () =
      let in

          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));
          
          drawcircle ();
          drawmouse ();

          flip screen;

          key ();
          delay 1;
          loop ()
      end



  val () = loop ()

end

