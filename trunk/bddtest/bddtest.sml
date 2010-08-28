
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

     
  (* Put the origin of the world at WIDTH / 2, HEIGHT / 2.
     make the viewport show 8 meters by 6. *)
  val PIXELS_PER_METER = 100
  fun topixels (xm, ym) =
      let
          val xp = xm * real PIXELS_PER_METER
          val yp = ym * real PIXELS_PER_METER
      in
          (Real.round xp + 400,
           Real.round yp + 300)
      end

  val circle = { radius = 0.3,
                 p = vec2 (1.0, 0.3) }

  exception Done

  fun key () =
      case pollevent () of
          NONE => ()
        | SOME evt =>
           case evt of
               E_KeyDown { sym = SDLK_ESCAPE } => raise Done
             | _ => ()

  fun loop () =
      let in

          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          flip screen;

          key ();
          delay 1;
          loop ()
      end



  val () = loop ()

end

