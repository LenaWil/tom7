(* Google Earth doesn't show vertices on polygons except when you're
   editing them. This makes it hard to make polygons line up exactly
   by placing colocated vertices. This program takes a KML file that
   contains only <LinearRing> geometric elements (because it assumes
   that all <coordinates> tags contain polygons), and outputs another
   KML containing <Point> placemarks for every vertex in the input.
*)
structure MakePoints =
struct

  datatype tree = datatype XML.tree

  exception MakePoints of string

  fun readkmlfile f =
    let
        val polys = ref nil

        fun process (Elem(("coordinates", nil), [Text coordtext])) =
            let 
              val coords = String.tokens (fn #" " => true | _ => false) coordtext
              val coords = 
                map (fn t =>
                     case map Real.fromString (String.fields (fn #"," => true 
                                                                  | _ => false) t) of
                         [SOME lon, SOME lat, SOME _] => (lon, lat)
                       | _ => raise MakePoints ("non-numeric lat/lon/elev: " ^ t)) coords
            in
                polys := ((), Polygon.frompoints coords) :: !polys
            end
          | process (Elem(("coordinates", _), _)) = 
            raise MakePoints "coordinates with subtags or attrs?"
          | process (e as Text _) = ()
          | process (Elem(t, tl)) = app process tl

        val x = XML.parsefile f 
            handle XML.XML s => 
                raise MakePoints ("Couldn't parse " ^ f ^ "'s xml: " ^ s)
        val () = process x

        val normed = PointLocation.normalize 0.00002 (!polys)

        local 
            val home = LatLon.fromdegs { lat = 40.452911, lon = ~79.936313 }
            val projection = LatLon.gnomonic home
            fun scalex x = x * 80000.0
            fun scaley y = y * ~80000.0
        in
            val scaled = ListUtil.mapsecond 
                (fn poly =>
                 Polygon.frompoints 
                 (map (fn (lon, lat) =>
                       let 
                           val pt = LatLon.fromdegs { lat = lat, lon = lon }
                           val (x, y) = projection pt
                       in
                           (scalex x, scaley y)
                       end) (Polygon.points poly))) normed
        end

        val f = TextIO.openOut "neighborhoods-locator-test.svg"
            (* XXX needs massive scaling! Also, conversion to x/y. *)
        val () = PointLocation.tosvg (PointLocation.locator scaled) 
                                     (fn s => TextIO.output (f, s))
        val () = TextIO.closeOut f
    in
        List.concat (map (Polygon.points o #2) normed)
    end

  (* No exponential notation *)
  fun ertos r = if (r > ~0.000001 andalso r < 0.000001) 
                then "0.0" 
                else (Real.fmt (StringCvt.FIX (SOME 14)) r)

  (* Don't use SML's dumb ~ *)
  fun rtos r = if r < 0.0 
               then "-" ^ ertos (0.0 - r)
               else ertos r

  (* Lexicographically. This biases one axis over the other
     in a possibly strange way. Could consider first taking
     the distance from the origin or something (?). *)
  fun comparepoint ((x, y), (xx, yy)) =
      case Real.compare (x, xx) of
          EQUAL => Real.compare (y, yy)
        | order => order

  datatype 'a set = Empty | Node of 'a set * 'a * 'a set
  fun fromlist nil = Empty
    | fromlist (h :: t) =
      let val (l, r) = List.partition (fn x => case comparepoint (x, h) of 
                                       LESS => true
                                     | _ => false) t
      in Node (fromlist l, h, fromlist r)
      end
  fun count Empty x = 0
    | count (Node (l, y, r)) x = 
      case comparepoint (x, y) of
          (* PERF only one of these is necessary, I think. *)
          EQUAL => 1 + count l x + count r x
        | LESS => count l x
        | GREATER => count r x

  fun writepoints pts f =
      let
          val f = TextIO.openOut f

          val set = fromlist (map (fn (lon, lat) => (lon, lat)) pts)

          fun placemarks (lon, lat) =
              (* This isn't really the test we want, because we want to show
                 incomplete "T" intersections too, though these will be obvious
                 in almost every case from the polygon fills. *)
              if count set (lon, lat) = 1
              then print ("<Placemark><styleUrl>#circle</styleUrl><Point><coordinates>" ^
                          rtos lon ^ "," ^ rtos lat ^ ",0" ^
                          "</coordinates></Point></Placemark>\n")
              else ()

      in
          print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
          print ("<kml xmlns=\"http://www.opengis.net/kml/2.2\"" ^ 
                 " xmlns:gx=\"http://www.google.com/kml/ext/2.2\"" ^
                 " xmlns:kml=\"http://www.opengis.net/kml/2.2\"" ^
                 " xmlns:atom=\"http://www.w3.org/2005/Atom\">\n");
          print "<Document>\n";
          print "<name>neighborhood dots (generated)</name>\n";
          print "<Style id=\"sn_placemark_circle\">\n";
          print " <IconStyle>\n";
          print "  <scale>1.2</scale>\n";
          print "  <Icon>\n";
          print "   <href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href>\n";
          print "  </Icon>\n";
          print " </IconStyle>\n";
          print " <ListStyle>\n";
          print " </ListStyle>\n";
          print "</Style>\n";
          print "<StyleMap id=\"circle\">\n";
          print "<Pair>\n";
          print " <key>normal</key>\n";
          print "  <styleUrl>#sn_placemark_circle</styleUrl>\n";
          print " </Pair>\n";

(*
          print " <Pair>\n";
          print "  <key>highlight</key>\n";
          print "  <styleUrl>#sh_placemark_circle_highlight</styleUrl>\n";
          print " </Pair>\n";
*)
          print "</StyleMap>\n";
          print "<Folder>\n";
          print "<name>Points</name>\n";
          print "<description>(generated)</description>\n";
          List.app placemarks pts;
          print "</Folder>\n";
          print "</Document>\n";
          print "</kml>\n";

          TextIO.closeOut f
      end

  val pts = readkmlfile "neighborhoods.kml"
  val () = writepoints pts "neighbordots.kml"


end
