(* Takes all of the Pactom data, and builds a reachability graph.
   Then, compute the shortest distances to home.
   Then, compute a minimal spanning tree comprising all points.
   Output to KML or SVG. *)

structure Radial = 
struct
  structure G = PacTom.G

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

  val { graph, promote } = PacTom.spanning_graph pt PacTom.home
      handle e as G.UndirectedGraph s => (msg s; raise e)
           | e as PacTom.PacTom s => (msg s; raise e)

  fun prloc l =
      let val { lat, lon } = LatLon.todegs l
      in print (PacTom.rtos lat ^ "," ^ PacTom.rtos lon ^ " ")
      end

  val paths = PacTom.paths pt

  fun printedge node =
      let
          val G.S { a = { path, pt }, dist, parent } = G.get node
          val (pos, _) = Vector.sub (Vector.sub (paths, path), pt)
      in
          case parent of
              SOME parnode =>
                  let val G.S { a = { path, pt }, ... } = G.get parnode
                      val (ppos, _) = Vector.sub (Vector.sub(paths, path), pt)
                  in
                      print ("<LineString><coordinates>");
                      prloc pos;
                      print " ";
                      prloc ppos;
                      print (" </coordinates></LineString>\n")
                  end
           | NONE => () (* XXX show unreachable/terminus somehow? *)
      end
  
  val () =
      let in
      print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
      print ("<kml xmlns=\"http://www.opengis.net/kml/2.2\" " ^
             "xmlns:gx=\"http://www.google.com/kml/ext/2.2\" " ^
             "xmlns:kml=\"http://www.opengis.net/kml/2.2\" " ^
             "xmlns:atom=\"http://www.w3.org/2005/Atom\">\n");
      print  "<Folder>\n";
      print  "  <name>Shortest Paths</name>\n";
      print  "  <visibility>1</visibility>\n";
      print  "  <Placemark>\n";
      print  "          <name>Shortest Path Segments</name>\n";
      print  "          <visibility>1</visibility>\n";
      print  "          <open>1</open>\n";
      print  "          <Style>\n";
      print  "                  <IconStyle>\n";
      print  "                          <color>ff2f2fc3</color>\n";
      print  "                          <scale>3</scale>\n";
      print  "                          <heading>0</heading>\n";
      print  "                  </IconStyle>\n";
      print  "                  <LineStyle>\n";
      print  "                          <color>ff2f2fc3</color>\n";
      print  "                          <width>3</width>\n";
      print  "                  </LineStyle>\n";
      print  "                  <PolyStyle>\n";
      print  "                          <color>ff2f2fc3</color>\n";
      print  "                  </PolyStyle>\n";
      print  "          </Style>\n";
      print  "        <MultiGeometry>\n";

      G.app printedge graph;

      print  "        </MultiGeometry>\n";
      print  "  </Placemark>\n";
      print  "</Folder>\n";
      print  "</kml>\n"
      end

end