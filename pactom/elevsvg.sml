(* Convert GPS trails in a KML file to SVG paths. *)
structure ToSVG = 
struct 

  exception ToSVG of string

  (* XX Port to PacTom struct *)
  val x = XML.parsefile "pac.kml" (* "rct.kml" *)
      handle (e as (XML.XML s)) => (print ("Error: " ^ s); raise e)

  datatype tree = datatype XML.tree

  val seed = ref (0wxDEADBEEF : Word32.word)

  val elev_max = ref ~99999.0
  val elev_min = ref 99999.0
  val paths = ref nil

  (* XXX use PacTom. *)
  fun process (Elem(("coordinates", nil), [Text coordtext])) =
      let val coords = String.tokens (fn #" " => true | _ => false) coordtext
          val coords = 
              map (fn t =>
                   case String.fields (fn #"," => true | _ => false) t of
                       [lon, lat, elev] =>
                           (case (Real.fromString lat, 
                                  Real.fromString lon,
                                  Real.fromString elev) of
                                (SOME lat, SOME lon, SOME elev) => (lat, lon, elev)
                              | _ => raise ToSVG ("non-numeric lat/lon/elev: " ^ 
                                                  lat ^ "," ^ lon ^ "," ^ elev))
                     | _ => raise ToSVG ("bad coord token: " ^ t)) coords

          (* XXX shown in reverse... *)
          val coords = rev coords

          fun go _ _ l nil = rev l
              (* previous location, distance so far in feet, reversed list 
                 of (dist feet, elev feet) pairs *)
            | go (plat, plon, pelev) d l ((lat, lon, elev) :: rest) =
              let
                  val elevfeet = elev * 3.2808399
                  val efeet = 
                      (* XXX numeric under/overflow issues. nan check is just a bandaid.
                         Should probably use a different method when the points are 
                         close on the sphere, which will be the usual case in this
                         code... *)
                      let val f = LatLon.dist_feet 
                          (LatLon.fromdegs { lat = plat, lon = plon },
                           LatLon.fromdegs { lat = lat,  lon = lon })
                      in
                          if Real.isNan f
                          then 0.0
                          else f
                      end
                  val zfeet = elev - pelev
                  (* Compute the actual distance traveled in feet *)
                  (* val dist = Math.sqrt (efeet * efeet + zfeet * zfeet) *)
                  val dist = efeet
              in
                  if elevfeet > !elev_max
                  then elev_max := elevfeet
                  else ();
                  if elevfeet < !elev_min
                  then elev_min := elevfeet
                  else ();
                  go (lat, lon, elevfeet) (d + dist) ((d + dist, elevfeet) :: l) rest
              end
          val cs = 
              case coords of
                  nil => nil
                | (lat, long, elev) :: rest => 
                      (0.0, elev * 3.2808399) :: 
                      go (lat, long, elev * 3.2808399) 0.0 nil rest
      in
          paths := cs :: !paths
      end
    | process (Elem(("coordinates", _), _)) = 
      raise ToSVG "coordinates with subtags or attrs?"
    | process (e as Text _) = ()
    | process (Elem(t, tl)) = app process tl

  val () = process x

  fun ertos r = if (r > ~0.000001 andalso r < 0.000001) 
                then "0.0" 
                else (Real.fmt (StringCvt.FIX (SOME 4)) r)
  fun rtos r = if r < 0.0 
               then "-" ^ ertos (0.0 - r)
               else ertos r

  fun xaxis x = x / 20.0
  fun yaxis y = (1200.0 - y) / 2.0
  val () =
      let 
          fun printpolyline coords =
              let in
                  print ("<polyline fill=\"none\" style=\"stroke-opacity:0.10\" " ^
                         "stroke=\"#273577\" stroke-width=\"1\" points=\""); (* " *)
                  app (fn (dist, elev) => print (rtos (xaxis dist) ^ "," ^ 
                                                 rtos (yaxis elev) ^ " ")) coords;
                  print "\"/>\n"
              end

          fun printxkey 26 = ()
            | printxkey n =
              let in
                  print ("<polyline fill=\"none\" stroke=\"#777777\" " ^
                         "stroke-width=\"0.75\" points=\"" ^
                         rtos (xaxis (real n * 5280.0)) ^ "," ^ 
                         rtos (yaxis (!elev_min - 41.0)) ^ " " ^
                         rtos (xaxis (real n * 5280.0)) ^ "," ^ 
                         rtos (yaxis (!elev_min - 7.0)) ^
                         "\"/>\n");
                  print ("<text x=\"" ^ rtos (xaxis (real n * 5280.0 - 20.0)) ^ "\" " ^
                         "y=\"" ^ rtos (yaxis (!elev_min - 74.0)) ^ "\" " ^
                         "style=\"font-size:12px;fill:#777777;font-family:Helvetica\" " ^
                         "xml:space=\"preserve\">" ^
                         Int.toString n ^ "</text>\n");
                  printxkey (n + 1)
              end

          fun printykey n =
              if real n > !elev_max
              then ()
              else
              let in
                  print ("<polyline fill=\"none\" stroke=\"#777777\" " ^
                         "stroke-width=\"0.75\" points=\"" ^
                         rtos (xaxis ~500.0) ^ "," ^ rtos (yaxis (real n)) ^ " " ^
                         rtos (xaxis ~300.0) ^ "," ^ rtos (yaxis (real n)) ^
                         "\"/>\n");
                  print ("<text x=\"" ^ rtos (xaxis ~1200.0) ^ "\" " ^
                         "y=\"" ^ rtos (yaxis (real (n + 10))) ^ "\" " ^
                         "style=\"font-size:10px;fill:#777777;font-family:Helvetica\" " ^
                         "xml:space=\"preserve\">" ^ (* " *)
                         Int.toString n ^ "</text>\n");
                  printykey (n + 20)
              end

      in
          (* XXX compute actual size *)
          print (TextSVG.svgheader { x = 0, y = 0, width = 264, height = 243,
                                     generator = "elevsvg.sml" });

          app printpolyline (rev (!paths));
          printxkey 0;
          printykey (Real.trunc (!elev_min - 10.0));

          print (TextSVG.svgfooter ())
      end

end