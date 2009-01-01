(* Convert GPS trails in a KML file to SVG paths. *)
structure ToSVG = 
struct 

  val pt = PacTom.fromkmlfile "pactom.kml"

  val () =
      let 
          val { paths, minx, maxx, miny, maxy } = PacTom.projectpaths (LatLon.gnomonic PacTom.home) pt
          fun printpolyline coords =
              let in
                  print ("<polyline fill=\"none\" stroke=\"#" ^ PacTom.randombrightcolor() ^ "\" stroke-width=\"1\" points=\""); (* " *)
                  (* XXX No, should use bounding box that's the output of projectpaths.. *)
                  (* XXX vertical axis has flipped meaning in SVG *)
                  List.app (fn (x, y, e) => 
                            print (PacTom.rtos (1000.0 * x) ^ "," ^ PacTom.rtos (1000.0 * y) ^ " ")) coords;
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
          Vector.app printpolyline paths;
          print "</svg>\n"
      end



end