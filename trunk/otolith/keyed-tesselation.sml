functor KeyedTesselation(Key : KEYARG) :> KEYEDTESSELATION
                                          where type key = Key.key =
struct

  type key = Key.key
  structure KM = SplayMapFn(type ord_key = key
                            val compare = Key.compare)

  exception KeyedTesselation of string

  datatype node = N of { id : IntInf.int,
                         coords : (int * int) KM.map,
                         triangles : (node * node) list } ref

  fun compare_node (N (ref {id, ...}), N (ref {id = idd, ...})) =
      IntInf.compare (id, idd)
  structure NM = SplayMapFn(type ord_key = node
                            val compare = compare_node)

  type triangle = node * node * node

  (* Must be no more than 180.0 *)
  val MINANGLE = 170.0

  (* Enough? *)
  datatype keyedtesselation =
      K of { triangles : triangle list ref,
             nodes : node list ref,
             ctr : IntInf.int ref }

  fun next (K { ctr, ... }) = (ctr := !ctr + 1; !ctr)

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
      end handle Domain => raise KeyedTesselation "bad angle"

  structure T =
  struct
    fun nodes x = x
    fun nodelist (a, b, c) = [a, b, c]
  end

  structure N =
  struct
    fun coordsmaybe (N (ref {coords, ...})) key = KM.find (coords, key)
    fun coords n key =
        case coordsmaybe n key of
            NONE => raise KeyedTesselation "No coordinates for key"
          | SOME v => v

    fun triangles (v as N (ref {triangles, ...})) =
        map (fn (a, b) => (v, a, b)) triangles

    val compare = compare_node

    fun eq (a : node, b : node) = a = b

    fun id (N (ref { id = i, ... })) = i

    fun trymove (node as N (r as ref { coords = c, triangles, id, ... }))
                key (newx, newy) =
        let
            val (x, y) = coords node key

            fun checktriangle (a, b) =
              (* It is not allowed to make the triangle degenerate
                 (angle = 180) or inside-out (angle > 180). *)
                let
                    val a = coords a key
                    val b = coords b key
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
            then (r := { coords = KM.insert (c, key, (newx, newy)),
                         triangles = triangles, id = id };
                  (newx, newy))
            else (x, y)
        end
  end

  fun triangles (K { triangles, ... }) : triangle list = !triangles
  fun nodes (K { nodes, ... }) : node list = !nodes

  (* Still necessary? Maybe only at load time? *)
