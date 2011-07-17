(* Animation test for Toward *)
structure AnimateTest =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:
  infixr 9 `
  fun f ` x = f x

  structure BDD = BDDWorld(
    type fixture_data = unit
    type body_data = string
    type joint_data = unit)
  open BDD
  exception Animate of string

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

  val WIDTH = 1024
  val HEIGHT = 768
  val PIXELS_PER_METER = 50
  val METERS_PER_PIXEL = 1.0 / real PIXELS_PER_METER
  val screen = makescreen (WIDTH, HEIGHT)

  structure M = Maths

  val LETTERFILE = "letter.toward"

  (* val () = SDL.show_cursor false *)

  fun tometers d = real d * METERS_PER_PIXEL
  fun toworld (xp, yp) =
      let
          val xp = xp - (WIDTH div 2)
          val yp = yp - (HEIGHT div 2)
      in
          (tometers xp, tometers yp)
      end

  val DRAW_NORMALS = false
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
  fun topixels d = d * real PIXELS_PER_METER
  fun toscreen (xm, ym) =
      let
          val xp = topixels xm
          val yp = topixels ym
      in
          (Real.round xp + (WIDTH div 2),
           Real.round yp + (HEIGHT div 2))
      end

  fun vectoscreen v = toscreen (vec2xy v)
  fun screentovec (x, y) = vec2 (toworld (x, y))

  val WHITE = hexcolor 0xFFFFFF
  fun drawpolygon (xf, polygon) =
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
               SDL.drawline (screen, x, y, xx, yy, WHITE)
           end);
          SDL.drawcircle (screen, cx, cy, 2, WHITE)
      end

  fun drawcircle (xf, { radius, p }) =
      let
          val p = xf @*: p
          (* drawcircle surf x y radius color
             draws a circle (not filled)
             *)
          val (x, y) = toscreen (vec2xy p)
          val r = Real.round (topixels radius)
      in
          SDL.drawcircle (screen, x, y, r, WHITE)
      end


  fun drawshape (xf, BDDShape.Circle c) = drawcircle (xf, c)
    | drawshape (xf, BDDShape.Polygon p) = drawpolygon (xf, p)


  fun printpolygon (xf, polygon) =
      let
          val num = Array.length (#vertices polygon)

          val { center, ... } = BDDPolygon.compute_mass (polygon, 1.0)
          (* val (cx, cy) = vectoscreen (xf @*: center) *)
      in
          print "poly: ";
          Util.for 0 (num - 1)
          (fn i =>
           let val i2 = if i = num - 1
                        then 0
                        else i + 1
               val (x, y) = vectoscreen (xf @*: Array.sub(#vertices polygon, i))
               (* val (xx, yy) = vectoscreen (xf @*: Array.sub(#vertices polygon, i2)) *)
           in
               print (Int.toString x ^ "," ^ Int.toString y ^ " -> ")
           end);
          print "\n"
      end

  fun printcircle (xf, { radius, p }) =
      let
          val p = xf @*: p
          val (x, y) = toscreen (vec2xy p)
          val r = Real.round (topixels radius)
      in
          print ("circle at " ^ Int.toString x ^ "/" ^ Int.toString y ^ 
                 " @" ^ Int.toString r ^ "\n")
      end


  fun printshape (xf, BDDShape.Circle c) = printcircle (xf, c)
    | printshape (xf, BDDShape.Polygon p) = printpolygon (xf, p)

  val gravity = vec2 (0.0, 9.8)
  (* No sleep, for now XXX j/k *)
  val world = World.world (gravity, true) (* ALLOW *)

  fun add_letter (x, y, letter) =
      let
          val origin = vec2 (x, y)
          val body = World.create_body
              (world,
               { typ = Body.Dynamic,
                 position = origin,
                 angle = 0.0,
                 linear_velocity = vec2 (0.0, 0.0),
                 angular_velocity = 0.0,
                 linear_damping = 0.0,
                 angular_damping = 0.0,
                 allow_sleep = true,
                 awake = true,
                 fixed_rotation = false,
                 bullet = false,
                 active = true,
                 data = "letter",
                 inertia_scale = 1.0 })

          (* put each shape on it. *)
          val shapes = Letter.shapes (origin, letter)
          val () = app
              (fn sh =>
               ignore `
               Body.create_fixture (body, 
                                    { shape = sh,
                                      data = (),
                                      friction = 0.2,
                                      restitution = 0.15,
                                      density = 1.0,
                                      is_sensor = false,
                                      filter = Fixture.default_filter })) shapes
      in
          ()
      end

  val () = add_letter (0.0, ~3.0, Letter.fromstring (StringUtil.readfile LETTERFILE))

  val ground = World.create_body
      (world,
       { typ = Body.Static,
         position = vec2 (0.0, 4.75),
         angle = 0.0,
         linear_velocity = vec2 (0.0, 0.0),
         angular_velocity = 0.0, 
         linear_damping = 0.0,
         angular_damping = 0.0,
         allow_sleep = true,
         awake = true,
         fixed_rotation = false,
         bullet = false,
         active = true,
         data = "ground",
         inertia_scale = 1.0 })

  val ground_floor =
      Body.create_fixture_default (ground, 
                                   BDDShape.Polygon
                                   (BDDPolygon.box (6.0, 0.2)),
                                   (), 1.0)

  exception Done

  (* val () = SDL.show_cursor true *)
  val rightmouse = ref false
  val mousex = ref 0
  val mousey = ref 0


  val PURPLE = hexcolor 0xFF00FF
  val RED = hexcolor 0xFF0000
  fun drawworld world =
    let
      fun onebody b =
        let
            val xf = Body.get_transform b
            val fixtures = Body.get_fixtures b
            fun onefixture f =
                let val shape = Fixture.shape f
                in drawshape (xf, shape)
                end
        in
            oapp Fixture.get_next onefixture fixtures
        end

      fun onecontact c =
        let
            val world_manifold = { normal = vec2 (~999.0, ~999.0),
                                   points = Array.fromList
                                   [ vec2 (~111.0, ~111.0),
                                     vec2 (~222.0, ~222.0) ] }
            val { point_count, ... } = Contact.get_manifold c
            val () = Contact.get_world_manifold (world_manifold, c)
            (* Where should the normal be drawn from? one of the points? *)
            val (sx, sy) = vectoscreen (vec2 (0.0, 0.0))
            val (dx, dy) = vectoscreen (#normal world_manifold)
        in
            if DRAW_NORMALS
            then SDL.drawline (screen, sx, sy, dx, dy, RED)
            else ();

            for 0 (point_count - 1) 
            (fn i =>
             let val pt = Array.sub(#points world_manifold, i)
                 val (x, y) = vectoscreen pt
             in
                 SDL.drawcircle (screen, x, y, 2, PURPLE)
             end)
        end
   in
      oapp Body.get_next onebody (World.get_body_list world);
      oapp Contact.get_next onecontact (World.get_contact_list world)
    end

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))

  fun getfixturename (f : fixture) =
    let val b = Fixture.get_body f
    in Body.get_data b
    end

  fun printworld world =
    let
      fun onebody b =
          (* Print only the drop. *)
        if Body.get_data b = "drop"
        then
        let
            val xf = Body.get_transform b
                (*
            val fixtures = Body.get_fixtures b
            fun onefixture f =
                let
                    val shape = Fixture.shape f
                in
                    print "Fixture.\n";
                    printshape (xf, shape)
                end
        in
            print "Body.\n";
            oapp Fixture.get_next onefixture fixtures *)
            val pos = transformposition xf
        in
            print ("drop xf: " ^ xftos xf ^ "\n")
        end
        else ()

      fun onecontact c =
        let
            val world_manifold = { normal = vec2 (~999.0, ~999.0),
                                   points = Array.fromList
                                   [ vec2 (~111.0, ~111.0),
                                     vec2 (~222.0, ~222.0) ] }
            val { point_count, ... } = Contact.get_manifold c
            val () = Contact.get_world_manifold (world_manifold, c)
            val name1 = getfixturename (Contact.get_fixture_a c)
            val name2 = getfixturename (Contact.get_fixture_b c)
        in
            print (name1 ^ "-" ^ name2 ^ " Contact! ");
            if Contact.is_touching c
            then print "touching "
            else ();
            print (Int.toString point_count ^ " points: ");
            for 0 (point_count - 1) 
            (fn i =>
             let val pt = Array.sub(#points world_manifold, i)
                 (* val (x, y) = vectoscreen pt *)
             in
                 print (rtos (vec2x pt) ^ "," ^ rtos (vec2y pt) ^ " ")
             end);

            print "\n"
        end
    in
      oapp Body.get_next onebody (World.get_body_list world);
      oapp Contact.get_next onecontact (World.get_contact_list world)
    end

  val iters = ref 0
  fun key () =
      case pollevent () of
          NONE => ()
        | SOME evt =>
           case evt of
               E_Quit => raise Done
             | E_KeyDown { sym = SDLK_ESCAPE } => raise Done
             | E_MouseMotion { state : mousestate, x : int, y : int, ... } =>
                   let in 
                       mousex := x;
                       mousey := y
                   end
(*
             | E_MouseDown { button = 1, x, y, ... } =>
                   let in
                       savex := x;
                       savey := y
                   end
*)
             | _ => ()

  fun drawinstructions () =
      let val (x, y) = (1, 1)
      in Font.draw (screen, x, y, "^3TOWARD^< animate")
      end

  val total_step = ref (0 : IntInf.int)
  val total_draw = ref (0 : IntInf.int)
  fun drawtiming () =
      let
          val (x, y) = (1, 1)
          val y = y + Font.height * 2
              
          val tot = Real.fromLargeInt (!total_step + !total_draw)
          val pcts = (100.0 * Real.fromLargeInt (!total_step)) / tot
          val pctd = (100.0 * Real.fromLargeInt (!total_draw)) / tot

          fun ptos p =
              if Real.isFinite p
              then Int.toString (Real.round p)
              else "?"
      in
          (* only if not saving pngs *)
          Font.draw (screen, x, y,
                     ptos pcts ^ "% step " ^
                     ptos pctd ^ "% draw " ^
                     "^4FPS TODO")
      end

  fun loop () =
      let 
          val start_draw = Time.now ()
      in
          
          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          drawworld world;
          drawinstructions ();
          drawtiming ();

          flip screen;

          total_draw := !total_draw + Time.toMicroseconds (Time.-(Time.now (), start_draw));

          key ();
          delay 0;
          iters := !iters + 1;
          let val start_step = Time.now ()
          in
              World.step (world, 0.005, 1000, 1000);
              total_step := !total_step + 
              Time.toMicroseconds (Time.-(Time.now (), start_step))
          end;
          loop ()
      end


  val () = print "*** Startup ***\n"
  val () = printworld world

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  val () = Params.main0 "No arguments." loop
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               BDDDynamics.BDDDynamics s => eprint s
             | BDDDynamicTree.BDDDynamicTree s => eprint s
             | BDDContactSolver.BDDContactSolver s => eprint s
             | BDDMath.BDDMath s => eprint s
             | Animate s => eprint s
             | Letter.Letter s => eprint s
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end
                   
end

