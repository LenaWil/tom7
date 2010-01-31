(* Convert GPS trails in a KML file to SVG paths. *)
structure ToSVG = 
struct 

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val () = msg "Load KMLs..."

  val (pt, hoods) = (PacTom.fromkmlfiles ["pac.kml", "pacannotations.kml",
                                          "pac2.kml"],
                     PacTom.neighborhoodsfromkml "neighborhoods.kml")
      handle e as (PacTom.PacTom s) =>
          let in
              msg s;
              raise e
          end

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

          (* XXX these look terrible. *)
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

      in
          msg "Output SVG...";
          print (PacTom.svgheader { x = 0, y = 0, 
                                    width = Real.trunc (Bounds.width bounds), 
                                    height = Real.trunc (Bounds.height bounds),
                                    generator = "tosvg.sml" });
          print
          ("<defs>\n" ^
           "<symbol id=\"MySymbol\" viewBox=\"0 0 1 1\">\n" ^
           " <desc>MySymbol - four rectangles in a grid</desc>\n" ^
           " <rect x=\"0\" y=\"0\" width=\"0.2\" height=\"0.2\"/>\n" ^
           " <rect x=\"0.8\" y=\"0\" width=\"0.2\" height=\"0.2\"/>\n" ^
           " <rect x=\"0\" y=\"0.8\" width=\"0.2\" height=\"0.2\"/>\n" ^
           " <rect x=\"0.8\" y=\"0.8\" width=\"0.2\" height=\"0.2\"/>\n" ^
           "</symbol>\n" ^
           "</defs>\n");

          Vector.app printhoodfill borders;
          Vector.app printhoodline borders;
          Vector.app printpolyline paths;
          Vector.app printoverlay (PacTom.overlays pt);
          print (PacTom.svgfooter ())
      end

end