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
          fun prpt (x, y) = print (PacTom.rtos (Bounds.offsetx bounds x) ^ "," ^ 
                                   PacTom.rtos (Bounds.offsety bounds y) ^ " ")
          fun averagepts l =
              let
                  val (xx, yy) = 
                      foldr (fn ((a, b), (aa, bb)) => (a + aa, b + bb)) (0.0, 0.0) l 
              in
                  (xx / real (length l), yy / real (length l))
              end

          fun printhoodfill (name, poly) =
              let val pts = Vector.foldr op:: nil poly
                  val pts = pts @ [hd pts]
              in
                  print ("<polyline fill=\"#" ^ 
                         PacTom.randompalecolor() ^ "\" opacity=\"0.3\"" ^
                         " stroke=\"none\" points=\""); (* " *)
                  app prpt pts;
                  print "\"/>\n" (* " *)
              end

          fun printhoodline (name, poly) =
              let val pts = Vector.foldr op:: nil poly
                  val pts = pts @ [hd pts]
              in
                  print ("<polyline fill=\"none\" opacity=\"0.6\"" ^
                         " stroke=\"#000000\" stroke-width=\"0.5\" points=\""); (* " *)
                  app prpt pts;
                  print "\"/>\n" (* " *)
              end

          fun printpolyline coords =
              let in
                  print ("<polyline fill=\"none\" stroke=\"#" ^ 
                         PacTom.randombrightcolor() ^ 
                         "\" stroke-width=\"0.7\" points=\""); (* " *)
                  (* XXX vertical axis has flipped meaning in SVG *)
                  Vector.app (fn (x, y, e) => prpt (x, y)) coords;
                  print "\"/>\n"
              end

          fun printoverlay { href, north, south, east, west, alpha, rotation } =
              let 
                  val tl = projection (LatLon.fromdegs { lat = north, lon = west })
                  val tr = projection (LatLon.fromdegs { lat = north, lon = east })
                  val bl = projection (LatLon.fromdegs { lat = south, lon = west })
                  val br = projection (LatLon.fromdegs { lat = south, lon = east })
                      
                  (* XXX this is not really correct (?), but these things are 
                     generally small. *)
                  val cp = averagepts [tl, tr, bl, br]
              in
                  (* XXX fake! Note that rotate works fine in illustrator but does
                     the wrong thing in convert. should probably work around this by
                     always rotating around 0 *)
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
                  ()
              end

      in
          msg "Output SVG...";
          print (PacTom.svgheader { x = 0, y = 0, 
                                    width = Real.trunc (Bounds.width bounds), 
                                    height = Real.trunc (Bounds.height bounds),
                                    generator = "tosvg.sml" });
          Vector.app printhoodfill borders;
          Vector.app printhoodline borders;
          Vector.app printpolyline paths;
          Vector.app printoverlay (PacTom.overlays pt);
          print (PacTom.svgfooter ())
      end

end