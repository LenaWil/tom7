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

end
