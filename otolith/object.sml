structure Object :> OBJECT =
struct

  exception Object of string

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
  type object = triangle list ref

  (* XXX This is sort of error prone and should probably be
     part of the object itself. In particular, when we
     load any object we need to make sure this counter
     is larger than any id it uses. *)
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
      end handle Domain => raise Object "bad angle"

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
    fun eq (a : node, b : node) = a = b

    fun id (N (ref ({ id = i, ... }))) = i

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

  fun triangles (s : object) : triangle list = !s

  (* PERF, probably this should be maintained with the object? *)
  fun nodes (ref t) =
      let val m = ref NM.empty
          fun tolist m =
              NM.foldri (fn (k, (), b) => k :: b) nil m
          fun visit (v as N (ref { triangles, ... })) =
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

  fun object { x0 : int, y0 : int, x1 : int, y1 : int } : object =
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
        val ds = distance_squared ((v1x, v1y), (v2x, v2y))
        val () = if ds = 0 then raise Object "degenerate triangle"
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

  fun todebugstring (s : object) =
      let
          fun id (N (ref { id = i, ... })) = IntInf.toString i
          fun others (v1, v2) =
              id v1 ^ "-" ^ id v2
          fun node (N (ref { id, x, y, triangles })) =
              "{" ^ IntInf.toString id ^ " @" ^ Int.toString x ^ "," ^
              Int.toString y ^
              " [" ^ StringUtil.delimit "," (map others triangles) ^
              "]}"
          fun triangle (t : triangle) =
              let val (a, b, c) = T.nodes t
              in
                  " <" ^ node a ^ "\n" ^
                  "  " ^ node b ^ "\n" ^
                  "  " ^ node c ^ ">\n"
              end

          val tris : triangle list = triangles s
          val nos : node list = nodes s
      in
          "triangles:\n" ^
          String.concat (map triangle tris) ^
          "nodes:\n"^
          String.concat (map (fn n => node n ^ "\n") nos)
      end

  fun closestedge (s : object) (x, y) : node * node * int * int =
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
              NONE => raise Object "impossible: must be at least one triangle"
            | SOME r => r
      end

  (* PERF if we had some kind of invariants on winding ordering we
     could probably reduce the number of comparisons here and below.
     But I think it's quite a pain to get right. *)
  fun same_edge ((n1 : node, n2 : node), (n3 : node, n4 : node)) =
      (N.eq (n1, n3) andalso N.eq (n2, n4)) orelse
      (N.eq (n1, n4) andalso N.eq (n2, n3))

  (* Returns a list, which should be at most two triangles.
     The triangle is represented as the node that is not n1 nor n2. *)
  fun triangles_with_edge (s : object) (n1 : node, n2 : node) =
      let
          fun match (a, b, c) =
              if same_edge ((a, b), (n1, n2)) then SOME c
              else if same_edge ((b, c), (n1, n2)) then SOME a
                   else if same_edge ((c, a), (n1, n2)) then SOME b
                        else NONE
      in
          (* Could check that there are at most 2 *)
          List.mapPartial match (triangles s)
      end

  (* PERF: Could generate the comparisons for sort/eq, which would
     be faster than this AND/OR mess. *)
  fun same_triangle ((a, b, c), (d, e, f)) =
      (* If they are the same triangle, then a must be equal to
         one of the other nodes. Then the remaining edges must
         be equal, too. *)
      (N.eq (a, d) andalso same_edge ((b, c), (e, f))) orelse
      (N.eq (a, e) andalso same_edge ((b, c), (d, f))) orelse
      (N.eq (a, f) andalso same_edge ((b, c), (d, e)))

  structure S =
  struct
      fun addtriangle (s : object) (a, b, c) =
          s := (a, b, c) :: !s

      (* Internal. Expects the triangle to exist exactly once. *)
      fun removetriangle (s : object) (a, b, c) =
          let val found = ref false
          in s := List.filter
              (fn t => if same_triangle (t, (a, b, c))
                       then (if !found
                             then raise Object
                                 ("Duplicate triangle in removetriangle")
                             else ();
                             found := true;
                             false)
                       else true) (!s);
             if !found
             then ()
             else raise Object ("triangle not removed in removetriangle")
          end
  end


  fun splitedge (s : object) (x, y) : node option =
      let
          val MIN_SPLIT_DISTANCE = 3 * 3
          val (n1, n2, xx, yy) = closestedge s (x, y)
          val (n1x, n1y) = N.coords n1
          val (n2x, n2y) = N.coords n2
      in
          if distance_squared ((n1x, n1y), (xx, yy)) < MIN_SPLIT_DISTANCE orelse
             distance_squared ((n2x, n2y), (xx, yy)) < MIN_SPLIT_DISTANCE
          then NONE
          else
          let
              fun settriangles (N (r as ref { id, x, y, ... }), t) =
                  r := { id = id, x = x, y = y, triangles = t }

              fun node_addtriangle (N (r as ref { id, x, y, triangles }), t) =
                  r := { id = id, x = x, y = y, triangles = t :: triangles }

              fun node_removetriangle (N (r as ref { id, x, y, triangles }),
                                       (a, b)) =
                  r := { id = id, x = x, y = y,
                         triangles = List.filter (fn (c, d) =>
                                                  not (same_edge ((a, b),
                                                                  (c, d))))
                                     triangles }

              val newnode =
                  N (ref { id = next (), x = xx, y = yy, triangles = nil })

              (* The edge may be in 1 or 2 triangles. The triangle is defined
                 by the single third node. *)
              fun addedge othernode =
                  let
                      val N (ref { triangles = oldtriangles, ... }) = newnode
                  in
                      (* update triangles in othernode *)
                      node_removetriangle (othernode, (n1, n2));
                      node_addtriangle (othernode, (n1, newnode));
                      node_addtriangle (othernode, (newnode, n2));

                      (* update triangles in n1 *)
                      node_removetriangle (n1, (othernode, n2));
                      node_addtriangle (n1, (othernode, newnode));

                      (* update triangles in n2 *)
                      node_removetriangle (n2, (n1, othernode));
                      node_addtriangle (n2, (othernode, newnode));

                      (* Add to newnode's triangles *)
                      node_addtriangle (newnode, (n1, othernode));
                      node_addtriangle (newnode, (othernode, n2));

                      (* Update global triangle list. *)
                      S.removetriangle s (othernode, n1, n2);
                      S.addtriangle s (newnode, n1, othernode);
                      S.addtriangle s (newnode, othernode, n2)
                  end

              val affected_triangles : node list =
                  triangles_with_edge s (n1, n2)
          in
              (*
              print ("BEFORE:\n");
              print (tostring s ^ "\n"); (* XX *)
              *)

              app addedge affected_triangles;

              (*
              print ("AFTER:\n");
              print (tostring s ^ "\n"); (* XX *)
              *)

              SOME newnode
          end
      end

  fun getnodewithin (s : object) (x, y) radius : node option =
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

  fun gettriangle (s : object) (x, y) : triangle option =
      raise Object "unimplemented"

  structure IIM = SplayMapFn(type ord_key = IntInf.int
                             val compare = IntInf.compare)
  structure IM = SplayMapFn(type ord_key = int
                            val compare = Int.compare)

(*
  local
    structure W = WorldTF
  in
    fun toworld (s : object) : W.object =
      let
          val next = ref 0
          val idmap : int IIM.map ref = ref IIM.empty
          fun get i =
             case IIM.find (!idmap, i) of
                NONE => (idmap := IIM.insert (!idmap, i, !next);
                         next := !next + 1;
                         get i)
              | SOME x => x

          fun oneid (N (ref { id, ... })) = get id
          fun onetriangle (a, b) = (oneid a, oneid b)
          fun onenode (N (ref { id : IntInf.int,
                                x : int, y : int,
                                triangles : (node * node) list })) =
              W.N { id = get id,
                    x = x, y = y,
                    triangles = map onetriangle triangles }
          val nodes = map onenode (nodes s)
      in
          W.S { nodes = nodes }
      end

    fun fromworld (W.S { nodes } : W.object) : object =
      let
        val nodemap : node IM.map ref = ref IM.empty

        fun makenode (W.N { id, x, y, triangles = _ }) =
            case IM.find (!nodemap, id) of
               SOME _ => raise Object "duplicate IDs in input"
             | NONE =>
                   let val ii = IntInf.fromInt id
                   in
                     if ii >= !ctr
                     then ctr := ii + 1
                     else ();
                     nodemap :=
                     (* Triangles filled in during the next pass. *)
                     IM.insert (!nodemap, id,
                                N (ref { id = IntInf.fromInt id,
                                         x = x,
                                         y = y,
                                         triangles = [] }))
                   end

        val alltriangles : triangle list ref = ref nil

        fun settriangles (W.N { id, x = _, y = _, triangles }) =
            case IM.find (!nodemap, id) of
               NONE => raise Object "bug"
             | SOME (node as N (r as ref { id = idi, x, y, triangles = _ })) =>
                let fun oneid i =
                        case IM.find (!nodemap, i) of
                          NONE => raise Object "unknown id in input"
                        | SOME n => n
                    fun onet (a, b) =
                        let val an = oneid a
                            val bn = oneid b

                            val ai = IntInf.fromInt a
                            val bi = IntInf.fromInt b
                        in
                            if idi = ai orelse idi = bi orelse ai = bi
                            then raise Object ("node " ^ IntInf.toString idi ^
                                                    " is in a degenerate triangle")
                            else ();

                            (* Only add once. Do it when the current id
                               is the least of the three. *)
                            if IntInf.< (idi, ai) andalso
                               IntInf.< (idi, bi)
                            then alltriangles := (an, node, bn) :: !alltriangles
                            else ();
                            (an, bn)
                        end
                in
                    r := { id = idi, x = x, y = y,
                           triangles = map onet triangles }
                end

        val () = app makenode nodes
        val () = app settriangles nodes
      in
        alltriangles
      end
  end

  fun check s =
    let
        fun checkobject s =
            let
                (* First we make a pass checking for duplicate IDs and
                   initializing the list of nodes in the object.
                   Then we make another pass to make sure every node
                   in the triangles is found in the node list and
                   vice versa. The bool ref is used to mark the ones
                   we found the second pass to see if any are missing. *)
                val seen : (node * bool ref) IIM.map ref = ref IIM.empty

                fun onenode (node as
                             N (ref { id : IntInf.int,
                                      x : int, y : int,
                                      triangles : (node * node) list })) =
                    let
                        fun onetri (a, b) =
                            if a = b orelse node = a orelse node = b
                            then raise Object "degenerate triangle"
                            else ()
                    in
                        (case IIM.find (!seen, id) of
                             NONE => seen := IIM.insert (!seen, id, (node, ref false))
                           | SOME (nnn, _) =>
                               if nnn <> node
                               then raise Object "Duplicate IDs"
                               else ());
                        app onetri triangles
                    end

                fun onetriangle (a, b, c) =
                    let fun looky (node as (N (ref { id, ... }))) =
                        case IIM.find (!seen, id) of
                          NONE => raise Object ("Didn't find " ^
                                                     IntInf.toString id ^
                                                     " in node list")
                        | SOME (nnn, saw) =>
                            if nnn <> node
                            then raise Object ("Node in triangle not " ^
                                                    "the same as in node list")
                            else saw := true
                    in
                        looky a;
                        looky b;
                        looky c
                    end

                fun checkmissing (i, (_, ref false)) =
                    raise Object ("Didn't find " ^ IntInf.toString i ^
                                       " in triangles.")
                  | checkmissing _ = ()
            in
                app onenode (nodes s);
                app onetriangle (triangles s);
                IIM.appi checkmissing (!seen)
            end
    in
        print ("Check: " ^ todebugstring s ^ "\n");
        checkobject s;
        ignore (fromworld (toworld s))
    end
*)

end
