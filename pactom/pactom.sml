(* Utilities for PacTom activities. *)
structure PacTom :> PACTOM = 
struct 

  exception PacTom of string

  datatype tree = datatype XML.tree

  (* XXX add some stuff. *)
  type pactom = { xml : tree, 
                  paths : (LatLon.pos * real) list Vector.vector }
  fun paths { xml, paths } = paths

  (* XXX dead? PERF: Slow *)
  fun printxml (Text s) =
      (StringUtil.replace "<" "&lt;"
       (StringUtil.replace ">" "&gt;"
        (StringUtil.replace "&" "&amp;" s)))
    | printxml (Elem ((s, attrs), tl)) =
      ("<" ^ s ^
       String.concat (map (fn (s, so) => 
                           case so of
                               SOME v => 
                                   (* XXX escape quotes in v *)
                                   (" " ^ s ^ "=\"" ^ v ^ "\"")
                             | NONE => s) attrs) ^
       ">" ^
       String.concat (map printxml tl) ^
       "</" ^ s ^ ">")

  val home = LatLon.fromdegs { lat = 40.452911, lon = ~79.936313 }

  val seed = MersenneTwister.init32 0wxDEADBEEF
  fun rand () = MersenneTwister.rand32 seed


  fun fromkmlfile f =
      let
          val x = XML.parsefile f handle XML.XML s => raise PacTom ("Couldn't parse xml: " ^ s)
          val paths = ref nil

          fun process (Elem(("coordinates", nil), [Text coordtext])) =
              let val coords = String.tokens (fn #" " => true | _ => false) coordtext
                  val coords = map (fn t =>
                                    case String.fields (fn #"," => true | _ => false) t of
                                        [long, lat, elev] =>
                                            (case (Real.fromString long, Real.fromString lat, Real.fromString elev) of
                                                 (SOME long, SOME lat, SOME elev) => (LatLon.fromdegs {lat = lat, lon = long}, elev)
                                               | _ => raise PacTom ("non-numeric lat/lon/elev: " ^ long ^ "," ^ lat ^ "," ^ elev))
                                      | _ => raise PacTom ("bad coord token: " ^ t)) coords
              in
                  paths := coords :: !paths
              end
            | process (Elem(("coordinates", _), _)) = raise PacTom "coordinates with subtags or attrs?"
            | process (e as Text _) = ()
            | process (Elem(t, tl)) = app process tl

      in
          process x;
          { xml = x, paths = Vector.fromList (rev (!paths)) }
      end

  (* always alpha 1.0 *)
  fun randomanycolor () = 
      StringUtil.padex #"0" ~6 (Word32.toString (rand()))

  (* Same value and saturation, different hue. *)
  fun randombrightcolor () =
      Color.tohexstring (Color.hsvtorgb 
                         (Word8.fromInt (Word32.toInt (Word32.andb(Word32.>>(rand (), 0w7), 0wxFF))),
                          0wxFF,
                          0wxFF))


  (* No exponential notation *)
  fun ertos r = if (r > ~0.000001 andalso r < 0.000001) then "0.0" else (Real.fmt (StringCvt.FIX (SOME 4)) r)

  (* Don't use SML's dumb ~ *)
  fun rtos r = if r < 0.0 
               then "-" ^ ertos (0.0 - r)
               else ertos r

  fun projectpaths proj { paths, xml = _ } =
      let
          val maxx = ref (~1.0 / 0.0)
          val minx = ref (1.0 / 0.0)
          val maxy = ref (~1.0 / 0.0)
          val miny = ref (1.0 / 0.0)
              
          fun bound p min max =
              let in
                  if p < !min
                  then min := p
                  else ();
                  if p > !max
                  then max := p
                  else ()
              end
          val paths = Vector.map (List.map (fn (p, z) =>
                                            let val (x, y) = proj p
                                            in 
                                                bound x minx maxx;
                                                bound y miny maxy;
                                                (x, y, z)
                                            end)) paths
      in
          { paths = paths,
            minx = !minx, maxx = !maxx, miny = !miny, maxy = !maxy }
      end


(*
  val () =
      let 
          fun printpolyline coords =
              let in
                  print ("<polyline fill=\"none\" stroke=\"#" ^ randomcolor() ^ "\" stroke-width=\"1\" points=\""); (* " *)
                  (* XXX mapping is nonlinear. see elevsvg. *)
                  app (fn (lat, lon) => print (rtos (2000.0 * (80.0 + lat)) ^ "," ^ rtos (2000.0 * (1.0 - (lon - 40.0))) ^ " ")) coords;
                  print "\"/>\n"
              end

      in
          print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
          print "<!-- Generator: PacTom.sml  -->\n";
          print "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\" [\n";
          print "<!ENTITY ns_flows \"http://ns.adobe.com/Flows/1.0/\">\n";
          print "]>\n";
          print "<svg version=\"1.1\"\n";
          print " xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n";
          print " xmlns:a=\"http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/\"\n";
          (* XXX *)
          print " x=\"0px\" y=\"0px\" width=\"263px\" height=\"243px\"\n";
          print " xml:space=\"preserve\">\n";
          app printpolyline (rev (!paths));
          print "</svg>\n"
      end
*)


end