(*
  fun compute_nodes (t : triangle list) =
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
*)

  fun rectangle key { x0 : int, y0 : int, x1 : int, y1 : int }
      : keyedtesselation =
      let
          fun settriangles (N (r as ref { id, coords, ... }), t) =
              r := { id = id, coords = coords, triangles = t }

          fun mc (x, y) = KM.insert (KM.empty, key, (x, y))

          val ctr : IntInf.int ref = ref 0
          val nodes : node list ref = ref nil
          val triangles : triangle list ref = ref nil
          val kt = K { ctr = ctr, nodes = nodes, triangles = triangles }

          (*    n1 --- n2
                |  \    |  t2
             t1 |    \  |
                n3 --- n4 *)
          val n1 = N (ref { id = next kt, coords = mc (x0, y0), triangles = nil })
          val n2 = N (ref { id = next kt, coords = mc (x1, y0), triangles = nil })
          val n3 = N (ref { id = next kt, coords = mc (x0, y1), triangles = nil })
          val n4 = N (ref { id = next kt, coords = mc (x1, y1), triangles = nil })
      in
          (* These are all clockwise. Should that be a representation invariant? *)
          settriangles (n1, [(n4, n3), (n2, n4)]);
          settriangles (n2, [(n4, n1)]);
          settriangles (n3, [(n1, n4)]);
          settriangles (n4, [(n3, n1), (n1, n2)]);

          nodes := [n1, n2, n3, n4];
          triangles := [(n1, n4, n3), (n4, n1, n2)];

          kt
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
        val () = if ds = 0 then raise KeyedTesselation "degenerate triangle"
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

  fun todebugstring (s : keyedtesselation) =
      let
          fun id (N (ref { id = i, ... })) = IntInf.toString i
          fun others (v1, v2) =
              id v1 ^ "-" ^ id v2
          fun coordmap cs =
              let val l = KM.listItemsi cs
              in
                  StringUtil.delimit ", "
                  (map (fn (k, (x, y)) => Key.tostring k ^ "=>" ^
                        Int.toString x ^ "," ^
                        Int.toString y) l)
              end


          fun node (N (ref { id, coords, triangles })) =
              "{" ^ IntInf.toString id ^ " @" ^
              coordmap coords ^
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

  fun closestedge (s : keyedtesselation) key (x, y)
      : node * node * int * int =
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
                  val (n1x, n1y) = N.coords n1 key
                  val (n2x, n2y) = N.coords n2 key
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
          app tryangle (triangles s);

          case !best_result of
              NONE => raise KeyedTesselation
                  "impossible: must be at least one triangle"
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
  fun triangles_with_edge (s : keyedtesselation) (n1 : node, n2 : node) =
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

  (* Internal! *)
  structure S =
  struct
      (* Adds the triangle. The nodes are not updated! *)
      fun addtriangle (K { triangles, ... }) (a, b, c) =
          triangles := (a, b, c) :: !triangles

      (* Add the node. Nothing else is updated. *)
      fun addnode (K { nodes, ... }) n =
          nodes := n :: !nodes

      (* Internal. Expects the triangle to exist exactly once.
         The nodes are not updated! *)
      fun removetriangle (K { triangles, ... }) (a, b, c) =
          let val found = ref false
          in triangles :=
              List.filter
                 (fn t => if same_triangle (t, (a, b, c))
                          then (if !found
                                then raise KeyedTesselation
                                    "Duplicate triangle in removetriangle"
                                else ();
                                found := true;
                                false)
                          else true) (!triangles);
             if !found
             then ()
             else raise KeyedTesselation "triangle not found in removetriangle"
          end
  end


  fun splitedge (s : keyedtesselation) key (x, y) : node option =
      let
          val MIN_SPLIT_DISTANCE_SQ = 3 * 3
          val (n1, n2, xx, yy) = closestedge s key (x, y)
          val (n1x, n1y) = N.coords n1 key
          val (n2x, n2y) = N.coords n2 key

          val n1dsq = distance_squared ((n1x, n1y), (xx, yy))
          val n2dsq = distance_squared ((n2x, n2y), (xx, yy))
      in
          if n1dsq < MIN_SPLIT_DISTANCE_SQ orelse
             n2dsq < MIN_SPLIT_DISTANCE_SQ
          then NONE
          else
          let
              val n1d = Math.sqrt (real n1dsq)
              val n2d = Math.sqrt (real n2dsq)

              (* Distance between n1 and n2. This is needed to place the
                 node in the same relative place in the other configurations. *)
              val frac : real = n1d / (n1d + n2d)

              fun settriangles (N (r as ref { id, coords, triangles = _ }), t) =
                  r := { id = id, coords = coords, triangles = t }

              fun node_addtriangle (N (r as ref { id, coords, triangles }), t) =
                  r := { id = id, coords = coords, triangles = t :: triangles }

              fun node_removetriangle (N (r as ref { id, coords, triangles }),
                                       (a, b)) =
                  r := { id = id, coords = coords,
                         triangles = List.filter (fn (c, d) =>
                                                  not (same_edge ((a, b),
                                                                  (c, d))))
                                     triangles }

              val (N (ref { coords = coords1, ... })) = n1
              val (N (ref { coords = coords2, ... })) = n2

              val newcoords =
                  KM.intersectWithi
                  (fn (k, (x1, y1), (x2, y2)) =>
                   if Key.compare (k, key) = EQUAL
                   then (xx, yy)
                   else
                    let
                        (* Vector from pt1 -> pt2 *)
                        val dx = x2 - x1
                        val dy = y2 - y1
                    in
                        (* then 'frac' of the way from pt1 to pt2. *)
                        (x1 + Real.round (frac * real dx),
                         y1 + Real.round (frac * real dy))
                    end) (coords1, coords2)

              val id = next s
              val () = print ("Splitedge next id is " ^ IntInf.toString id ^ "\n")
              val newnode =
                  N (ref { id = id, coords = newcoords, triangles = nil })

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
              S.addnode s newnode;
              app addedge affected_triangles;
              SOME newnode
          end
      end

  fun getnodewithin (s : keyedtesselation) key (x, y) radius : node option =
      let
          val radius_squared = radius * radius
          (* keep track of the best distance (actually squared distance
             to avoid doing sqrt) seen so far *)
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
                  val (nx, ny) = N.coords n key
                  val dist = distance_squared ((x, y), (nx, ny))
              in
                  maybeupdate (dist, n)
              end
      in
          app trynode (nodes s);
          !best_result
      end

  fun gettriangle (s : keyedtesselation) (x, y) : triangle option =
      raise KeyedTesselation "unimplemented"

  structure IIM = SplayMapFn(type ord_key = IntInf.int
                             val compare = IntInf.compare)
  structure IM = SplayMapFn(type ord_key = int
                            val compare = Int.compare)

  local
    structure W = WorldTF
  in
    fun toworld (s : keyedtesselation) : W.keyedtesselation =
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
          fun onecoord (k, (x, y)) = (Key.tostring k, x, y)
          fun onenode (N (ref { id : IntInf.int,
                                coords,
                                triangles : (node * node) list })) =
              W.N { id = get id,
                    coords = map onecoord (KM.listItemsi coords),
                    triangles = map onetriangle triangles }
          val nodes = map onenode (nodes s)
      in
          print (todebugstring s ^ "\n");
          W.S { nodes = nodes }
      end

    fun fromworld (W.S { nodes } : W.keyedtesselation) : keyedtesselation =
      let
        val ctr = ref 0
        val nodemap : node IM.map ref = ref IM.empty

        val allnodes : node list ref = ref nil

        fun makenode (W.N { id, coords, triangles = _ }) =
            case IM.find (!nodemap, id) of
               SOME _ => raise KeyedTesselation "duplicate IDs in input"
             | NONE =>
                   let
                     val coords =
                         foldl (fn ((s, x, y), m) =>
                                case Key.fromstring s of
                                    NONE => raise KeyedTesselation "unparseable key"
                                  | SOME k => KM.insert (m, k, (x, y)))
                                KM.empty
                                coords

                     val ii = IntInf.fromInt id

                     val newnode = N (ref { id = IntInf.fromInt id,
                                            coords = coords,
                                            triangles = [] })
                   in
                     if ii >= !ctr
                     then ctr := ii + 1
                     else ();
                     nodemap :=
                     (* Triangles filled in during the next pass. *)
                     IM.insert (!nodemap, id, newnode);
                     allnodes := newnode :: !allnodes
                   end

        val alltriangles : triangle list ref = ref nil

        fun settriangles (W.N { id, coords = _, triangles }) =
            case IM.find (!nodemap, id) of
               NONE => raise KeyedTesselation "bug"
             | SOME (node as N (r as ref { id = idi, coords, triangles = _ })) =>
                let fun oneid i =
                      case IM.find (!nodemap, i) of
                        NONE => raise KeyedTesselation "unknown id in input"
                      | SOME n => n

                    fun onet (a, b) =
                      let
                        val an = oneid a
                        val bn = oneid b

                        val ai = IntInf.fromInt a
                        val bi = IntInf.fromInt b
                      in
                        if idi = ai orelse idi = bi orelse ai = bi
                        then raise KeyedTesselation ("node " ^ IntInf.toString idi ^
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
                    r := { id = idi, coords = coords,
                           triangles = map onet triangles }
                end

        val () = app makenode nodes
        val () = app settriangles nodes
      in
        print ("On load, ctr is " ^ IntInf.toString (!ctr) ^ "\n");
        K { ctr = ctr, nodes = allnodes, triangles = alltriangles }
      end
  end

(*
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
                            then raise KeyedTesselation "degenerate triangle"
                            else ()
                    in
                        (case IIM.find (!seen, id) of
                             NONE => seen := IIM.insert (!seen, id, (node, ref false))
                           | SOME (nnn, _) =>
                               if nnn <> node
                               then raise KeyedTesselation "Duplicate IDs"
                               else ());
                        app onetri triangles
                    end

                fun onetriangle (a, b, c) =
                    let fun looky (node as (N (ref { id, ... }))) =
                        case IIM.find (!seen, id) of
                          NONE => raise KeyedTesselation ("Didn't find " ^
                                                     IntInf.toString id ^
                                                     " in node list")
                        | SOME (nnn, saw) =>
                            if nnn <> node
                            then raise KeyedTesselation ("Node in triangle not " ^
                                                    "the same as in node list")
                            else saw := true
                    in
                        looky a;
                        looky b;
                        looky c
                    end

                fun checkmissing (i, (_, ref false)) =
                    raise KeyedTesselation ("Didn't find " ^ IntInf.toString i ^
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
