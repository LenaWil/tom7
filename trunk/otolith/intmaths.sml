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
      let val (p1x, p1y) = (v1x - v2x, v1y - v2y)
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
     This code is specialized to triangles with integer coordinates. *)
  fun pointinside (a, b, c) (x : int, y : int) =
      let
        (* XXX use int math! *)
        val (ax, ay) = realpt a
        val (bx, by) = realpt b
        val (cx, cy) = realpt c
        val (x, y) = realpt (x, y)

        fun xcoord 0 = ax
          | xcoord 1 = bx
          | xcoord _ = cx
        fun ycoord 0 = ay
          | ycoord 1 = by
          | ycoord _ = cy

        val nvert = 3

        fun loop odd idx jdx =
            if idx = nvert
            then odd
            else
              let
                val negate =
                  ((ycoord idx > y) <> (ycoord jdx > y)) andalso
                  let val numer = (xcoord jdx - xcoord idx) * (y - ycoord idx)
                      val denom = (ycoord jdx - ycoord idx)
                      val frac = numer / denom
                  in
                    x - (xcoord idx) < frac
                  end
              in
                loop (if negate
                      then not odd
                      else odd) (idx + 1) idx
              end
      in
        loop false 0 (nvert - 1)
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

end
