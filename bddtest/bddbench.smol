structure BDDTest =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:

  structure BDD = BDDWorld(
    type fixture_data = unit
    type body_data = string
    type joint_data = unit)
  open BDD

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

(*
  val circle = { radius = 0.3,
                 p = vec2 (1.0, 0.3) }

  val polygon = BDDPolygon.polygon 
      (map screentovec (rev [(225, 280),
                             (295, 124),
                             (185, 36),
                             (136, 51),
                             (116, 330)]))

  (* roughly centered around screen origin *)
*)
  val small_circle = BDDShape.Circle { radius = 0.3,
                                       p = vec2 (0.0, 0.0) }
  val familiar_shape = BDDShape.Polygon 
      (BDDPolygon.polygon
       (map screentovec (rev [(377, 268),
                              (386, 321),
                              (418, 329),
                              (428, 305)])))


  val gravity = vec2 (0.0, 9.8)
  (* No sleep, for now *)
  val world = World.world (gravity, false)


  val drop = World.create_body 
      (world,
       { typ = Body.Dynamic,
         (* Start at origin. *)
         position = vec2 (0.0, 0.12),
         angle = 0.0,
         linear_velocity = vec2 (0.1, 0.2),
         angular_velocity = 0.0,
         linear_damping = 0.0,
         angular_damping = 0.0,
         allow_sleep = false,
         awake = true,
         fixed_rotation = false,
         bullet = false,
         active = true,
         data = "drop",
         inertia_scale = 1.0 })

  (* put a fixture on the drop *)
  val drop_fixture = 
      Body.create_fixture_default (drop, 
                                   familiar_shape,
                                   (* small_circle, *)
                                   (), 1.0)

  val drop2 = World.create_body 
      (world,
       { typ = Body.Dynamic,
         position = vec2 (0.0, ~1.0),
         angle = 0.0,
         linear_velocity = vec2 (0.4, 6.0),
         angular_velocity = 0.0,
         linear_damping = 0.0,
         angular_damping = 0.0,
         allow_sleep = false,
         awake = true,
         fixed_rotation = false,
         bullet = false,
         active = true,
         data = "drop2",
         inertia_scale = 1.0 })

  (* put a fixture on the drop *)
  val drop2_fixture = 
      Body.create_fixture_default (drop2,
                                   familiar_shape,
                                   (* small_circle, *)
                                   (), 1.0)


  (* PS if dynamic and linear velocity of 0,~2, then they have a non-touching
     collision, which might be a good test case. *)
  val ground = World.create_body
      (world,
       { typ = Body.Static,
         position = vec2 (0.0, 0.75),
         angle = 0.0,
         linear_velocity = vec2 (0.0, 0.0),
         angular_velocity = 0.0, 
         linear_damping = 0.0,
         angular_damping = 0.0,
         allow_sleep = false,
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

  val rightmouse = ref false

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
            SDL.drawline (screen, sx, sy, dx, dy, RED);

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
                 print (vtos pt ^ ", ")
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
               E_KeyDown { sym = SDLK_ESCAPE } => raise Done
(*
             | E_KeyDown { sym = SDLK_SPACE } => 
                   let in
                       print ("=== Step " ^ Int.toString (!iters) ^ " ===\n");
                       (* 100ms time step *)
                       World.step (world, 0.01, 10, 10);
                       printworld world;
                       iters := !iters + 1
                   end
*)
             | _ => ()
  fun drawinstructions () =
      let
      in
          Font.draw 
          (screen, 1, 1, 
           "^3BoxDiaDia dynamics test^<. You just watch")
      end

  fun loop () =
      let in
          print ("\n=== Step " ^ Int.toString (!iters) ^ " ===\n");
          iters := !iters + 1;


          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          drawworld world;
          drawinstructions ();

          flip screen;

          key ();
          delay 1;
          World.step (world, 0.001, 10, 10);

          loop ()
      end

  val () = print "\n*** Startup ***\n"
  val () = printworld world

  val MAX_ITERS = 85

  fun loop () =
      for 0 (* 14 *) MAX_ITERS
      (fn i =>
       let in
           print ("\n=== Step " ^ Int.toString i ^ " ===\n");
           World.step (world, 0.01, 10, 10);
           printworld world
       end)


  fun eprint s = TextIO.output (TextIO.stdErr, s)

  val () = loop ()
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               BDDDynamics.BDDDynamics s => eprint s
             | BDDContactSolver.BDDContactSolver s => eprint s
             | BDDMath.BDDMath s => eprint s
             | BDDDynamicTree.BDDDynamicTree s => eprint s
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end
                   
end

