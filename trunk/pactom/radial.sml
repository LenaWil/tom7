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
  val REVOLUTION_MILES = 20.0

  fun vector_tolist v = Vector.foldr op:: nil v

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
          (* XXX compute actual size *)
          print (PacTom.svgheader { x = 0, y = 0, width = 264, height = 243,
                                    generator = "radial.sml" });

          Vector.app (printpolyline o vector_tolist) (PacTom.paths pt);

          print (PacTom.svgfooter ())
      end

end
