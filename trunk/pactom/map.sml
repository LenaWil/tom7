(* Convert GPS trails in a KML file to SVG paths. *)
structure ToSVG =
struct

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val () = msg "Load KMLs..."

  val (pt, osm, hoods) =
      (PacTom.fromkmlfiles ["pac.kml", "pacannotations.kml",
                            "pac2.kml"],
       PacTom.loadosms ["pittsburgh-north.osm",
                        "pittsburgh-northeast.osm",
                        "pittsburgh-center.osm",
                        "pittsburgh-south.osm",
                        "pittsburgh-west.osm",
                        "pittsburgh-southwest.osm"],
       PacTom.neighborhoodsfromkml "neighborhoods.kml")
      handle e as (PacTom.PacTom s) =>
          let in
              msg s;
              raise e
          end

  (* One square meter is very conservative! *)
  val pt = PacTom.simplify_paths 16.0 pt

  val logo = TextSVG.loadgraphic "interstate-logo.svg"

  val () = msg ("There are " ^ Int.toString (Vector.length (PacTom.paths pt)) ^
                " paths\n" ^
                "      and " ^ Int.toString (Vector.length (PacTom.overlays pt)) ^
                " overlays")

  val () =
      let
          fun projection p =
              let val (x, y) = LatLon.gnomonic PacTom.home p
              in
                  (* Scale up massively, and invert Y axis. *)
                  (240000.0 * x, ~240000.0 * y)
              end
          val () = msg "Project paths...";
          val { paths, bounds } = PacTom.projectpaths projection pt
          val () = msg "Project hoods...";
          val { borders, bounds = hoodbounds } = PacTom.projecthoods projection hoods
          val () = Bounds.union bounds hoodbounds
          val rtos = PacTom.rtos
          fun xtos x = PacTom.rtos (Bounds.offsetx bounds x)
          fun ytos y = PacTom.rtos (Bounds.offsety bounds y)
          fun prpt (x, y) = print (xtos x ^ "," ^ ytos y ^ " ")

          fun averagepts l =
              let
                  val (xx, yy) =
                      foldr (fn ((a, b), (aa, bb)) => (a + aa, b + bb)) (0.0, 0.0) l
              in
                  (xx / real (length l), yy / real (length l))
              end

          (* XXX these look terrible on white backgrounds *)
          fun printhoodfill (name, poly) =
              let val pts = Vector.foldr op:: nil poly
                  val pts = pts @ [hd pts]
              in
                  print ("<polygon fill=\"#" ^
                         PacTom.randompalecolor() ^ "\" opacity=\"0.3\"" ^
                         " stroke=\"none\" points=\""); (* " *)
                  app prpt pts;
                  print "\"/>\n" (* " *)
              end

          fun printhoodline (name, poly) =
              let val pts = Vector.foldr op:: nil poly
                  val pts = pts @ [hd pts]
              in
                  print ("<polygon fill=\"none\" opacity=\"0.6\"" ^
                         " stroke=\"#000000\" stroke-width=\"0.5\" points=\""); (* " *)
                  app prpt pts;
                  print "\"/>\n" (* " *)
              end

          fun printpolyline coords =
              let in
                  print ("<polyline stroke-linejoin=\"round\" " ^ (* " *)
                         "fill=\"none\" stroke=\"#" ^
                         PacTom.randombrightcolor() ^
                         "\" stroke-width=\"0.7\" points=\""); (* " *)
                  (* Note: vertical axis has flipped meaning in SVG *)
                  Vector.app (fn (x, y, e) => prpt (x, y)) coords;
                  print "\"/>\n" (* " *)
              end

          fun printoverlay { href, north, south, east, west, alpha, rotation } =
              let
                  (* We assume that this thing is a rectangle, even though it's
                     really a geodesic. *)
                  val tl = projection (LatLon.fromdegs { lat = north, lon = west })
                  val tr = projection (LatLon.fromdegs { lat = north, lon = east })
                  val bl = projection (LatLon.fromdegs { lat = south, lon = west })
                  val br = projection (LatLon.fromdegs { lat = south, lon = east })
                  (* XXX this is not really correct (?), but these things are
                     generally small. *)
                  val cp = averagepts [tl, tr, bl, br]

                  val (x, y) = tl
                  val (x', y') = br
                  val (w, h) = (x' - x, y' - y)

              in
                         (*
                  (* This version just draws a placeholder box. *)
                  (* Note: This transform doesn't work in convert, but does work
                     in illustrator and rsvg-convert. *)
                  print ("<g transform=\"rotate(" ^ PacTom.rtos (~ rotation) ^ " "); (* " *)
                  (* rotate around the object's own center point. *)
                  prpt cp;
                  print (")\" opacity=\"" ^
                         PacTom.rtos (real (Word8.toInt alpha) / 255.0) ^ "\">");
                  print ("<polyline fill=\"none\" stroke=\"#000000\" " ^
                         "stroke-width=\"0.3\" points=\""); (* " *)
                  prpt tl;
                  prpt tr;
                  prpt br;
                  prpt bl;
                  prpt tl; (* close loop *)
                  print ("\" />\n"); (* " *)
                  print ("</g>");
                         *)

                  print ("<use transform=\"translate(" ^ xtos x ^ " " ^ ytos y ^ ")\""); (* " *)
                  (* print ("transform=\"rotate(" ^ PacTom.rtos (~ rotation) ^ " "); (* " *)
                         prpt cp;
                         print ")\"; (* " *)
                  *)
                  (* rotate around the object's own center point. *)
                  print (" opacity=\"" ^
                         PacTom.rtos (real (Word8.toInt alpha) / 255.0) ^ "\"" ^
(*                         " x=\"" ^ xtos x ^ "\" y=\"" ^ xtos y ^ "\"" ^
                         " w=\"" ^ rtos w ^ "\" h=\"" ^ rtos h ^ "\"" ^ *)
                         " xlink:href=\"#MySymbol\" />\n");

                  ()
              end

          fun ++r = r := 1 + !r
          val missing_point = ref 0

          (* XXX not using this until we clip the osm *)
          fun boundosm ({ points, streets } : PacTom.osm) =
             let
                 fun onestreet { pts, ... } =
                    let
                        fun onepoint i =
                          case PacTom.IntMap.find (points, i) of
                            NONE => ()
                          | SOME pos => Bounds.boundpoint bounds (projection pos)
                    in Vector.app onepoint pts
                    end
             in Vector.app onestreet streets
             end

          fun printosm ({ points, streets } : PacTom.osm) =
             let
                 fun onestreet { pts, ... } =
                    let
                        fun onepoint i =
                          case PacTom.IntMap.find (points, i) of
                            NONE => ++missing_point
                          | SOME pos => prpt (projection pos)
                    in
                        print ("<polyline fill=\"none\" stroke=\"#000000\" " ^
                               "opacity=\"0.5\" " ^
                               "stroke-width=\"0.3\" points=\""); (* " *)
                        Vector.app onepoint pts;
                        print ("\" />\n") (* " *)
                    end
             in
                 Vector.app onestreet streets;
                 TextIO.output(TextIO.stdErr, "Missing points: " ^
                               Int.toString (!missing_point) ^ "\n")
             end

          (* val () = boundosm osm *)

          val () = Bounds.addmarginfrac bounds 0.035

          val width = Real.trunc (Bounds.width bounds)
          val height = Real.trunc (Bounds.height bounds)

          (* scale for logo so that it takes 1/10 of the height. *)
          val logoheight = real height / 10.0
          val padding = logoheight / 8.0
          val logox = padding
          val logoy = real height - logoheight - padding
          val logoscale = logoheight / #2 (TextSVG.graphicsize logo)
          val logowidth = logoscale * #1 (TextSVG.graphicsize logo)

          val textx = logowidth + padding * 2.0
          val fontsize = 28.0 (* XXX compute it! *)
          val fontheight = fontsize (* XXX compute it! *)
          val firstliney = logoy + fontheight - 8.5
          val secondliney = firstliney + fontheight + 6.0

          val datestring =
              StringUtil.losespecl (StringUtil.ischar #"0")
              (Date.fmt "%d %b %Y" (Date.fromTimeLocal (Time.now())))

      in
          msg "Output SVG...";
          print (TextSVG.svgheader { x = 0, y = 0,
                                     width = width,
                                     height = height,
                                     generator = "tosvg.sml" });

          (* a background *)
          print ("<rect x=\"-10\" y=\"-10\" width=\"" ^
                 Int.toString (width + 20) ^ "\" height=\"" ^
                 Int.toString (height + 20) ^ "\" " ^
                 "style=\"fill:rgb(32,20,20)\" />\n");

          Vector.app printhoodfill borders;
          Vector.app printhoodline borders;

          (* printosm osm; *)

          Vector.app printpolyline paths;
(*          Vector.app printoverlay (PacTom.overlays pt); *)

          print (TextSVG.placegraphic { graphic = logo, x = logox, y = logoy,
                                        scale = SOME logoscale, rotate = NONE });
          print (TextSVG.svgtext { x = textx, y = firstliney, 
                                   face = "Franklin Gothic Medium",
                                   size = fontsize, 
                                   text = [("#FFFF9E", "Pac Tom Project")] });

          print (TextSVG.svgtext { x = textx, y = secondliney, 
                                   face = "Franklin Gothic Medium",
                                   size = fontsize,
                                   text = [("#CCCCCC", datestring),
                                           ("#666666", " - "),
                                           ("#6297C9", "http://pac.tom7.org")] });

          print (TextSVG.svgfooter ())
      end

end
