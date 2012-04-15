structure Waypoints =
struct

  exception Waypoints of string

  (* Just a frame number for now *)
  type waypoint = unit

  structure IM = SplayMapFn(type ord_key = int
                            val compare = Int.compare)

  datatype waypoints =
      WP of { prefix : string,
              suffix : string,
              padto : int,
              start : int ref,
              num : int ref,
              points : waypoint IM.map ref }

  fun parsepoints ps =
      let val ps = String.tokens (fn #" " => true | _ => false) ps
          val ps = map Int.fromString ps

          fun folder (NONE, _) = raise Waypoints "non-numeric waypoint token?"
            | folder (SOME i, b) =
              IM.insert (b, i, ())
      in
          foldl folder IM.empty ps
      end

  fun renderpoints ps =
      let
          val l = IM.foldri (fn (i, (), l) => i :: l) nil ps
      in
          StringUtil.delimit " " (map Int.toString l)
      end

  fun loadfile f =
      let val { alist = _, lookup } = Script.alistfromfile f
          fun lookupint s = Option.join (Option.map Int.fromString (lookup s))

          val () =
               case lookup "type" of
                   SOME "frames" => ()
                 | SOME t => raise Waypoints ("Unknown waypoint type " ^ t)
                 | NONE => raise Waypoints "must specify waypoint types in file."
      in
          case (lookup "prefix", lookup "suffix",
                lookupint "padto", lookupint "start", lookupint "num") of
              (SOME prefix, SOME suffix, SOME padto, SOME start, SOME num) =>
               let
                   val p =
                       (case lookup "points" of
                            NONE => IM.empty
                          | SOME ps => parsepoints ps)
               in
                   WP { prefix = prefix, suffix = suffix, padto = padto,
                        start = ref start, num = ref num, points = ref p }
               end
            | _ => raise Waypoints ("Missing required fields in " ^ f)
      end

  fun savefile (WP { prefix, suffix, padto, start, num, points }) f =
      let
      in
          StringUtil.writefile f
          ("type frames\n" ^
           "prefix " ^ prefix ^ "\n" ^
           "suffix " ^ suffix ^ "\n" ^
           "padto " ^ Int.toString padto ^ "\n" ^
           "start " ^ Int.toString (!start) ^ "\n" ^
           "num " ^ Int.toString (!num) ^ "\n" ^
           "points " ^ renderpoints (!points) ^ "\n")
      end

  fun setwaypoint (WP { points, ... }) i =
      points := IM.insert (!points, i, ())

  fun clearwaypoint (WP { points, ... }) i =
      points := #1 (IM.remove (!points, i)) handle _ => ()

  fun iswaypoint (WP { points, ... }) i =
      case IM.find (!points, i) of
          NONE => false
        | SOME () => true

  fun prevwaypoint (wp as WP { num = ref num, ... }) i =
      let
          fun pw i =
              if i - 1 >= 0
              then if iswaypoint wp (i - 1)
                   then i - 1
                   else pw (i - 1)
              else i
      in
          pw i
      end

  fun nextwaypoint (wp as WP { num = ref num, ... }) i =
      let
          fun nw i =
              if i + 1 < num
              then if iswaypoint wp (i + 1)
                   then i + 1
                   else nw (i + 1)
              else i
      in
          nw i
      end

  fun firstwaypoint wp =
      if iswaypoint wp 0
      then 0
      else nextwaypoint wp 0

  fun prefix (WP { prefix, ... }) = prefix
  fun suffix (WP { suffix, ... }) = suffix
  fun padto (WP { padto, ... }) = padto
  fun start (WP { start, ... }) = !start
  fun num (WP { num, ... }) = !num
  fun points (WP { points, ... }) = IM.foldri (fn (i, (), l) => i :: l) nil (!points)

end