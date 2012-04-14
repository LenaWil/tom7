structure Waypoints =
struct

  exception Waypoints of string

  (* Just a frame number for now *)
  type waypoint = int

  datatype waypoints =
      WP of { prefix : string,
              suffix : string,
              padto : int,
              start : int ref,
              num : int ref,
              points : waypoint list ref }

  fun parsepoints ps =
      let val ps = String.tokens (fn #" " => true | _ => false) ps
          val ps = map Int.fromString ps
      in
          map (fn NONE => raise Waypoints "non-numeric waypoint token?"
                | SOME i => i) ps
      end

  fun loadfile f =
      let val { alist, lookup } = Script.alistfromfile f
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
                       ListUtil.sort Int.compare
                       (case lookup "points" of
                            NONE => []
                          | SOME ps => parsepoints ps)
               in
                   WP { prefix = prefix, suffix = suffix, padto = padto,
                        start = ref start, num = ref num, points = ref p }
               end
            | _ => raise Waypoints ("Missing required fields in " ^ f)
      end

  fun prefix (WP { prefix, ... }) = prefix
  fun suffix (WP { suffix, ... }) = suffix
  fun padto (WP { padto, ... }) = padto
  fun start (WP { start, ... }) = !start
  fun num (WP { num, ... }) = !num
  fun points (WP { points, ... }) = !points

end