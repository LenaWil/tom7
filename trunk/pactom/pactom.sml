(* Utilities for PacTom activities. *)
structure PacTom :> PACTOM = 
struct 

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  exception PacTom of string
  open Bounds

  datatype tree = datatype XML.tree

  (* XXX add some stuff. *)
  type pactom = { xmls : tree list,
                  overlays : { href : string, 
                               rotation : real, 
                               alpha : Word8.word,
                               north : real, south : real,
                               east : real, west : real } Vector.vector,
                  paths : (LatLon.pos * real) Vector.vector Vector.vector }
  fun paths { xmls, paths, overlays } = paths
  fun overlays { xmls, paths, overlays } = overlays
  fun xmls { xmls, paths, overlays } = xmls

  type neighborhoods = (string * LatLon.pos Vector.vector) Vector.vector

  val home = LatLon.fromdegs { lat = 40.452911, lon = ~79.936313 }

  val seed = MersenneTwister.init32 0wxDEADBEEF
  fun rand () = MersenneTwister.rand32 seed

  fun ++r = r := 1 + !r

  fun fromkmlfiles fs =
    let
      val paths = ref nil
      val overlays = ref nil

      fun process (Elem(("coordinates", nil), [Text coordtext])) =
        let val coords = String.tokens (StringUtil.charspec " \t\r\n") coordtext
            val coords = 
                map (fn t =>
                     case map Real.fromString
                         (String.fields (Util.is #",") t) of
                       [SOME lon, SOME lat, SOME elev] =>
                           (LatLon.fromdegs {lat = lat, lon = lon}, elev)
                     | _ => raise PacTom ("non-numeric lat/lon/elev: '" ^ t ^
                                          "'")) coords
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
          <description>dirt lot with Jersey barriers. 
            Looks like it might have formerly been a parking lot?</description>
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
          paths = Vector.map Vector.fromList (Vector.fromList (rev (!paths))) }
    end

  structure IntMap = SplayMapFn(type ord_key = int
                                val compare = Int.compare)
  datatype highway =
      Residential
    | Primary
    | Secondary
    | Tertiary
    | Service
    | Steps
    | Foot
    | Motorway
    | MotorwayLink
    | Unclassified
    | Other of string

  fun highway_compare (l, r) =
      case (l, r) of
          (Residential, Residential) => EQUAL
        | (Residential, _) => LESS
        | (_, Residential) => GREATER
        | (Primary, Primary) => EQUAL
        | (Primary, _) => LESS
        | (_, Primary) => GREATER
        | (Secondary, Secondary) => EQUAL
        | (Secondary, _) => LESS
        | (_, Secondary) => GREATER
        | (Tertiary, Tertiary) => EQUAL
        | (Tertiary, _) => LESS
        | (_, Tertiary) => GREATER
        | (Service, Service) => EQUAL
        | (Service, _) => LESS
        | (_, Service) => GREATER
        | (Steps, Steps) => EQUAL
        | (Steps, _) => LESS
        | (_, Steps) => GREATER
        | (Foot, Foot) => EQUAL
        | (Foot, _) => LESS
        | (_, Foot) => GREATER
        | (Motorway, Motorway) => EQUAL
        | (Motorway, _) => LESS
        | (_, Motorway) => GREATER
        | (MotorwayLink, MotorwayLink) => EQUAL
        | (MotorwayLink, _) => LESS
        | (_, MotorwayLink) => GREATER
        | (Unclassified, Unclassified) => EQUAL
        | (Unclassified, _) => LESS
        | (_, Unclassified) => GREATER
        | (Other s1, Other s2) => String.compare (s1, s2)

  fun highwayfromstring tys =
      case tys of
          "residential" => Residential
        | "primary" => Primary
        | "secondary" => Secondary
        | "tertiary" => Tertiary
        | "service" => Service
        | "steps" => Steps
        | "foot" => Foot
        | "motorway" => Motorway
        | "motorway_link" => MotorwayLink
        | "unclassified" => Unclassified
        | _ => Other tys

  type street = { pts : int Vector.vector, typ : highway, name : string option }
  structure StreetSet = SplaySetFn(type ord_key = street
                                   val compare : street Util.orderer =
                                       Util.lexicographic
                                       [Util.order_field #pts (Util.lex_vector_order Int.compare),
                                        Util.order_field #typ highway_compare,
                                        Util.order_field #name (Util.option_compare String.compare)])
  structure StreetSetUtil = SetUtil(structure S = StreetSet)

  type osm = { points : LatLon.pos IntMap.map,
               streets : street Vector.vector }

  fun loadosms fl =
    let
      val bad_node = ref 0
      val not_highway = ref 0
      val empty_way = ref 0
      val num_points = ref 0
      val num_streets = ref 0
      val overlap_points = ref 0
      val points = ref (IntMap.empty : LatLon.pos IntMap.map)
      val streets = ref StreetSet.empty

      fun onefile f =
        let
          val x = XML.parsefile f 
              handle XML.XML s => 
                  raise PacTom ("Couldn't parse " ^ f ^ "'s xml: " ^ s)

          fun isway (Elem(("nd", _), _) :: l) = true
            | isway (_ :: rest) = isway rest
            | isway nil = false

          fun getattr attrs k = ListUtil.Alist.find op= attrs k
              
          fun gettag k nil = NONE
            | gettag k (Elem(("tag", attrs), _) :: l) =
              (case getattr attrs "k" of
                   NONE => gettag k l
                 | SOME keyname =>
                       if keyname = k
                       then (case getattr attrs "v" of
                                 NONE => (* error? *) gettag k l
                               | SOME v => SOME v)
                       else gettag k l)
            | gettag k (_ :: l) = gettag k l

          (* XXX need to filter out streets whose points are never loaded. *)

          fun process (Elem(("node", attrs), body)) =
              (case (getattr attrs "id", getattr attrs "lat", getattr attrs "lon") of
                   (SOME id, SOME lat, SOME lon) =>
                       (case (Int.fromString id, Real.fromString lat, Real.fromString lon) of
                            (SOME id, SOME lat, SOME lon) =>
                                (case IntMap.find(!points, id) of
                                     NONE => 
                                         (++num_points;
                                          points := IntMap.insert(!points, id, 
                                                                  LatLon.fromdegs { lat = lat,
                                                                                    lon = lon }))
                                   | SOME _ => ++overlap_points)
                          | _ => raise PacTom "non-numeric id/lat/lon??")
                 | _ => ++bad_node)
            | process (Elem(("way", attrs), body)) =
                   if isway body
                   then (case gettag "highway" body of
                             NONE => ++not_highway
                           | SOME tys => 
                                 let
                                     val pts = ref nil
                                     fun proc (Elem(("nd", [("ref", s)]), _)) =
                                         (case Int.fromString s of
                                              NONE => raise PacTom "non-numeric nd ref?"
                                            | SOME i => pts := i :: !pts)
                                       | proc _ = ()
                                 in
                                     app proc body;
                                     ++num_streets;
                                     streets :=
                                     StreetSet.add(!streets,
                                                   { pts = Vector.fromList (rev (!pts)),
                                                     typ = highwayfromstring tys,
                                                     name = gettag "name" body })
                                 end)
                   else ++empty_way
            (* nb. whole thing is in an <osm> tag. Should descend under that
               and then expect these all to be top-level, rather than recursing *)
            | process (Elem((_, _), body)) = app process body
            | process _ = ()
        in
            process x
        end

      val () = app onefile fl
      val streets = Vector.fromList (StreetSetUtil.tolist (!streets))
    in
        TextIO.output(TextIO.stdErr,
                      "OSM files:      " ^ Int.toString (length fl) ^ "\n" ^
                      "Bad nodes:      " ^ Int.toString (!bad_node) ^ "\n" ^
                      "Not highway:    " ^ Int.toString (!not_highway) ^ "\n" ^
                      "Empty way:      " ^ Int.toString (!empty_way) ^ "\n" ^
                      "Streets seen:   " ^ Int.toString (!num_streets) ^ "\n" ^
                      "Unique streets: " ^ Int.toString (Vector.length streets) ^ "\n" ^
                      "Points:         " ^ Int.toString (!num_points) ^ "\n" ^
                      "Repeated pts:   " ^ Int.toString (!overlap_points) ^ "\n");
        { points = !points, streets = streets }
    end

  fun loadosm f = loadosms [f]
      
  fun fromkmlfile f = fromkmlfiles [f]

  fun neighborhoodsfromkml f =
    let
        val polys = ref nil

        (* XXX: need pointwise for xml *)
        fun eachplacemark (Elem(("Placemark", nil), tl)) =
            let
                val name = ref NONE
                fun findname (Elem(("name", nil), [Text n])) = 
                    (case !name of
                         NONE => name := SOME n
                       | SOME nn => 
                             raise PacTom ("multiple names for placemark: " ^
                                           nn ^ " and " ^ n))
                  | findname (Elem(("name", _), _)) =
                         raise PacTom "name with subtags or attributes?"
                  | findname (Elem(t, tl)) = app findname tl
                  | findname (Text _) = ()

                fun findcoords (Elem(("coordinates", nil), [Text coordtext])) =
                    let 
                        val coords = String.tokens (Util.is #" ") coordtext
                        val coords = 
                            map (fn t =>
                                 case map Real.fromString (String.fields (Util.is #",") t) of
                                     [SOME lon, SOME lat, SOME _] => LatLon.fromdegs {lon = lon, lat = lat}
                                   | _ => raise PacTom ("non-numeric lat/lon/elev: " ^ t)) coords
                    in
                        case !name of
                            NONE => raise PacTom "no name preceding coordinates!"
                          | SOME name => polys := (name, coords) :: !polys
                    end
                  | findcoords (Elem(("coordinates", _), _)) = 
                    raise PacTom "coordinates with subtags or attrs?"
                  | findcoords (Text _) = ()
                  | findcoords (Elem(_, tl)) = app findcoords tl

            in
                app findname tl;
                app findcoords tl
            end
          | eachplacemark (Elem(("Placemark", _), _)) =
            raise PacTom "Didn't expect attributes on placemark"
          | eachplacemark (Text _) = ()
          | eachplacemark (Elem(_, tl)) = app eachplacemark tl

        val x = XML.parsefile f 
            handle XML.XML s => 
                raise PacTom ("Couldn't parse " ^ f ^ "'s xml: " ^ s)
        val () = eachplacemark x

        val () = TextIO.output (TextIO.stdErr, "Snap neighborhoods...\n")
        val start = Time.now ()
        (* XXX PERF this is crazy slow!! *)
        (* XXX snap distance needs to be tuned. *)
        val polys = SnapLatLon.snap 5.0 (!polys)
    in
        TextIO.output (TextIO.stdErr, 
                       " ... Done in " ^ 
                       LargeInt.toString (Time.toSeconds (Time.-(Time.now(), start))) ^ 
                       " sec\n");
        Vector.fromList (ListUtil.mapsecond Vector.fromList polys)
    end

  fun projecthoods projection (hoods : neighborhoods) :
      { borders : (string * (real * real) Vector.vector) Vector.vector,
        bounds : Bounds.bounds } =
      let
          val bounds = Bounds.nobounds ()
          val hoods = 
              Vector.map (fn (name, poly) => (name, Vector.map projection poly)) hoods

(*
      val f = TextIO.openOut "neighborhoods-locator-test.svg"
          (* XXX needs massive scaling! Also, conversion to x/y. *)
      val () = PointLocation.tosvg (PointLocation.locator scaled) 
                                   (fn s => TextIO.output (f, s))
      val () = TextIO.closeOut f
*)

    in
        Vector.app (fn (_, poly) => Vector.app (Bounds.boundpoint bounds) poly) hoods;
        { borders = hoods, bounds = bounds }
    end

  (* always alpha 1.0 *)
  fun randomanycolor () = 
      StringUtil.padex #"0" ~6 (Word32.toString (rand()))

  (* Same value and saturation, different hue. *)
  fun randombrightcolor () =
      Color.tohexstring (Color.hsvtorgb 
                         (Word8.fromInt 
                          (Word32.toInt (Word32.andb(Word32.>>(rand (), 0w7), 0wxFF))),
                          0wxFF,
                          0wxFF))

  fun randompalecolor () =
      Color.tohexstring (Color.hsvtorgb 
                         (Word8.fromInt 
                          (Word32.toInt (Word32.andb(Word32.>>(rand (), 0w7), 0wxFF))),
                          0wx33,
                          0wxAA))


  (* No exponential notation *)
  fun ertos r = if (r > ~0.000001 andalso r < 0.000001) 
                then "0.0" 
                    (* XXX using 8 for kml, was 4 for svg *)
                else (Real.fmt (StringCvt.FIX (SOME 8)) r)

  (* Don't use SML's dumb ~ *)
  fun rtos r = if r < 0.0 
               then "-" ^ ertos (0.0 - r)
               else ertos r


  fun projectpaths proj pt =
      let
          val paths = paths pt
          val b = Bounds.nobounds ()
              
          val paths = Vector.map (Vector.map (fn (p, z) =>
                                              let val (x, y) = proj p
                                              in boundpoint b (x, y);
                                                 (x, y, z)
                                              end)) paths
      in
          { paths = paths, bounds = b }
      end

  type waypoint = { path : int, pt : int }

  structure G = RealUndirectedGraph

  fun latlontree ({ paths, ... } : pactom) =
      let
          (* First get all points so that we can shuffle them. LatLontree is
             sensitive to insertion order, and definitely sucks with
             close-by, roughly horizontal or linear paths, which are
             rife in the input *)

          val all = ref (nil : ({ path : int, pt : int } * LatLon.pos) list)
          fun addpath (path_idx, points) =
              let
                  fun addpoint (point_idx, (pos, elev)) =
                      all := ({ path = path_idx, pt = point_idx }, pos) :: !all
              in
                  Vector.appi addpoint points
              end

          val () = Vector.appi addpath paths
          val all_a = Array.fromList (!all)
      in
          MersenneTwister.shuffle seed all_a;
          Array.foldl (fn ((way, pos), t) => LatLonTree.insert t way pos) 
                      LatLonTree.empty 
                      all_a
      end

  (* If points on the same path are greater than 50m apart, assume a
     data problem and don't create that edge. *)
  val PATH_ERROR_M = 250.0
  (* Distance within which we create an implicit edge between nearby
     points, even if I didn't physically travel between them *)
  val MERGE_DISTANCE_M = 25.0

  (* Waypoints might literally be on top of one another. We should really
     be merging them, but that's pretty tricky, so add a tiny distance. *)
  val EPSILON = 0.0000001 (* 1mm *)

  fun wtos { path, pt } = Int.toString path ^ "." ^ Int.toString pt

  fun graph (pactom as { paths, ... } : pactom) =
      let
          val g : waypoint G.graph = G.empty ()

          (* First, insert all nodes. *)
          fun pointstonodes (path_idx, points) =
              Vector.mapi (fn (point_idx, (pos, elev)) =>
                           G.add g { path = path_idx, pt = point_idx }) points
          val nodepaths = Vector.mapi pointstonodes paths
          fun waynode { path, pt } = Vector.sub(Vector.sub (nodepaths, path), pt)
          fun wayloc { path, pt } = Vector.sub(Vector.sub (paths, path), pt)

          (* distance in meters between waypoints. *)
          fun waypoint_distance (w1, w2) =
              let
                  val (pos1, elev1) = wayloc w1
                  val (pos2, elev2) = wayloc w2
              in
                  LatLon.dist_meters (pos1, pos2)
              end

          fun addnewedge (w1, w2) = 
              if w1 = w2
              then false
              else
                let
                    val n1 = waynode w1
                    val n2 = waynode w2
                in
                    case G.hasedge n1 n2 of
                        NONE => 
                            let
                                val d = waypoint_distance (w1, w2)
                            in
                                case Real.compare (d, 0.0) of
                                    LESS =>
                                        raise PacTom ("Distance less than 0? " ^
                                                      wtos w1 ^ " -> " ^ wtos w2 ^ ": " ^
                                                      Real.toString d ^ "m\n")
                                  | EQUAL => (G.addedge n1 n2 EPSILON; true)
                                  | GREATER => (G.addedge n1 n2 d; true)
                            end
                      | SOME _ => false
                end

          (* If they're on the same path, then they're mutually reachable.
             We filter out data problems, like jumps of more than several hundred
             meters. *)
          (* PERF: Every time we call this we already have the distance. *)
          fun addpath (path_idx, path) =
              Util.for 0 (Vector.length path - 2)
              (fn point_idx =>
               let
                   val w1 = { path = path_idx, pt = point_idx }
                   val w2 = { path = path_idx, pt = point_idx + 1 }
               in
                   if waypoint_distance (w1, w2) <= PATH_ERROR_M
                   then ignore (addnewedge (w1, w2))
                   else
                       msg ("Consecutive waypoint distance exceeds maximum: " ^
                            wtos w1 ^ " -> " ^ wtos w2 ^ ": " ^
                            Real.fmt (StringCvt.FIX (SOME 3)) 
                            (waypoint_distance (w1, w2)))
               end)
          val () = Vector.appi addpath paths

          (* Now, add adjacencies. *)
          val t = latlontree pactom
              
          (* XXX this should actually work by looking at line segments and
             intersecting them. What we do here "cuts corners", literally. *)
          val nlinked = ref 0
          fun addclosepath (path_idx, path) =
              let
                  val theselinked = ref 0
                  fun addclosepoint (point_idx, _) =
                      let val way = { path = path_idx, pt = point_idx }
                          val adj = LatLonTree.lookup t (#1 (wayloc way)) MERGE_DISTANCE_M
                      in
                          app (fn neighbor =>
                               if addnewedge (way, neighbor)
                               then theselinked := !theselinked + 1
                               else ()) adj
                      end
              in
                  Vector.appi addclosepoint path;
                  msg (Int.toString path_idx ^ " / " ^
                       Int.toString (Vector.length paths) ^ " : " ^
                       Int.toString (!theselinked));
                  (* Should warn if the path was not linked in at all.
                     But this count won't do it... *)
                  nlinked := !nlinked + !theselinked
              end
              
          val () = Vector.appi addclosepath paths
          val () = msg ("Added " ^ Int.toString (!nlinked) ^ " merged edges")
      in
          { graph = g, promote = waynode, latlontree = t }
      end

(*
  fun simplified_graph (pactom : pactom) =
*)      

  fun spanning_graph (pactom : pactom) (rootnear : LatLon.pos) :
      { graph : waypoint G.span G.graph,
        promote : waypoint -> waypoint G.span G.node } =
      let
          (* Create graph. We don't need the graph itself, because we
             compute the shortest path graph using the node (which is
             associated with this graph) closest to home. *)
          val { graph = _, latlontree, promote = ur_p } = graph pactom
          val (way_root, root_dist) = 
              case LatLonTree.closestpoint latlontree rootnear of
                  NONE => raise PacTom "There are no points! Can't continue."
                | SOME p => p
          val () = msg ("The closest point to the root is " ^ 
                        Real.fmt (StringCvt.FIX (SOME 3)) root_dist ^ "m away")
          val root_node = ur_p way_root
          val { graph = shortest_g, promote = shortest_p } = G.shortestpaths root_node 
          (* XXX with this graph, could make a histogram of road-distance from home *)
          val { graph = span_g, promote = span_p } = G.spanningtree shortest_g
      in
          { graph = span_g, promote = span_p o shortest_p o ur_p }
      end

end
