(* Convert GPS trails in a KML file to SVG paths. *)
structure ToSVG = 
struct 

  exception ToSVG of string

  val x = XML.parsefile "pactom.kml"
      handle (e as (XML.XML s)) => (print ("Error: " ^ s); raise e)

  datatype tree = datatype XML.tree

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

  val seed = ref (0wxDEADBEEF : Word32.word)
      
  fun rand () =
      let in
          seed := !seed + 0wx23456789;
          seed := !seed * 0w31337;
          seed := Word32.mod(!seed, 0w477218579);
          seed := Word32.xorb(!seed, 0w331171895);
          Word32.andb(!seed, 0wxFFFFFF)
      end

  (* always alpha 1.0 *)
  fun randomanycolor () = 
      "ff" ^ StringUtil.padex #"0" ~6 (Word32.toString (rand()))

  (* Same value and saturation, different hue. *)
  fun randomcolor () =
      Color.tohexstring (Color.hsvtorgb 
                         (Word8.fromInt (Word32.toInt (Word32.andb(Word32.>>(rand (), 0w7), 0wxFF))),
                          0wxFF,
                          0wxFF))

  val paths = ref nil

  fun process (Elem(("coordinates", nil), [Text coordtext])) =
      let val coords = String.tokens (fn #" " => true | _ => false) coordtext
          val coords = map (fn t =>
                            case String.fields (fn #"," => true | _ => false) t of
                                [lat, long, elev] =>
                                    (case (Real.fromString lat, Real.fromString long, Real.fromString elev) of
                                         (SOME lat, SOME long, SOME elev) => (lat, long, elev)
                                       | _ => raise ToSVG ("non-numeric lat/lon/elev: " ^ lat ^ "," ^ long ^ "," ^ elev))
                              | _ => raise ToSVG ("bad coord token: " ^ t)) coords

          (* XXX shown in reverse... *)
          val coords = rev coords

          fun go _ _ l nil = rev l
              (* previous location, distance so far in feet, reversed list of (dist feet, elev feet) pairs *)
            | go (plat, plon, pelev) d l ((lat, lon, elev) :: rest) =
              let
                  (* this is not technically correct because lat/lon distances are not isotropic. But within
                     the Pittsburgh area the error will be very tiny; much less than the GPS error. *)
                  (* At this scale .02 degrees longitude is 66,715 inches. *)
                  (* ... and .01 degrees latitude is 43,682 inches. *)
                  val xfeet = (lon - plon) * 100.0 * (43682.0 / 12.0)
                  val yfeet = (lat - plat) *  50.0 * (66715.0 / 12.0)
                  val zfeet = elev - pelev
                  (* Compute the actual distance traveled in feet *)
                  val dist = Math.pow (xfeet * xfeet + yfeet * yfeet + zfeet * zfeet, 1.0 / 3.0)
              in
                  go (lat, lon, elev) (d + dist) ((d + dist, elev) :: l) rest
              end
          val cs = 
              case coords of
                  nil => nil
                | (lat, long, elev) :: rest => (0.0, elev) :: go (lat, long, elev) 0.0 nil rest
      in
          paths := cs :: !paths
      end
    | process (Elem(("coordinates", _), _)) = raise ToSVG "coordinates with subtags or attrs?"
    | process (e as Text _) = ()
    | process (Elem(t, tl)) = app process tl

  val () = process x

  fun ertos r = if (r > ~0.000001 andalso r < 0.000001) then "0.0" else Real.toString r
  fun rtos r = if r < 0.0 
               then "-" ^ ertos (1.0 - r)
               else ertos r

  val () =
      let 
          fun printpolyline coords =
              let in
                  print ("<polyline fill=\"none\" stroke=\"#" ^ randomcolor() ^ "\" stroke-width=\"1\" points=\""); (* " *)
                  app (fn (dist, elev) => print (rtos (dist / 10.0) ^ "," ^ rtos elev ^ " ")) coords;
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
          app printpolyline (rev (!paths));
          print "</svg>\n"
      end



end