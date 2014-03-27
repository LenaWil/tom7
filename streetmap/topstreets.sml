
structure TopStreets =
struct

  exception TopStreets of string

  datatype tree = datatype XML.tree
  fun ++r = r := (1 + !r : IntInf.int)

  structure IntMap = SplayMapFn(type ord_key = IntInf.int
                                val compare = IntInf.compare)
  structure StringMap = SplayMapFn(type ord_key = string
                                   val compare = String.compare)

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

  type street = { (* pts : IntInf.int Vector.vector, *) typ : highway, name : string }
  structure StreetSet = SplaySetFn(type ord_key = street
                                   val compare : street Util.orderer =
                                       Util.lexicographic
                                       [(* Util.order_field #pts (Util.lex_vector_order IntInf.compare), *)
                                        Util.order_field #typ highway_compare,
                                        Util.order_field #name String.compare])
  structure StreetSetUtil = SetUtil(structure S = StreetSet)

  type osm = { points : LatLon.pos IntMap.map,
               streets : street Vector.vector }

  fun increment m k =
    case StringMap.find (m, k) of
      NONE => StringMap.insert (m, k, 1)
    | SOME n => StringMap.insert (m, k, n + 1)

  fun loadosm state f =
    let
      val bad_node = ref 0
      val not_highway = ref 0
      val empty_way = ref 0
      val num_points = ref 0
      val num_streets = ref 0
      val overlap_points = ref 0
      val points = ref (IntMap.empty : LatLon.pos IntMap.map)
      val streets = ref StreetSet.empty
      val names = ref (StringMap.empty : IntInf.int StringMap.map)

      val () = print ("Parsing " ^ f ^ "...\n")
      val xml = XML.parsefile f
          handle XML.XML s =>
              raise TopStreets ("Couldn't parse " ^ f ^ "'s xml: " ^ s)

      val () = print "Parsed.\n"

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

      fun (* process (Elem(("node", attrs), body)) =
          (case (getattr attrs "id", getattr attrs "lat", getattr attrs "lon") of
               (SOME id, SOME lat, SOME lon) =>
                   (case (IntInf.fromString id, Real.fromString lat, Real.fromString lon) of
                        (SOME id, SOME lat, SOME lon) =>
                            (case IntMap.find(!points, id) of
                                 NONE =>
                                     (++num_points;
                                      points := IntMap.insert(!points, id,
                                                              LatLon.fromdegs { lat = lat,
                                                                                lon = lon }))
                               | SOME _ => ++overlap_points)
                      | _ => raise TopStreets "non-numeric id/lat/lon??")
             | _ => ++bad_node)
        |  *) process (Elem(("way", attrs), body)) =
               if isway body
               then (case gettag "highway" body of
                         NONE => ++not_highway
                       | SOME tys =>
                             let
                                 val pts = ref nil
                                 fun proc (Elem(("nd", [("ref", s)]), _)) =
                                     (case IntInf.fromString s of
                                          NONE => raise TopStreets "non-numeric nd ref?"
                                        | SOME i => pts := i :: !pts)
                                   | proc _ = ()
                                 val name = case gettag "name" body of
                                   NONE => ""
                                 | SOME s => s
                             in
                                 names := increment (!names) name;
                                 (* print ("Name: [" ^ name ^ "]\n") ; *)
                                 (* app proc body; *)
                                 ++num_streets;
                                               (*
                                 streets :=
                                 StreetSet.add(!streets,
                                               { (* pts = Vector.fromList (rev (!pts)), *)
                                                 typ = highwayfromstring tys,
                                                 name = name })
                                 *)
                                 ()
                             end)
               else ++empty_way
        (* nb. whole thing is in an <osm> tag. Should descend under that
           and then expect these all to be top-level, rather than recursing *)
        | process (Elem((_, _), body)) = app process body
        | process _ = ()

      val () = process xml

      val streets = Vector.fromList (StreetSetUtil.tolist (!streets))

      val namecount = ref (0 : IntInf.int)
      val fo = TextIO.openOut (state ^ "-counts.txt")
    in
      TextIO.output(TextIO.stdErr, "Writing names and counts...");
      StringMap.appi (fn (name, count) =>
                      let in
                        ++namecount;
                        TextIO.output (fo, IntInf.toString count ^ "\t" ^ name ^ "\n")
                      end) (!names);
      TextIO.closeOut fo;
      TextIO.output(TextIO.stdErr,
                    "Bad nodes:      " ^ IntInf.toString (!bad_node) ^ "\n" ^
                    "Not highway:    " ^ IntInf.toString (!not_highway) ^ "\n" ^
                    "Empty way:      " ^ IntInf.toString (!empty_way) ^ "\n" ^
                    "Streets seen:   " ^ IntInf.toString (!num_streets) ^ "\n" ^
                    "Unique names:   " ^ IntInf.toString (!namecount) ^ "\n" ^
                    "Points:         " ^ IntInf.toString (!num_points) ^ "\n" ^
                    "Repeated pts:   " ^ IntInf.toString (!overlap_points) ^ "\n");
        { points = !points, streets = streets }
    end

  fun run s = loadosm s (s ^ "-latest.osm")

end

val () = Params.main1 "Command-line argument: state name." TopStreets.run