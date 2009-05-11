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
          val points = ref nil

          fun process (Elem(("coordinates", nil), [Text coordtext])) =
              let val coords = String.tokens (fn #" " => true | _ => false) coordtext
                  val coords = map (fn t =>
                                    case String.fields (fn #"," => true | _ => false) t of
                                        [long, lat, elev] =>
                                            (case (Real.fromString long, Real.fromString lat, Real.fromString elev) of
                                                 (SOME lon, SOME lat, SOME _) => {lat = lat, lon = lon}
                                               | _ => raise MakePoints ("non-numeric lat/lon/elev: " ^ long ^ "," ^ lat ^ "," ^ elev))
                                      | _ => raise MakePoints ("bad coord token: " ^ t)) coords
              in
                  points := coords @ !points
              end
            | process (Elem(("coordinates", _), _)) = raise MakePoints "coordinates with subtags or attrs?"
            | process (e as Text _) = ()
            | process (Elem(t, tl)) = app process tl

          val x = XML.parsefile f 
              handle XML.XML s => 
                  raise MakePoints ("Couldn't parse " ^ f ^ "'s xml: " ^ s)
          val () = process x

      in
          !points
      end

  (* No exponential notation *)
  fun ertos r = if (r > ~0.000001 andalso r < 0.000001) then "0.0" else (Real.fmt (StringCvt.FIX (SOME 14)) r)

  (* Don't use SML's dumb ~ *)
  fun rtos r = if r < 0.0 
               then "-" ^ ertos (0.0 - r)
               else ertos r

  fun writepoints pts f =
      let
          val f = TextIO.openOut f
          fun placemarks { lat, lon } =
              print ("<Placemark><styleUrl>#circle</styleUrl><Point><coordinates>" ^
                     rtos lon ^ "," ^ rtos lat ^ ",0" ^
                     "</coordinates></Point></Placemark>\n")
      in
          print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
          print "<kml xmlns=\"http://www.opengis.net/kml/2.2\" xmlns:gx=\"http://www.google.com/kml/ext/2.2\" xmlns:kml=\"http://www.opengis.net/kml/2.2\" xmlns:atom=\"http://www.w3.org/2005/Atom\">\n";
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
