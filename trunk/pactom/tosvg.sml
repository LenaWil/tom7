(* Convert GPS trails in a KML file to SVG paths. *)
structure ToSVG = 
struct 

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val pt = PacTom.fromkmlfiles ["pactom.kml", "pacannotations.kml"]
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
          val projection = LatLon.gnomonic PacTom.home
          val { paths, minx, maxx, miny, maxy } = PacTom.projectpaths projection pt
          fun scalex x = x * 80000.0
          fun scaley y = y * 80000.0
          fun prpt (x, y) = print (PacTom.rtos (scalex x) ^ "," ^ 
                                   PacTom.rtos (scaley y) ^ " ")
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
                         "\" stroke-width=\"1\" points=\""); (* " *)
                  (* XXX No, should use bounding box that's the output of projectpaths.. *)
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
                  (* XXX fake! *)
                  print ("<g transform=\"rotate(" ^ PacTom.rtos rotation ^ " "); (* " *)
                  (* rotate around the object's own center point. *)
                  prpt cp;
                  print (")\" opacity=\"" ^ 
                         PacTom.rtos (real (Word8.toInt alpha) / 255.0) ^ "\">");
                  print ("<polyline fill=\"none\" stroke=\"#000000\" " ^
                         "stroke-width=\"2\" points=\""); (* " *)
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
          print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
          print "<!-- Generator: ToSVG.sml  -->\n";
          print "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\" [\n";
          print "<!ENTITY ns_flows \"http://ns.adobe.com/Flows/1.0/\">\n";
          print "]>\n";
          print "<svg version=\"1.1\"\n";
          print " xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n";
          print " xmlns:a=\"http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/\"\n";
          (* XXX *)
          print " x=\"0px\" y=\"0px\" width=\"263px\" height=\"243px\"\n";
          print " xml:space=\"preserve\">\n";
          Vector.app printpolyline paths;
          Vector.app printoverlay (PacTom.overlays pt);
          print "</svg>\n"
      end

end