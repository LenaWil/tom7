(* Takes all of the Pactom data, and builds a reachability graph.
   Then, compute the shortest distances to home.
   Then, compute a minimal spanning tree comprising all points.
   Output to KML or SVG. *)

structure Radial = 
struct
  structure G = PacTom.G

  val svgout = Params.param "" (SOME ("-svgout",
                                      "SVG output file, if desired.")) "svgout"
  val kmlout = Params.param "" (SOME ("-kmlout",
                                      "KML output file, if desired.")) "kmlout"

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

  val { graph, promote } = PacTom.spanning_graph pt PacTom.home
      handle e as G.UndirectedGraph s => (msg s; raise e)
           | e as PacTom.PacTom s => (msg s; raise e)

  fun loctos l =
      let val { lat, lon } = LatLon.todegs l
      in (PacTom.rtos lon ^ "," ^ PacTom.rtos lat)
      end

  val paths = PacTom.paths pt

  (* Google Earth goes nuts if we try to generate a placemark for each
     line segment, with a color set for each one. We really don't need
     that many different colors, though. Instead organize the line segments
     by color bin, so that all the segments of the same color are in the
     same bin and don't need to be separate placemarks. *)
  val color_bins = Array.array(180, nil : (LatLon.pos * LatLon.pos) list)
  fun radians_to_bin r =
      Real.trunc (real (Array.length color_bins) * r / (Math.pi * 2.0))
      mod Array.length color_bins

  fun binedge node =
      let
          val G.S { a = { path, pt }, dist, parent } = G.get node
          val (pos, _) = Vector.sub (Vector.sub (paths, path), pt)
      in
          case parent of
              SOME parnode =>
                  let val G.S { a = { path, pt }, ... } = G.get parnode
                      val (ppos, _) = Vector.sub (Vector.sub(paths, path), pt)
                  in
                      case LatLon.angle (pos, ppos) of
                          NONE => msg "no angle!"
                        | SOME r => 
                              let val b = radians_to_bin r
                              in
                                  Array.update 
                                  (color_bins, b,
                                   (pos, ppos) :: Array.sub (color_bins, b))
                              end
                  end
           | NONE => () (* XXX show unreachable/terminus somehow? *)
      end

  (* generate bins. *)
  val () = G.app binedge graph

  fun anglecolor f =
      let val (r, g, b) = Color.hsvtorgbf (f, 1.0, 1.0)
      in Color.tohexstring (Word8.fromInt (Real.trunc (r * 255.0)),
                            Word8.fromInt (Real.trunc (g * 255.0)),
                            Word8.fromInt (Real.trunc (b * 255.0)))
      end

  fun writebinkml write (idx, segments) =
      let 
          val color = anglecolor (real idx / real (Array.length color_bins))
          fun writept (pos, ppos) =
              write("<LineString><coordinates>" ^
                    loctos pos ^ " " ^
                    loctos ppos ^
                    " </coordinates></LineString>\n")
      in
          write "<Placemark><Style><LineStyle><color>";
          write ("7f" ^ color);
          write "</color><width>3</width></LineStyle></Style>";
          write "<MultiGeometry>\n";
          (* now each segment ... *)
          app writept segments;
          write "</MultiGeometry></Placemark>\n"
      end
  
  fun writekml "" = msg "Skipping KML."
    | writekml fname =
      let val f = TextIO.openOut fname
          fun write s = TextIO.output(f, s)
      in
        write "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
        write ("<kml xmlns=\"http://www.opengis.net/kml/2.2\" " ^
               "xmlns:gx=\"http://www.google.com/kml/ext/2.2\" " ^
               "xmlns:kml=\"http://www.opengis.net/kml/2.2\" " ^
               "xmlns:atom=\"http://www.w3.org/2005/Atom\">\n");
        write  "<Folder>\n";
        write  "  <name>Shortest Paths</name>\n";
        write  "  <visibility>1</visibility>\n";

        Array.appi (writebinkml write) color_bins;

        write  "</Folder>\n";
        write  "</kml>\n";
        
        TextIO.closeOut f
      end

  fun writesvg "" = msg "Skipping SVG."
    | writesvg fname =
      let
          val f = TextIO.openOut fname
          fun write s = TextIO.output(f, s)
          fun projection p = 
              let val (x, y) = LatLon.gnomonic PacTom.home p
              in 
                  (* Scale up massively, and invert Y axis. *)
                  (240000.0 * x, ~240000.0 * y)
              end

          (* Generate bounding box. PERF: Could precompute projections,
             and this strategy means each node is added n times, where
             n is its degree. But far from being the slowest part of
             this program.. *)
          val bounds = Bounds.nobounds ()
          fun addpt p = Bounds.boundpoint bounds (projection p)
          (* Process each end point of each segment of each bin *)
          val () = Array.app (fn (segments : (LatLon.pos * LatLon.pos) list) =>
                              app (fn (a, b) => (addpt a; addpt b)) segments) color_bins


          fun writept (x : real, y : real) = 
              write (PacTom.rtos (Bounds.offsetx bounds x) ^ " " ^ 
                     PacTom.rtos (Bounds.offsety bounds y))


          fun writebin (idx, segments) =
              let 
                  val color = anglecolor (real idx / real (Array.length color_bins))
                  fun writeseg (pos : LatLon.pos, ppos : LatLon.pos) =
                      let in
                          write "M";
                          writept (projection pos);
                          write "L";
                          writept (projection ppos)
                      end
              in
                  write ("<path fill=\"none\" stroke=\"#" ^ color ^ "\" " ^
                         " opacity=\"0.7\"" ^
                         " stroke-width=\"0.6\" d=\""); (* " *)
                  app writeseg segments;
                  write "\"/>\n"
              end
      in
          write (PacTom.svgheader { x = 0, y = 0, 
                                    width = Real.trunc (Bounds.width bounds), 
                                    height = Real.trunc (Bounds.height bounds),
                                    generator = "shortestpaths.sml" });
          Array.appi writebin color_bins;
          write (PacTom.svgfooter ())
      end

  fun main () =
      let in
          writekml (!kmlout);
          writesvg (!svgout)
      end
      

  val () = 
      Params.main0 
      ("Takes no arguments and reads KML files in the " ^
       "current directory. Should specify at least one output " ^
       "format, or nothing will happen.") main
      
end