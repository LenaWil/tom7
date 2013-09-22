signature INTMATHS =
sig

  exception IntMaths of string

  type point = int * int

  (* Return the angle in degrees between v2->v1 and v2->v3,
     which is 360 - angle(v3, v2, v1). *)
  val angle : point * point * point -> real

  val distance_squared : point * point -> int
  val distance : point * point -> real

  (* closest_point pt v1 v2
     returns the point on the line segment between v1 and v2 that is
     closest to the pt (first) argument. If this is one of v1 or v2,
     NONE is returned. *)
  val closest_point : point * point * point -> point option

  (* Same, but returns the closest vertex if it is one of them. *)
  val closest_point_or_vertex : point * point * point -> point

  (* Return true if the point is inside the triangle. *)
  val pointinside : point * point * point -> point -> bool

  val trianglebounds : point * point * point ->
                       { x0 : int, y0 : int, x1 : int, y1 : int }

  (* barycentric (a, b, c, pt)
     Returns the barycentric coordinates of pt using the
     triangle abc. *)
  val barycentric : point * point * point * point ->
                    real * real * real

  (* Checks for illegal triangle overlap.

     Returns true if the pair of triangles overlap.
     This includes the case where any vertex is inside
     the other triangle. It allows the two triangles
     to share a vertex or edge. It allows a vertex to
     be exactly upon an edge of another triangle, but
     only on one side (consistent with the pointinside
     test). Usually you don't want this anyway. (XXX
     consider disallowing this case -- in a tesselation,
     every point should be in at most one triangle,
     right?)

     XXX This does not yet handle the case where
     two triangles intersect but neither has a point
     inside the other, like in the Star of David. I
     think that's sufficient for tesselation checks
     because there's no way to construct the Star of
     David without violating this function momentarily.

     The function should be fixed and callers should
     be ready for that. *)
  val triangleoverlap : (point * point * point) ->
                        (point * point * point) ->
                        bool

  datatype intersection =
      NoIntersection
    | Intersection of int * int
    | Colinear

  (* Find the nature of the intersection between the
     vectors (x1, y1) to (x2, y2)  and   (x3, y3) to (x4, y4). *)
  val vectorintersection : (point * point) * (point * point) -> intersection
  (* Cheaper; doesn't compute the point of intersection. If the
     vectors are colinear, this counts as intersection. *)
  val vectorsintersect : (point * point) * (point * point) -> bool

  datatype side =
    LEFT | ATOP | RIGHT
  (* point (a, b, pt)
     Tests which side of the line a->b the point is on.
     If the line is horizontal with a to the left of b,
     then above the line is called "left". *)
  val pointside : point * point * point -> side

end
