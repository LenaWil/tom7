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
    LEFT | ATOP | RIGHT
  fun pointside ((x0, y0), (x1, y1), (x, y)) =
    let val m = (x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)
    in
      if m > 0 then LEFT
      else if m < 0 then RIGHT
           else ATOP
    end

  datatype intersection =
      NoIntersection
    | Intersection of int * int
    | Colinear

  (* This is a straightforward port of Mukesh Prasad's lines_intersect
     from Graphics Gems II. Graphics Gems are published with the
     requirement that the source contain attribution. "Using the code
     is permitted in any program, product, or library, non-commercial
     or commercial. Giving credit is not required, though is a nice
     gesture." *)
  fun vectorintersection (((x1, y1), (x2, y2)), ((x3, y3), (x4, y4)))
    : intersection =
    let
      (* Compute a1, b1, c1, where line joining points 1 and 2
         is "a1 x  +  b1 y  +  c1  =  0". *)
      val a1 = y2 - y1
      val b1 = x1 - x2
      val c1 = x2 * y1 - x1 * y2

      val r3 = a1 * x3 + b1 * y3 + c1
      val r4 = a1 * x4 + b1 * y4 + c1
    in
      (* If both point 3 and point 4 lie on same side of line 1, the line
         segments do not intersect. *)
      if r3 <> 0 andalso r4 <> 0 andalso
         Int.sameSign (r3, r4)
      then NoIntersection
      else
        let
          val a2 = y4 - y3
          val b2 = x3 - x4
          val c2 = x4 * y3 - x3 * y4

          val r1 = a2 * x1 + b2 * y1 + c2
          val r2 = a2 * x2 + b2 * y2 + c2
        in
          (* If both point 1 and point 2 lie on same side of second line
             segment, the line segments do not intersect. *)
          if r1 <> 0 andalso r2 <> 0 andalso
             Int.sameSign (r1, r2)
          then NoIntersection
          else
            (* They intersect -- where? *)
            let
              val denom = a1 * b2 - a2 * b1
            in
              if denom = 0
              then Colinear
              else
                let
                  (* To get rounding instead of truncating.
                     It's added or subtracted to the numerator,
                     depending on the sign. XXX I seem to recall
                     a difference in rounding behavior between
                     C and SML? *)
                  val offset = if denom < 0
                               then denom div ~2
                               else denom div 2

                  val numx = b1 * c2 - b2 * c1
                  val numy = a2 * c1 - a1 * c2
                in
                  Intersection ((if numx < 0
                                 then numx - offset
                                 else numx + offset) div denom,
                                (if numy < 0
                                 then numy - offset
                                 else numy + offset) div denom)
                end
            end
        end
    end

  fun ctos (x, y) = Int.toString x ^ "," ^ Int.toString y
  fun vtos (p1, p2) = ctos p1 ^ "->" ^ ctos p2
  fun ttos (a, b, c) = ctos a ^ ";" ^ ctos b ^ ";" ^ ctos c

  (* Just a simplified version of the above. *)
  fun vectorsintersect (((x1, y1), (x2, y2)), ((x3, y3), (x4, y4)))
    : bool =
    let
      (* Compute a1, b1, c1, where line joining points 1 and 2
         is "a1 x  +  b1 y  +  c1  =  0". *)
      val a1 = y2 - y1
      val b1 = x1 - x2
      val c1 = x2 * y1 - x1 * y2

      val r3 = a1 * x3 + b1 * y3 + c1
      val r4 = a1 * x4 + b1 * y4 + c1
    in
      (* If both point 3 and point 4 lie on same side of line 1, the line
         segments do not intersect. *)
      if r3 <> 0 andalso r4 <> 0 andalso
         Int.sameSign (r3, r4)
      then false
      else
        let
          val a2 = y4 - y3
          val b2 = x3 - x4
          val c2 = x4 * y3 - x3 * y4

          val r1 = a2 * x1 + b2 * y1 + c2
          val r2 = a2 * x2 + b2 * y2 + c2
        in
          (* If both point 1 and point 2 lie on same side of second line
             segment, the line segments do not intersect. *)
          not (r1 <> 0 andalso r2 <> 0 andalso Int.sameSign (r1, r2))
        end
    end

  (* PERF surely there are faster tests. *)
  fun triangleoverlap (abc as (a, b, c)) (def as (d, e, f)) : bool =
    let
      (* The point is okay if it is equal to one of the other
         vertices, or if it is outside the triangle. *)
      fun badpoint (pt, tri as (g, h, i)) =
        pointinside tri pt andalso
        not (pt = g orelse
             pt = h orelse
             pt = i)

      (* Like vectorsintersect, but ignored if the vectors
         share an endpoint in common. Note that this allows
         colinear vectors in that case. *)
      fun edgesintersect (e as (p, q),
                          ee as (pp, qq)) =
        p <> pp andalso p <> qq andalso q <> pp andalso q <> qq
        andalso vectorsintersect (e, ee)

      fun badedge (edge, (g, h, i)) =
        edgesintersect (edge, (g, h)) orelse
        edgesintersect (edge, (h, i)) orelse
        edgesintersect (edge, (i, g))

    in
      (* "Most" triangle intersections also have edge intersections,
         so try those first. The test is symmetric, so we only need
         to test one triangle. *)
       badedge ((a, b), def) orelse
       badedge ((b, c), def) orelse
       badedge ((c, a), def) orelse

       (* Might be appropriate to use an integer barycentric-based
          test, since you can precompute the determinant for all
          three tests. *)
       badpoint (d, abc) orelse
       badpoint (e, abc) orelse
       badpoint (f, abc) orelse

       badpoint (a, def) orelse
       badpoint (b, def) orelse
       badpoint (c, def)
    end

end
