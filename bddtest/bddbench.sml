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

  val WIDTH = 800
  val HEIGHT = 600

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

  val small_circle = BDDShape.Circle { radius = 0.3,
                                       p = vec2 (0.0, 0.0) }
  val familiar_shape = BDDShape.Polygon 
      (BDDPolygon.polygon
       (map screentovec (rev [(377, 268),
                              (386, 321),
                              (418, 329),
                              (428, 305)])))

  local fun mapcoord (xp, yp) =
      let
          fun tom p = real p * 0.01
          val xp = xp - (800 div 2)
          val yp = yp - (600 div 2)
      in
          vec2 (tom xp, tom yp)
      end
  in
  val familiar_shape = BDDShape.Polygon 
      (BDDPolygon.polygon
       (map mapcoord (rev [(377, 268),
                           (386, 321),
                           (418, 329),
                           (428, 305)])))
  end

  val gravity = vec2 (0.0, 9.8)
  (* No sleep, for now XXX j/k *)
  val world = World.world (gravity, false)


  fun add_drop (s, x, y, a) =
      let
          val drop = World.create_body 
              (world,
               { typ = (if s then Body.Static else Body.Dynamic),
                 (* Start at origin. *)
                 (* funny if they all start at 0, 1.12 *)
                 position = (* vec2 (0.0, 1.12) *) vec2(x, y),
                 angle = a,
                 linear_velocity = vec2 (0.1, 0.2),
                 angular_velocity = a,
                 linear_damping = 0.0,
                 angular_damping = 0.0,
                 allow_sleep = true,
                 awake = true,
                 fixed_rotation = false,
                 bullet = false,
                 active = true,
                 data = "drop",
                 inertia_scale = 1.0 })

          (* put a fixture on the drop *)
          val drop_fixture = 
              Body.create_fixture (drop, 
                                   { shape = 
                                     (if (Real.trunc x * 13 +
                                          Real.trunc y * 11) mod 2 = 0
                                      then familiar_shape
                                      else small_circle),
                                     data = (),
                                     friction = 0.2,
                                     restitution = 0.15,
                                     density = 1.0,
                                     is_sensor = false,
                                     filter = Fixture.default_filter })
      in
          ()
      end

  val () = 
      Util.for ~5 1
      (fn y =>
       Util.for ~5 5
       (fn x =>
        let in
            add_drop (y = 1, real x * 1.25, real y * 0.75,
                      Real.realMod (Math.sin(real x + real y)) * 6.28 - 3.14)
        end))

(*
          val drop = World.create_body 
              (world,
               { typ = Body.Dynamic,
                 position = vec2 (0.0, 1.12),
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
              Body.create_fixture (drop, 
                                   { shape = familiar_shape,
                                     (* small_circle, *)
                                     data = (),
                                     friction = 0.2,
                                     restitution = 0.75,
                                     density = 1.0,
                                     is_sensor = false,
                                     filter = Fixture.default_filter })
*)


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
            val pos = transformposition xf
        in
            reallyprint ("drop xf: " ^ xftos xf ^ "\n")
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

  fun loop () =
      let in
          print ("\n=== Step " ^ Int.toString (!iters) ^ " ===\n");
          iters := !iters + 1;

          World.step (world, 0.001, 10, 10);

          loop ()
      end

  val () = reallyprint "\n*** Startup ***\n"
  val () = printworld world

  val MAX_ITERS = 250

  fun loop () =
      let in
          for 0 (* 14 *) MAX_ITERS
          (fn i =>
           let in
               print ("\n=== Step " ^ Int.toString i ^ " ===\n");
               World.step (world, 0.01, 10, 10)
           end);
          (* Make sure results are used. *)
          reallyprint "\n*** Finish ***\n";
          printworld world
      end


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

