(* Utilities for PacTom activities. *)
structure PacTom :> PACTOM = 
struct 

  exception PacTom of string

  datatype tree = datatype XML.tree

  (* XXX add some stuff. *)
  type pactom = { xmls : tree list,
                  overlays : { href : string, 
                               rotation : real, 
                               alpha : Word8.word,
                               north : real, south : real,
                               east : real, west : real } Vector.vector,
                  paths : (LatLon.pos * real) list Vector.vector }
  fun paths { xmls, paths, overlays } = paths
  fun overlays { xmls, paths, overlays } = overlays
  fun xmls { xmls, paths, overlays } = xmls

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

  fun fromkmlfiles fs =
    let
      val paths = ref nil
      val overlays = ref nil

      fun process (Elem(("coordinates", nil), [Text coordtext])) =
        let val coords = String.tokens (fn #" " => true | _ => false) coordtext
            val coords = 
                map (fn t =>
                     case String.fields (fn #"," => true | _ => false) t of
                       [long, lat, elev] =>
                         (case (Real.fromString long, 
                                Real.fromString lat, 
                                Real.fromString elev) of
                              (SOME long, SOME lat, SOME elev) => 
                                  (LatLon.fromdegs {lat = lat, lon = long}, elev)
                            | _ => raise PacTom ("non-numeric lat/lon/elev: " ^ 
                                                 long ^ "," ^ lat ^ "," ^ elev))
                     | _ => raise PacTom ("bad coord token: " ^ t)) coords
        in
            paths := coords :: !paths
        end
      | process (Elem(("coordinates", _), _)) = 
        raise PacTom "coordinates with subtags or attrs?"
      | process (t as Elem(("GroundOverlay", _), _)) =
        let
            (* name and description are there, but we don't need them for this
               purpose (?).

               color has an alpha component as the first two hex
                 digits. If it's not specified, assume FFFFFF.
               href is the location of the graphic file.
               viewBoundScale is always 0.75?
               north, south, east, west specify the bounding box 
                 parallels and meridians.
               rotation specifies the degrees of rotation -180 to 180,
                 where 0 is north and 90 is west. *)
            val leaves = XML.getleaves t

            fun findoneopt tag = 
                case ListUtil.Alist.find op= leaves tag of
                    (* XXX are there any sensible defaults, like 0 for rotation? *)
                    NONE => NONE
                  | SOME [v] => SOME v
                  | SOME nil => raise PacTom "impossible"
                  | SOME _ => raise PacTom ("GroundOverlay specified more than one " ^ tag)

            fun findone tag =
                case findoneopt tag of
                    NONE => raise PacTom ("GroundOverlay didn't specify " ^ tag)
                  | SOME v => v

            fun findoner tag = 
                let val v = findone tag
                in
                    case Real.fromString v of
                        NONE => raise PacTom ("Non-numeric " ^ tag ^ 
                                              " in GroundOverlay: " ^ v)
                      | SOME r => r
                end

            val href = findone "href"
            val north = findoner "north"
            val south = findoner "south"
            val east = findoner "east"
            val west = findoner "west"
            val rotation = 
                case findoneopt "rotation" of
                    NONE => 0.0
                  | SOME s => 
                        case Real.fromString s of
                            NONE => raise PacTom 
                                ("Non-numeric rotation in GroundOverlay: " ^ s)
                          | SOME r => r
            val color = 
                case findoneopt "color" of
                    NONE => "ffffffff"
                  | SOME c => c
            val alpha =
                case Color.onefromhexstring (String.substring(color, 0, 2)) of
                    NONE => raise PacTom ("bad color: " ^ color)
                  | SOME w => w
(*
          <name>Lincoln place - Mifflin Rd Park</name>
          <description>dirt lot with Jersey barriers. Looks like it might have formerly been a parking lot?</description>
          <color>cfffffff</color>
          <Icon>
                  <href>C:/old-f/pictures/pac tom/not-a-road.png</href>
                  <viewBoundScale>0.75</viewBoundScale>
          </Icon>
          <LatLonBox>
                  <north>40.37134954421344</north>
                  <south>40.37107590394126</south>
                  <east>-79.91349939576577</east>
                  <west>-79.91547483878412</west>
                  <rotation>-46.49832619008645</rotation>
          </LatLonBox>
*)
        in
            overlays := { href = href, 
                          north = north, south = south, 
                          east = east, west = west, 
                          alpha = alpha,
                          rotation = rotation } :: !overlays
        end
      | process (e as Text _) = ()
      | process (Elem(t, tl)) = app process tl

      val xs = map (fn f =>
                    let val x = XML.parsefile f 
                        handle XML.XML s => 
                            raise PacTom ("Couldn't parse " ^ f ^ "'s xml: " ^ s)
                    in
                        process x;
                        x
                    end) fs
    in
        { xmls = xs, 
          overlays = Vector.fromList (rev (!overlays)), 
          paths = Vector.fromList (rev (!paths)) }
    end

  fun fromkmlfile f = fromkmlfiles [f]

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

  fun projectpaths proj pt =
      let
          val paths = paths pt
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

end