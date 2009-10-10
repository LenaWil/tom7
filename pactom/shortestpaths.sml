(* Takes all of the Pactom data, and builds a reachability graph.
   Then, compute the shortest distances to home.
   Then, compute a minimal spanning tree comprising all points.
   Output to KML or SVG. *)

structure Radial = 
struct 

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val pt = PacTom.fromkmlfiles ["pactom.kml"]
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

  val () =
      let 
          fun prpt (x, y) = print (PacTom.rtos x ^ "," ^ PacTom.rtos y ^ " ")

          fun printpolyline nil =
              print "Can't plot empty path.\n"
            | printpolyline ((start, _) :: coords) =
              let 
                  fun plot nil _ _ = ()
                    | plot ((pos, elev) :: t) prev total_miles =
                      let
                          val theta = (total_miles / REVOLUTION_MILES) * Math.pi * 2.0
                          val r = LatLon.dist_miles (PacTom.home, pos) * 100.0

                          val x = r * Math.cos theta
                          val y = r * Math.sin theta
                      in
                          prpt (x, y);
                          plot t pos (total_miles + LatLon.dist_miles (prev, pos))
                      end
              in
                  print ("<polyline fill=\"none\" opacity=\"0.75\" stroke=\"#" ^ 
                         PacTom.randombrightcolor() ^ 
                         "\" stroke-width=\"1\" points=\""); (* " *)
                  (* XXX Should put point at 0 deg, radius = |start - home| *)
                  plot coords start 0.0;

                  print "\"/>\n"
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
          Vector.app printpolyline (PacTom.paths pt);
          print "</svg>\n"
      end

end