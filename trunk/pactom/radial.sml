(* Converts KML trails into a radial image that shows distance from
   home by time. *)
structure Radial = 
struct 

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val pt = PacTom.fromkmlfiles ["pac.kml", "pac2.kml"]
      handle e as (PacTom.PacTom s) =>
          let in
              msg s;
              raise e
          end

  val () = msg ("There are " ^ Int.toString (Vector.length (PacTom.paths pt)) ^ 
                " paths\n" ^
                "      and " ^ Int.toString (Vector.length (PacTom.overlays pt)) ^ 
                " overlays")

  (* The graphic is as follows:

     We use polar coordinates to draw each path. (XXX Straight up is 0
     degrees), where positive degrees is clockwise. A path is plotted
     in increasing degrees according to its total distance. Its radius
     is the distance from some home spot (PacTom.home). 

     *)
  (* XXX compute this dynamically, as slightly more than the longest
     run in there *)
  val REVOLUTION_MILES = 32.0
  val GRAPHIC_SIZE = 800

  fun vector_tolist v = Vector.foldr op:: nil v

  fun get_max_distance paths =
      let
          val md = ref 0.0
      in
          Vector.app (app (fn (pos, _) =>
                           let val dist = LatLon.dist_miles (PacTom.home, pos)
                           in if dist > !md
                              then md := dist
                              else ()
                           end)) paths;
          !md
      end

  fun randomvariant () =
      let val h = 0.086 + (PacTom.randf() * 0.1) - 0.05
          val s = 0.8314 + (PacTom.randf() * 0.1) - 0.05
          val v = 0.9 + (PacTom.randf() * 0.1) - 0.05
      in Color.tohexstring (Color.rgbf (Color.hsvtorgbf (h, s, v)))
      end

  val () =
      let 
          val paths = Vector.map vector_tolist (PacTom.paths pt)
          val MAX_DISTANCE = get_max_distance paths
          val () = msg ("Max distance: " ^ PacTom.rtos MAX_DISTANCE)

          fun prpt (x, y) = print (PacTom.rtos x ^ "," ^ PacTom.rtos y ^ " ")
          fun prptcentered (x, y) = prpt (x + real GRAPHIC_SIZE / 2.0,
                                          y + real GRAPHIC_SIZE / 2.0)

          fun ptcentered c = PacTom.rtos (c + real GRAPHIC_SIZE / 2.0)

          fun miles_to_r m =
              real GRAPHIC_SIZE * 0.45 * (m / MAX_DISTANCE)

          fun miles_to_theta m =
              (m / REVOLUTION_MILES) * Math.pi * 2.0

          fun printpolyline nil =
              print "Can't plot empty path.\n"
            | printpolyline ((start, _) :: coords) =
              let 
                  fun plot nil _ _ = ()
                    | plot ((pos, elev) :: t) prev total_miles =
                      let
                          val theta = miles_to_theta total_miles
                          val r = miles_to_r (LatLon.dist_miles (PacTom.home, pos))

                          val x = r * Math.cos theta
                          val y = r * Math.sin theta
                      in
                          prptcentered (x, y);
                          plot t pos (total_miles + LatLon.dist_miles (prev, pos))
                      end
              in
                  print ("<polyline fill=\"none\" opacity=\"0.5\" stroke=\"#" ^ 
                         randomvariant() ^ 
                         "\" stroke-width=\"1\" points=\""); (* " 
                  *)
                  (* XXX Should put point at 0 deg, radius = |start - home| *)
                  plot coords start 0.0;

                  print "\"/>\n"
              end

          val CENTERX = real GRAPHIC_SIZE / 2.0
          val CENTERY = real GRAPHIC_SIZE / 2.0

          fun makecircles m =
              if real m < MAX_DISTANCE
              then 
              let 
                  val rad = miles_to_r (real m)
                  val t = [("#9F9F00", Int.toString m),
                           ("#7F7F20", " mi")]
              in
                  print ("<circle cx=\"" ^ PacTom.rtos CENTERX ^ "\" cy=\"" ^
                         PacTom.rtos CENTERY ^ "\" r=\"" ^ 
                         PacTom.rtos rad ^ "\" fill=\"none\"" ^
                         " opacity=\"0.5\" stroke-width=\"0.5\"" ^
                         " stroke=\"#FFFF60\" />\n"); 
                           (* " *)
                           
                  print (TextSVG.svgtext { x = CENTERX + rad + (miles_to_r 0.1),
                                           y = CENTERY - 6.0,
                                           face = "Franklin Gothic Medium",
                                           size = 14.0,
                                           text = t });
                  makecircles (m + 1)
              end
              else ()

          fun makerays m =
              if real m < REVOLUTION_MILES
              then
                let
                    val t = [("#9F9FAF", Int.toString m),
                             ("#7F7FB0", " mi")]

                    val theta = miles_to_theta (real m)

                    (* Don't start at center; it's too messy. *)
                    val r0 = miles_to_r 1.0
                    (* XXX should probably hit the circle. *)
                    val r1 = miles_to_r (real (Real.trunc MAX_DISTANCE))
                    (* Text is wider than tall, so be an oval, wider
                       near the left or right (angles near 0 or pi) *)
                    val rt = r1 + miles_to_r 0.30 + 
                        (Real.abs (Math.cos theta) * miles_to_r 0.35)

                    val x0 = r0 * Math.cos theta
                    val y0 = r0 * Math.sin theta
                    val x1 = r1 * Math.cos theta
                    val y1 = r1 * Math.sin theta

                    val tx = rt * Math.cos theta
                    val ty = rt * Math.sin theta
                in
                    print ("<line x1=\"" ^ ptcentered x0 ^ 
                              "\" y1=\"" ^ ptcentered y0 ^
                              "\" x2=\"" ^ ptcentered x1 ^
                              "\" y2=\"" ^ ptcentered y1 ^
                              (if m = 0
                               then "\" stroke-width=\"1.0\""
                               else "\" stroke-width=\"0.5\"") ^
                              " stroke=\"#AAAAFF\"" ^
                              " opacity=\"0.75\" />\n");

                    (* for placing text
                    print ("<circle cx=\"" ^ PacTom.rtos (CENTERX + tx) ^
                                   "\" cy=\"" ^ PacTom.rtos (CENTERY + ty) ^
                                   "\" r=\"2\" stroke=\"#FFFFFF\" />\n");
                    *)

                    print (TextSVG.svgtext { x = CENTERX + tx - 16.0,
                                             y = CENTERY + ty + 6.0,
                                             face = "Franklin Gothic Medium",
                                             size = 14.0,
                                             text = t });

                    makerays (m + 1)
                end
              else ()

          val datestring = 
              StringUtil.losespecl (StringUtil.ischar #"0")
              (Date.fmt "%d %b %Y" (Date.fromTimeLocal (Time.now())))

      in
          (* XXX compute actual size *)
          print (TextSVG.svgheader { x = 0, y = 0, 
                                     width = GRAPHIC_SIZE,
                                     height = GRAPHIC_SIZE,
                                     generator = "radial.sml" });

          (* Black background. *)
          print ("<rect x=\"-10\" y=\"-10\" width=\"" ^
                  Int.toString (GRAPHIC_SIZE + 20) ^ "\" height=\"" ^
                  Int.toString (GRAPHIC_SIZE + 20) ^ "\" style=\"fill:rgb(20,20,32)\" />\n");

          makerays 0;
          makecircles 1;

          print (TextSVG.svgtext { x = 5.0, y = 20.0,
                                   face = "Franklin Gothic Medium",
                                   size = 18.0,
                                   text = [("#FFFF9E", "Pac Tom Project")] });

          print (TextSVG.svgtext { x = 5.0, y = 38.0,
                                   face = "Franklin Gothic Medium",
                                   size = 16.0,
                                   text = [("#CCCCCC", datestring),
                                           ("#666666", " - "),
                                           ("#6297C9", "http://pac.tom7.org")] });

          Vector.app printpolyline paths;

          print (TextSVG.svgfooter ())
      end

end
