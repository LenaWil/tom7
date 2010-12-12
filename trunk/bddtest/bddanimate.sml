structure BDDTest =
struct

  val output = Params.param ""
      (SOME ("-output", "Set output for PNG series.")) "output"

  val frames = Params.param "0"
      (SOME ("-frames", "Write this many frames to PNG series, " ^
             "then stop.")) "frames"

  val downsample = Params.param "1"
      (SOME ("-downsample", "Each output frame consists of this " ^
             "many actual frames, blended together")) "downsample"

  val title = Params.param "You just watch"
      (SOME ("-title", "Use this title.")) "title"

  val cropx = Params.param "0" (SOME ("-cropx", "x offset for crop")) "cropx"
  val cropy = Params.param "0" (SOME ("-cropy", "y offset for crop")) "cropy"
  val cropw = Params.param "0" (SOME ("-cropw", "width of crop")) "cropw"
  val croph = Params.param "0" (SOME ("-croph", "height of crop")) "croph"

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:

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

  val WIDTH = 800
  val HEIGHT = 600
  val METERS_PER_PIXEL = 0.01
  val PIXELS_PER_METER = 100
  val screen = makescreen (WIDTH, HEIGHT)

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
  (* No sleep, for now XXX j/k *)
  val world = World.world (gravity, true)


  fun add_drop (s, x, y) =
      let
          val drop = World.create_body 
              (world,
               { typ = (if s then Body.Static else Body.Dynamic),
                 (* Start at origin. *)
                 (* funny if they all start at 0, 1.12 *)
                 position = (* vec2 (0.0, 1.12) *) vec2(x, y),
                 angle = 0.0,
                 linear_velocity = vec2 (0.1, 0.2),
                 angular_velocity = 1.0,
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
                                   { shape = familiar_shape,
                                     (* small_circle, *)
                                     data = (),
                                     friction = 0.2,
                                     restitution = 0.75,
                                     density = 1.0,
                                     is_sensor = false,
                                     filter = Fixture.default_filter })
      in
          ()
      end

  val () = 
      Util.for ~1 1
      (fn y =>
       Util.for ~2 2
       (fn x =>
        let in
            add_drop (y = 1, real x * 1.25, real y * 0.75)
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
         position = vec2 (0.0, 1.75),
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
      let
          val (x, y) =
              if Params.asint 0 frames > 0
              then (Params.asint 0 cropx,
                    Params.asint 0 cropy)
              else (1, 1)
      in
          Font.draw 
          (screen, x, y, 
           if !title = ""
           then "^3BoxDiaDia dynamics test^<: You just watch"
           else !title);
          (* only if not saving pngs *)
          if Params.asint 0 frames > 0
          then ()
          else Font.draw (screen, x, Font.height + y,
                          "^2" ^
                          Int.toString (!mousex) ^ " " ^ 
                          Int.toString (!mousey) ^ "^< " ^
                          Int.toString (!iters))
      end

  fun crop (width, height, a) =
      let
          val (cx, cy, cw, ch) = (Params.asint 0 cropx,
                                  Params.asint 0 cropy,
                                  Params.asint 0 cropw,
                                  Params.asint 0 croph)
      in
          if cw = 0 orelse ch = 0
          then (width, height, a)
          else
           let
               val cropped = Array.array (cw * ch * 4, 0w0 : Word8.word)
           in
               Util.for 0 (ch - 1)
               (fn y =>
                Util.for 0 (cw - 1)
                (fn x =>
                 Util.for 0 3
                 (fn i =>
                  let val ox = x + cx
                      val oy = y + cy
                  in
                      Array.update(cropped, 
                                   (y * cw + x) * 4 + i,
                                   Array.sub(a, (oy * width + ox) * 4 + i))
                  end)));
               (cw, ch, cropped)
           end
      end

  fun blendframes nil = raise Animate "Can't blend 0 frames"
    | blendframes (l as ((w, h, _) :: _)) =
      let
          val frames = map #3 l
          val aa = Array.array (w * h * 4, 0w0)
          val num = length l

          (* Get the color component, merged, from all the frames. *)
          fun get (x, y, i) =
              let val total = 
                  foldr (fn (a, acc) => acc +
                         real (Word8.toInt (Array.sub (a, (w * y + x) * 4 + i)))) 0.0 frames
                  val avg = total / real num
              in
                  Word8.fromInt (Real.round avg)
              end

      in
          Util.for 0 (h - 1)
          (fn y =>
           Util.for 0 (w - 1)
           (fn x =>
            let val r = get (x, y, 0)
                val g = get (x, y, 1)
                val b = get (x, y, 2)
                val a = 0w255
            in
                Array.update(aa, (w * y + x) * 4 + 0, r);
                Array.update(aa, (w * y + x) * 4 + 1, g);
                Array.update(aa, (w * y + x) * 4 + 2, b);
                Array.update(aa, (w * y + x) * 4 + 3, a)
            end
            ));
          (w, h, aa)
      end

  val framenum = ref 0
  val thisframe = ref (nil : (int * int * Word8.word Array.array) list)
  fun flush () =
      case !thisframe of
          nil => () 
        | _ => 
        let
            val f = !output ^ "-" ^ 
                StringUtil.padex #"0" ~4 (Int.toString (!framenum)) ^
                ".png"

            val (w, h, a) = blendframes (!thisframe)
        in
            if PNGsave.save (f, w, h, a)
            then print ("Wrote " ^ f ^ "\n")
            else raise Animate ("Couldn't write " ^ f);

            framenum := !framenum + 1;
            thisframe := nil
        end

    fun saveframe () =
      let val (w, h, a) = SDL.pixels screen
          val (w, h, a) = crop (w, h, a)
      in 
          thisframe := (w, h, a) :: !thisframe;
          if length (!thisframe) >= Params.asint 1 downsample
          then flush ()
          else ()
      end
      

  val total_step = ref (0 : IntInf.int)
  val total_draw = ref (0 : IntInf.int)
  fun drawtiming () =
      let
          val (x, y) =
              if Params.asint 0 frames > 0
              then (Params.asint 0 cropx,
                    Params.asint 0 cropy)
              else (1, 1)
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
          if Params.asint 0 frames > 0
          then ()
          else Font.draw (screen, x, y,
                          ptos pcts ^ "% step " ^
                          ptos pctd ^ "% draw " ^
                          "^4FPS TODO")
      end

  fun loop () =
      let 
          (* One of these tails is called, depending on whether we're
             watching the animation or saving frames. *)
          fun interactive () =
              let in
                  key ();
                  delay 0;
                  iters := !iters + 1;
                  let val start_step = Time.now ()
                  in
                      World.step (world, 0.005, 10, 10);
                      total_step := !total_step + 
                        Time.toMicroseconds (Time.-(Time.now (), start_step))
                  end;
                  loop ()
              end

          fun auto () = 
              let in
                  iters := !iters + 1;
                  World.step (world, 0.0005, 10, 10);
                  loop ()
              end
          val start_draw = Time.now ()
      in
          
          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          drawworld world;
          drawinstructions ();
          drawtiming ();

          flip screen;

          total_draw := !total_draw + Time.toMicroseconds (Time.-(Time.now (), start_draw));

          case (!output, Params.asint 0 frames) of
              (_, 0) => interactive ()
            | ("", _) => interactive ()
            | (file, n) =>
              if !iters < n
              then (saveframe(); auto ())
              else (flush(); print "Done.\n")
      end


  val () = print "*** Startup ***\n"
  val () = printworld world

(*
  fun loop () =
      for 0 (* 14 *) 14
      (fn i =>
       let in
           print ("\n=== Step " ^ Int.toString i ^ " ===\n");
           World.step (world, 0.01, 10, 10);
           printworld world
       end)
*)

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
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end
                   
end

