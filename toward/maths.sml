(* Maths for codename: TOWARD. *)
structure Maths =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:

  structure GA = GrowArray

  type poly = vec2 GA.growarray
  type letter =
      (* Add graphics, ... *)
      { polys: poly GA.growarray }

  fun vertex p i = GA.sub p i
  fun previous_vertex p 0 = GA.sub p (GA.length p - 1)
    | previous_vertex p i = GA.sub p (i - 1)
  fun next_vertex p i = if i = GA.length p - 1
                        then GA.sub p 0
                        else GA.sub p (i + 1)

  (* Real-valued (num mod den), always positive. *)
  fun fmod (num, den) =
      let val r = Real.rem (num, den)
      in
          if r < 0.0 then r + den
          else r
      end

  (* Return the angle in degrees between v2->v1 and v2->v3,
     which is 360 - angle(v3, v2, v1). *)
  fun angle (v1, v2, v3) =
      (* Treating v2 as the center, we have
           p1
          /
         / phi1
         0--------x
         | phi3
         |
         p3
         *)
      let val p1 = v1 :-: v2
          val p3 = v3 :-: v2
          val phi1 = Math.atan2 (vec2y p1, vec2x p1)
          val phi3 = Math.atan2 (vec2y p3, vec2x p3)

          val degs = 57.2957795 * (phi1 - phi3)
      in
          fmod (degs, 360.0)
      end

  (* Test that every angle is less than 180 degrees using
     one winding order. (XXX Maybe we should actually insist on
     using a consistent winding order?) This does not need
     any other checks. Weird non-convex polygons like a star
     have "interior" angles that are all less than 180 degrees,
     but we use a consistent notion of interior in this code,
     so those angles appear to be large. *)
  fun issimple (p : poly) =
      let
          (* A polygon that's simple has exactly one winding
             order (clockwise or counter-clockwise) in which
             each interior angle is less than 180 degrees.
             Determine that winding order by choosing the
             one that makes an arbitrary angle less than
             180. *)
          (* XXX I guess I decided not to do it this way? *)
          val (forward, back) =
              if angle (previous_vertex p 0,
                        vertex p 0,
                        next_vertex p 0) < 180.0
              then (previous_vertex, next_vertex)
              else (next_vertex, previous_vertex)

          fun anglesum (s, i) =
              if i >= GA.length p
              then SOME s
              else
                  let val a =
                      angle (previous_vertex p i,
                             vertex p i,
                             next_vertex p i)
                  in
                      if a < 180.0
                      then anglesum (s + a, i + 1)
                      else NONE
                  end
      in
          case anglesum (0.0, 0) of
              NONE => false
            | SOME sum => true
      (* PERF actually, don't need
         the sum when using this method. *)
      end

  (* returns the point on the line segment between v1 and v2 that is
     closest to the pt argument. If this is one of v1 or v2, NONE is
     returned. *)
  fun closest_point (pt : vec2, v1 : vec2, v2 : vec2) : vec2 option =
    let
        val (px, py) = vec2xy pt
        val (v1x, v1y) = vec2xy v1
        val (v2x, v2y) = vec2xy v2
        val u = ((px - v1x) * (v2x - v1x) +
                 (py - v1y) * (v2y - v1y)) / distance_squared (v1, v2)
    in
        (* PERF: could do negative test before dividing *)
        if u < 0.0 orelse u > 1.0
        then NONE
        else SOME (vec2 (v1x + u * (v2x - v1x),
                         v1y + u * (v2y - v1y)))
    end

  (* From the BSD-licensed code by Wm. Randolph Franklin.
     See sml-lib/geom/polygon.sml, which is the same but uses
     a different representation of polygons. *)
  fun pointinside (p : poly) (v : vec2) =
      let
          (* val () = eprint ("pointinside " ^ vtos v ^ "?\n") *)
          val (x, y) = vec2xy v
          fun xcoord i = vec2x (GA.sub p i)
          fun ycoord i = vec2y (GA.sub p i)
          val nvert = GA.length p
          fun loop odd idx jdx =
              if idx = nvert
              then odd
              else loop (if ((ycoord idx > y) <> (ycoord jdx > y)) andalso
                             (x < ((xcoord jdx - xcoord idx) * (y - ycoord idx) /
                                   (ycoord jdx - ycoord idx) + xcoord idx))
                         then not odd
                         else odd) (idx + 1) idx
      in
          loop false 0 (nvert - 1)
      end

  (* Take two vectors that define a rectangle. Orient them so
     that they are the top left and bottom right corners. *)
  fun orienttobox (a, b) =
    let
        val (ax, ay) = vec2xy a
        val (bx, by) = vec2xy b
    in
        (vec2 (Real.min (ax, bx), Real.min (ay, by)),
         vec2 (Real.max (ax, bx), Real.max (ay, by)))
    end

end
