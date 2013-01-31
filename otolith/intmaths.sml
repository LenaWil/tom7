structure IntMaths :> INTMATHS =
struct

  exception IntMaths of string

  type point = int * int

  (* Real-valued (num mod den), always positive. *)
  fun fmod (num, den) =
    let val r = Real.rem (num, den)
    in if r < 0.0
       then r + den
       else r
    end

  (* Return the angle in degrees between v2->v1 and v2->v3,
     which is 360 - angle(v3, v2, v1). *)
  fun angle ((v1x, v1y), (v2x, v2y), (v3x, v3y)) =
    (* Treating v2 as the center, we have
         p1
        /
       / phi1
       0--------x
       | phi3
       |
       p3
       *)
    let
      val (p1x, p1y) = (v1x - v2x, v1y - v2y)
      val (p3x, p3y) = (v3x - v2x, v3y - v2y)
      val phi1 = Math.atan2 (real p1y, real p1x)
      val phi3 = Math.atan2 (real p3y, real p3x)

      val degs = 57.2957795 * (phi1 - phi3)
    in
      fmod (degs, 360.0)
    end handle Domain => raise IntMaths "bad angle"

  fun distance_squared ((x0, y0) : point, (x1, y1) : point) =
    let
      val xd = x0 - x1
      val yd = y0 - y1
    in
      xd * xd + yd * yd
    end

  fun distance v = Math.sqrt (real (distance_squared v))

  (* returns the point on the line segment between v1 and v2 that is
     closest to the pt argument. If this is one of v1 or v2, NONE is
     returned. *)
  fun closest_point ((px, py), (v1x, v1y), (v2x, v2y)) : point option =
    let
      val ds = distance_squared ((v1x, v1y), (v2x, v2y))
      val () = if ds = 0 then raise IntMaths "degenerate triangle"
               else ()
      val u = real ((px - v1x) * (v2x - v1x) +
                    (py - v1y) * (v2y - v1y)) /
        real ds
    in
      (* PERF: could do negative test before dividing *)
      if u < 0.0 orelse u > 1.0
      then NONE
      else SOME (Real.round (real v1x + u * real (v2x - v1x)),
                 Real.round (real v1y + u * real (v2y - v1y)))
    end

  fun closest_point_or_vertex ((px, py), (v1x, v1y), (v2x, v2y)) : point =
    case closest_point ((px, py), (v1x, v1y), (v2x, v2y)) of
      SOME p => p
    | NONE =>
        (* One of the two must be closest then. *)
        let val d1 = distance_squared ((px, py), (v1x, v1y))
          val d2 = distance_squared ((px, py), (v2x, v2y))
        in
          if d1 < d2
          then (v1x, v1y)
          else (v2x, v2y)
        end

  fun realpt (x, y) = (real x, real y)

  (* Adapted from the BSD-licensed code by Wm. Randolph Franklin, but it's
     nearly unrecognizable now. See sml-lib/geom/polygon.sml.
     This code is specialized to triangles with integer coordinates.

     PERF There may be more ways to simplify this, but probably should just
     switch to the barycentric version if it can be done with ints. *)
  fun pointinside ((ax, ay), (bx, by), (cx, cy)) (x : int, y : int) =
      let
        val odd =
          ((ay > y) <> (cy > y)) andalso
          let val numer = (cx - ax) * (y - ay)
              val denom = (cy - ay)
          in
            if denom > 0
            then (x - ax) * denom < numer
            else (x - ax) * denom > numer
          end

        val negate =
          ((by > y) <> (ay > y)) andalso
          let val numer = (ax - bx) * (y - by)
              val denom = (ay - by)
          in
            if denom > 0
            then (x - bx) * denom < numer
            else (x - bx) * denom > numer
          end

        val odd = (if negate then not odd else odd)

        val negate =
          ((cy > y) <> (by > y)) andalso
          let val numer = (bx - cx) * (y - cy)
              val denom = (by - cy)
          in
            if denom > 0
            then (x - cx) * denom < numer
            else (x - cx) * denom > numer
          end
      in
        if negate then not odd else odd
      end

  (* PERF might be some redundant comparisons. *)
  fun trianglebounds ((ax, ay), b, c) =
    let
      val bounds = { x0 = ax, y0 = ay, x1 = ax, y1 = ay }
      fun update { x0, y0, x1, y1 } (x, y) =
        { x0 = Int.min (x, x0),
          y0 = Int.min (y, y0),
          x1 = Int.max (x, x1),
          y1 = Int.max (y, y1) }

      val bounds = update bounds b
      val bounds = update bounds c
    in
      bounds
    end

  fun barycentric ((x1, y1), (x2, y2), (x3, y3), (x, y)) =
    let
      (* PERF: Note that this can be precomputed, as it doesn't depend
         on x,y. *)
      val determinant = real ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3))
      val lambda1 = real ((y2 - y3) * (x - x3) + (x3 - x2) * (y - y3)) / determinant
      val lambda2 = real ((y3 - y1) * (x - x3) + (x1 - x3) * (y - y3)) / determinant
      val lambda3 = 1.0 - lambda1 - lambda2
    in
      (lambda1, lambda2, lambda3)
    end

  datatype side =
    LEFT | COLINEAR | RIGHT
  fun pointside ((x0, y0), (x1, y1), (x, y)) =
    let val m = (x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)
    in
      if m > 0 then LEFT
      else if m < 0 then RIGHT
           else COLINEAR
    end

end
