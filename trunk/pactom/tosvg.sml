(* Convert GPS trails in a KML file to SVG paths. *)
structure ToSVG = 
struct 

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val pt = PacTom.fromkmlfiles ["pac.kml", "pacannotations.kml",
                                "pac2.kml"]
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
          val { paths, bounds } = PacTom.projectpaths projection pt
          (* val { minx, maxx, miny, maxy } = PacTom.getbounds bounds *)
          fun prpt (x, y) = print (PacTom.rtos (PacTom.offsetx bounds x)  ^ "," ^ 
                                   PacTom.rtos (PacTom.offsety bounds y) ^ " ")
          fun averagepts l =
              let
                  val (xx, yy) = 
                      foldr (fn ((a, b), (aa, bb)) => (a + aa, b + bb)) (0.0, 0.0) l 
              in
                  (xx / real (length l), yy / real (length l))
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
          print (PacTom.svgheader { x = 0, y = 0, 
                                    width = Real.trunc (PacTom.width bounds), 
                                    height = Real.trunc (PacTom.height bounds),
                                    generator = "tosvg.sml" });
          Vector.app printpolyline paths;
          Vector.app printoverlay (PacTom.overlays pt);
          print (PacTom.svgfooter ())
      end

end