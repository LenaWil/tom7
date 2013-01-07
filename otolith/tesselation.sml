structure Tesselation :> TESSELATION =
struct

  exception Tesselation of string

  datatype node = N of { id : IntInf.int,
                         x : int, y : int,
                         triangles : (node * node) list } ref
  structure NM = SplayMapFn(type ord_key = node
                            fun compare (N (ref {id, ...}),
                                         N (ref {id = idd, ...})) =
                                IntInf.compare (id, idd))

  type triangle = node * node * node

  (* Must be no more than 180.0 *)
  val MINANGLE = 170.0

  (* Enough? *)
  type tesselation = triangle list ref

  val ctr = ref (0 : IntInf.int)
  fun next () = (ctr := !ctr + 1; !ctr)

  (* Real-valued (num mod den), always positive. *)
  fun fmod (num, den) =
      let val r = Real.rem (num, den)
      in
          if r < 0.0 then r + den
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
      end

  structure T =
  struct
    fun nodes x = x
    fun nodelist (a, b, c) = [a, b, c]
  end

  structure N =
  struct
    fun coords (N (ref {x, y, ...})) = (x, y)
    fun triangles (v as N (ref {triangles, ...})) =
        map (fn (a, b) => (v, a, b)) triangles
    fun compare (N (ref {id, ...}), N (ref {id = idd, ...})) =
        IntInf.compare (id, idd)

    fun trymove (N (r as ref { x, y, triangles, id })) (newx, newy) =
        let
            fun checktriangle (a, b) =
              (* It is not allowed to make the triangle degenerate
                 (angle = 180) or inside-out (angle > 180). *)
                let
                    val a = coords a
                    val b = coords b
                    (* Get interior angle, regardless of winding *)
                    val (a, b) =
                        if angle (a, (x, y), b) < 180.0
                        then (a, b)
                        else (b, a)

                    val newangle = angle (a, (newx, newy), b)
                in
                    newangle < MINANGLE
                end
        in
            (* XXX: Could do binary search to find a closer point
               that's okay. *)
            if List.all checktriangle triangles
            then (r := { x = newx, y = newy, triangles = triangles, id = id };
                  (newx, newy))
            else (x, y)
        end
  end

  fun triangles (s : tesselation) : triangle list = !s

  (* PERF, probably this should be maintained with the tesselation? *)
  fun nodes (ref t) =
      let val m = ref NM.empty
          fun tolist m =
              NM.foldri (fn (k, (), b) => k :: b) nil m
          fun visit (v as N (ref { id, triangles, ... })) =
              case NM.find (!m, v) of
                  SOME () => ()
                | NONE =>
                   let in
                       m := NM.insert (!m, v, ());
                       List.app (fn (a, b) => (visit a; visit b)) triangles
                   end
      in
          (* Only visit one vertex because it knows about its neighbors *)
          app (fn (a, _, _) => visit a) t;
          tolist (!m)
      end

  fun tesselation { x0 : int, y0 : int, x1 : int, y1 : int } : tesselation =
      let
          fun settriangles (N (r as ref { id, x, y, ... }), t) =
              r := { id = id, x = x, y = y, triangles = t }

          (*    n1 --- n2
                |  \    |  t2
             t1 |    \  |
                n3 --- n4 *)
          val n1 = N (ref { id = next (), x = x0, y = y0, triangles = nil })
          val n2 = N (ref { id = next (), x = x1, y = y0, triangles = nil })
          val n3 = N (ref { id = next (), x = x0, y = y1, triangles = nil })
          val n4 = N (ref { id = next (), x = x1, y = y1, triangles = nil })
      in
          (* These are all clockwise. Should that be a representation invariant? *)
          settriangles (n1, [(n4, n3), (n2, n4)]);
          settriangles (n2, [(n4, n1)]);
          settriangles (n3, [(n1, n4)]);
          settriangles (n4, [(n3, n1), (n1, n2)]);
          ref [(n1, n4, n3), (n4, n1, n2)]
      end

  fun distance_squared ((x0 : int, y0 : int), (x1, y1)) =
      let
          val xd = x0 - x1
          val yd = y0 - y1
      in
          xd * xd + yd * yd
      end

  (* returns the point on the line segment between v1 and v2 that is
     closest to the pt argument. If this is one of v1 or v2, NONE is
     returned. *)
  fun closest_point ((px, py), (v1x, v1y), (v2x, v2y)) : (int * int) option =
    let
        val u = real ((px - v1x) * (v2x - v1x) +
                      (py - v1y) * (v2y - v1y)) /
            real (distance_squared ((v1x, v1y), (v2x, v2y)))
    in
        (* PERF: could do negative test before dividing *)
        if u < 0.0 orelse u > 1.0
        then NONE
        else SOME (Real.round (real v1x + u * real (v2x - v1x)),
                   Real.round (real v1y + u * real (v2y - v1y)))
    end

  fun closest_point_or_node ((px, py), (v1x, v1y), (v2x, v2y)) : int * int =
      case closest_point ((px, py), (v1x, v1y), (v2x, v2y)) of
          SOME p => p
        | NONE =>
            (* One of the two must be closest then. *)
          let val d1 = distance_squared ((px, py), (v1x, v1y))
              val d2 = distance_squared ((px, py), (v2x, v2y))
          in
              if (d1 < d2)
              then (v1x, v1y)
              else (v2x, v2y)
          end

  fun closestedge (s : tesselation) (x, y) : node * node * int * int =
      let
          (* keep track of the best distance seen so far *)
          val best_squared = ref NONE : int option ref
          val best_result = ref NONE : (node * node * int * int) option ref

          fun maybeupdate (d, r) =
              case !best_squared of
                  NONE => (best_squared := SOME d; best_result := SOME r)
                | SOME old => if d < old
                              then (best_squared := SOME d;
                                    best_result := SOME r)
                              else ()

          fun tryedge (n1, n2) =
              let
                  val (n1x, n1y) = N.coords n1
                  val (n2x, n2y) = N.coords n2
                  val (xx, yy) = closest_point_or_node ((x, y),
                                                        (n1x, n1y), (n2x, n2y))
                  val dist = distance_squared ((x, y), (xx, yy))
              in
                  (* print ("SDistance to " ^ Int.toString xx ^ "," ^
                         Int.toString yy ^ " is " ^ Int.toString dist ^ "\n"); *)
                  maybeupdate (dist, (n1, n2, xx, yy))
              end

          fun tryangle (a, b, c) =
              let in
                  tryedge (a, b);
                  tryedge (b, c);
                  tryedge (c, a)
              end
      in
          (* print ("--- to " ^ Int.toString x ^ "," ^ Int.toString y ^ "\n"); *)
          app tryangle (triangles s);

          case !best_result of
              NONE => raise Tesselation "impossible: must be at least one triangle"
            | SOME r => r
      end

  fun getnodewithin (s : tesselation) (x, y) radius : node option =
      let
          val radius_squared = radius * radius
          (* keep track of the best distance seen so far *)
          val best_squared = ref NONE : int option ref
          val best_result = ref NONE : node option ref

          fun maybeupdate (d, r) =
              if d > radius_squared
              then ()
              else
              case !best_squared of
                  NONE => (best_squared := SOME d; best_result := SOME r)
                | SOME old => if d < old
                              then (best_squared := SOME d;
                                    best_result := SOME r)
                              else ()

          fun trynode n =
              let
                  val (nx, ny) = N.coords n
                  val dist = distance_squared ((x, y), (nx, ny))
              in
                  maybeupdate (dist, n)
              end

      in
          app trynode (nodes s);
          !best_result
      end


  fun gettriangle (s : tesselation) (x, y) : triangle option =
      raise Tesselation "unimplemented"

  fun splitedge (s : tesselation) (x, y) : node option =
      raise Tesselation "unimplemented"

end
