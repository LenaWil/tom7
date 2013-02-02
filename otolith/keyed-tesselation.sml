functor KeyedTesselation(Key : KEYARG) :> KEYEDTESSELATION
                                          where type key = Key.key =
struct

  type key = Key.key
  structure KM = SplayMapFn(type ord_key = key
                            val compare = Key.compare)

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

  (* TODO: Representation issues.

     - The angle check doesn't work correctly if the line is
       completely vertical? (maybe something like 360 should be 0?)
       So it's possible to turn a triangle inside out.
     - Edge flips don't respect triangle size
     - Irrespective of triangle size, it's possible to make
       overlapping triangles with a triangle strip that loops
       over itself.
     - Should be possible (or automatic) to snap two nodes at
       the same x,y. *)

  (* PERF probably don't need to be using IntInf. Now that
     counters are local to the tesselation, it's pretty implausible
     that these numbers would get high. And currently there is no
     way to delete anyway. *)

  (* Representation invariant: All nodes have the set of keys. *)
  datatype keyedtesselation =
    K of { triangles : triangle list ref,
           nodes : node list ref,
           ctr : IntInf.int ref }

  (* Any node will do; they must all have the same set. *)
  fun keys (K { nodes = ref (N (ref { coords, ... }) :: _), ... }) =
      KM.foldri (fn (k, _, l) => k :: l) nil coords
    | keys _ = raise Key.exn "empty keyedtesselation in keys?"

  fun iskey (K { nodes = ref (N (ref { coords, ... }) :: _), ... }) n =
    Option.isSome (KM.find (coords, n))
    | iskey _ _ = raise Key.exn "empty keyedtesselation in iskey?"

  fun addkey (kt as K { nodes, ... }) newcoords key =
    if iskey kt key
    then raise Key.exn "key already exists in addkey"
    else
      let
        fun setcoords (N (r as ref { id, coords = _, triangles })) coords =
          r := { id = id, coords = coords, triangles = triangles }

        fun onenode (n as N (ref { coords, ... })) =
          let val nc = newcoords n
          in setcoords n (KM.insert (coords, key, nc))
          end
      in
        List.app onenode (!nodes)
      end

  fun next (K { ctr, ... }) = (ctr := !ctr + 1; !ctr)

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
        NONE => raise Key.exn "No coordinates for key"
      | SOME v => v

    fun triangles (v as N (ref {triangles, ...})) =
      map (fn (a, b) => (v, a, b)) triangles

    val compare = compare_node

    fun eq (a : node, b : node) = a = b

    fun id (N (ref { id = i, ... })) = i

  end

  (* PERF if we had some kind of invariants on winding order we
     could probably reduce the number of comparisons here and below.
     But I think it's quite a pain to get right. *)
  (* Same as compare_edge = EQUAL but should be faster. *)
  fun same_edge ((n1 : node, n2 : node), (n3 : node, n4 : node)) =
    (N.eq (n1, n3) andalso N.eq (n2, n4)) orelse
    (N.eq (n1, n4) andalso N.eq (n2, n3))


  (* PERF: Could generate the comparisons for sort/eq, which would
     be faster than this AND/OR mess. *)
  fun same_triangle ((a, b, c), (d, e, f)) =
    (* If they are the same triangle, then a must be equal to
       one of the other nodes. Then the remaining edges must
       be equal, too. *)
    (N.eq (a, d) andalso same_edge ((b, c), (e, f))) orelse
    (N.eq (a, e) andalso same_edge ((b, c), (d, f))) orelse
    (N.eq (a, f) andalso same_edge ((b, c), (d, e)))

  fun triangles (K { triangles, ... }) : triangle list = !triangles
  fun nodes (K { nodes, ... }) : node list = !nodes

  fun trymovenode (s : keyedtesselation)
                  (node as N (r as ref { coords = c,
                                         triangles = nodetriangles,
                                         id, ... }))
                  key (newx, newy) =
    let
      val alltriangles = triangles s

      val (x, y) = N.coords node key

      fun checkadjacentangle (a, b) =
        (* It is not allowed to make the triangle degenerate
           (angle = 180) or inside-out (angle > 180). *)
        let
          val a = N.coords a key
          val b = N.coords b key
          (* Get interior angle, regardless of winding *)
          val (a, b) =
            if IntMaths.angle (a, (x, y), b) < 180.0
            then (a, b)
            else (b, a)

          val newangle = IntMaths.angle (a, (newx, newy), b)
        in
          newangle < MINANGLE
        end

      (* No new overlaps are allowed. Check this triangle
         against all other ones. Returns true if everything
         is okay. We only move with the selected key, so only
         this key can violate representation invariants. *)
      fun checkoverlaps (a, b) =
        let
          val whichtri = (a, node, b)
          val a = N.coords a key
          val b = N.coords b key
          val me = (a, (newx, newy), b)

          (* We may encounter the node being moved in other triangles;
             make sure that they respect its new position (otherwise
             you almost always get an apparent overlap since the
             node will have moved into a triangle it used to define). *)
          fun newcoords n =
            if n = node
            then (newx, newy)
            else N.coords n key
        in
          List.all (fn (d, e, f) =>
                    (* don't do self-overlap test. *)
                    same_triangle (whichtri, (d, e, f)) orelse
                    let
                      val d = newcoords d
                      val e = newcoords e
                      val f = newcoords f
                      fun ctos (x, y) = Int.toString x ^ "," ^ Int.toString y
                      fun ttos (a, b, c) = ctos a ^ ";" ^ ctos b ^ ";" ^ ctos c
                    in
                      if IntMaths.triangleoverlap me (d, e, f)
                      then (print ("Overlap: " ^ ttos me ^ " and " ^ ttos (d, e, f) ^ "\n");
                            false)
                      else true
                    (* not (IntMaths.triangleoverlap me (d, e, f)) *)
                    end) alltriangles
        end

    in
      (* XXX: Could do binary search to find a closer point
         that's okay. *)
      if List.all checkadjacentangle nodetriangles andalso
         List.all checkoverlaps nodetriangles
      then (r := { coords = KM.insert (c, key, (newx, newy)),
                   triangles = nodetriangles, id = id };
            (newx, newy))
      else (x, y)
    end

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

  (* Return the closest edge (ties broken arbitrarily) that satisfies
     the predicate. The predicate is only tested in a single node
     order (also arbitrary) so it should be symmetric. *)
  fun closestedgesatisfying (pred : node * node -> bool)
                            (s : keyedtesselation) key (x, y)
      : (node * node * int * int) option =
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
        if pred (n1, n2)
        then
          let
            val (n1x, n1y) = N.coords n1 key
            val (n2x, n2y) = N.coords n2 key
            val (xx, yy) =
              IntMaths.closest_point_or_vertex ((x, y),
                                                (n1x, n1y), (n2x, n2y))
            val dist = IntMaths.distance_squared ((x, y), (xx, yy))
          in
            (* print ("SDistance to " ^ Int.toString xx ^ "," ^
               Int.toString yy ^ " is " ^ Int.toString dist ^ "\n"); *)
            maybeupdate (dist, (n1, n2, xx, yy))
          end
        else ()

      fun tryangle (a, b, c) =
        let in
          tryedge (a, b);
          tryedge (b, c);
          tryedge (c, a)
        end
    in
      app tryangle (triangles s);
      !best_result
    end

  fun closestedge s key xy =
    case closestedgesatisfying (fn _ => true) s key xy of
      NONE => raise Key.exn "impossible: must be at least one triangle"
    | SOME r => r

  (* Assumes n1 and n2 is a valid edge in a single tesselation. *)
  fun getinternaledge (n1 as N (ref { triangles = t1, ... }),
                       n2 as N (ref { triangles = t2, ... })) =
    (* The edge n1->n2 is internal if there exist nodes
       A and B where (A, n2) is in the triangles of n1
       and (B, n1) is in the triangles of n2 and A <> B. *)
    let
      (* For the triangles in t, find nodes that appear in
         a triangle with nn. *)
      fun getcands (t, nn) =
        List.mapPartial (fn (a, b) =>
                         (* Assumes a <> b, by representation
                            invariant. *)
                         if b = nn then SOME a
                         else if a = nn then SOME b
                              else NONE) t

      (* XXX actually, can't we just check cand_a with itself? *)
      val cand_a = getcands (t1, n2)
      val cand_b = getcands (t2, n1)

      (* Both cand_a and cand_b have maximum length of 2,
         so no fancy algorithms needed here... *)

      val () = if List.length cand_a > 2
               then raise Key.exn "Bug A: can't be more than 2 triangles on an edge"
               else ()

      val () = if List.length cand_b > 2
               then raise Key.exn "Bug B: can't be more than 2 triangles on an edge"
               else ()

      fun find_disequal (nil, _) = NONE
        | find_disequal (a :: rest, bl) =
        case List.find (fn b => not (N.eq (a, b))) bl of
          NONE => find_disequal (rest, bl)
        | SOME b => SOME (a, b)
    in
      find_disequal (cand_a, cand_b)
    end

  fun isinternaledge (n1, n2) = Option.isSome (getinternaledge (n1, n2))

  (* Put the smaller node first. *)
  fun normalize_edge (n1 : node, n2 : node) =
    case compare_node (n1, n2) of
      GREATER => (n2, n1)
    | _ => (n1, n2)

  fun compare_edge ((n1 : node, n2 : node), (n3 : node, n4 : node)) =
    let val (n1, n2) = normalize_edge (n1, n2)
      val (n3, n4) = normalize_edge (n3, n4)
    in
      case compare_node (n1, n3) of
        LESS => LESS
      | GREATER => GREATER
      | EQUAL => compare_node (n2, n4)
    end

  (* PERF: Keys could be kept in a normalized order (smaller
     node first), which makes comparisons much cheaper. But
     this would require wrapping the splaymap operations.
     Maybe it makes sense to have a KeyNormalizedSplayMapFn
     that does that in generality? *)
  structure EM = SplayMapFn(type ord_key = node * node
                            val compare = compare_edge)

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
                       then raise Key.exn
                         "Duplicate triangle in removetriangle"
                       else ();
                         found := true;
                         false)
                 else true) (!triangles);
        if !found
        then ()
        else raise Key.exn "triangle not found in removetriangle"
      end
  end


  fun splitedge (s : keyedtesselation) key (x, y) : node option =
    let
      val MIN_SPLIT_DISTANCE_SQ = 3 * 3
      val (n1, n2, xx, yy) = closestedge s key (x, y)
      val (n1x, n1y) = N.coords n1 key
      val (n2x, n2y) = N.coords n2 key

      val n1dsq = IntMaths.distance_squared ((n1x, n1y), (xx, yy))
      val n2dsq = IntMaths.distance_squared ((n2x, n2y), (xx, yy))
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
        val newnode = N (ref { id = id, coords = newcoords, triangles = nil })

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

  (*
          n1                           n1
           .---. n3                     .---. n3
           |\  |                        |  /|
           | \ |          --->          | / |
        n4 |__\|                     n4 |/__|
               n2                           n2
               *)
  fun closestflipedge (s : keyedtesselation) key (x, y) :
    ((node * node) * (int * int) * (node * node)) option =
    case closestedgesatisfying isinternaledge s key (x, y) of
      NONE => NONE
    | SOME (n1, n2, cx, cy) =>
      (* Could maybe have closestedgepartial to avoid two passes *)
      (case getinternaledge (n1, n2) of
         NONE => raise Key.exn ("bug: can't get internal edge " ^
                                "after isinternaledge succeeds?")
       | SOME (n4, n3) =>
         let
           (* XXXXXXX have to do this for every key, not just the current
              one. *)
           val n1c = N.coords n1 key
           val n2c = N.coords n2 key
           val n3c = N.coords n3 key
           val n4c = N.coords n4 key

           (* n1 and n2 cannot be on the same side of the new edge.
              Don't allow colinear either. *)
           val ok =
             case (IntMaths.pointside (n3c, n4c, n1c),
                   IntMaths.pointside (n3c, n4c, n2c)) of
               (IntMaths.LEFT, IntMaths.RIGHT) => true
             | (IntMaths.RIGHT, IntMaths.LEFT) => true
             | _ => false
         in
           (* XXX check angles in new triangles. *)
           if ok
           then SOME ((n1, n2), (cx, cy), (n3, n4))
           else NONE
         end)

  fun flipedge (s : keyedtesselation) (key : key) (x : int, y : int)
    : bool =
    case closestflipedge s key (x, y) of
      NONE => false
    | SOME ((n1, n2), _, (n3, n4)) =>
        let
          fun node_addtriangle (N (r as ref { id, coords, triangles }), t) =
            r := { id = id, coords = coords, triangles = t :: triangles }

          fun node_removetriangle (N (r as ref { id, coords, triangles }),
                                   (a, b)) =
            r := { id = id, coords = coords,
                   triangles = List.filter (fn (c, d) =>
                                            not (same_edge ((a, b),
                                                            (c, d))))
                                           triangles }

          (* All that we need to do is remove the old triangles
             (from each node, as well as the tesselation itself)
             and add the new ones (to each node, and the tesslation). *)

          (*
                  n1                           n1
                   .---. n3                     .---. n3
                   |\  |                        |  /|
                   | \ |          --->          | / |
                n4 |__\|                     n4 |/__|
                       n2                           n2
          *)
        in
          node_removetriangle (n1, (n4, n2));
          node_removetriangle (n1, (n2, n3));

          node_removetriangle (n2, (n4, n1));
          node_removetriangle (n2, (n1, n3));

          node_removetriangle (n3, (n1, n2));
          node_removetriangle (n4, (n2, n1));

          node_addtriangle (n1, (n3, n4));
          node_addtriangle (n2, (n4, n3));

          node_addtriangle (n3, (n4, n1));
          node_addtriangle (n3, (n2, n4));

          node_addtriangle (n4, (n1, n3));
          node_addtriangle (n4, (n3, n2));

          S.removetriangle s (n1, n2, n4);
          S.removetriangle s (n1, n3, n2);

          S.addtriangle s (n1, n3, n4);
          S.addtriangle s (n2, n4, n3);

          true
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
          val dist = IntMaths.distance_squared ((x, y), (nx, ny))
        in
          maybeupdate (dist, n)
        end
    in
      app trynode (nodes s);
      !best_result
    end

  (* PERF With some kind of spatial data structure this could be
     much faster. *)
  fun gettriangle (s : keyedtesselation) (x, y) : (key * triangle) option =
    let
      fun findany nil = NONE
        | findany ((tri as (N (ref { coords = coordsa, ... }),
                            N (ref { coords = coordsb, ... }),
                            N (ref { coords = coordsc, ... }))) :: rest) =
        let
          val joined = KM.intersectWith (fn (a, b) => (a, b)) (coordsa, coordsb)
          val joined = KM.intersectWith (fn ((a, b), c) => (a, b, c))
                                        (joined, coordsc)
          (* PERF don't need to create the whole list.. *)
          val l = KM.listItemsi joined
          fun findkey nil = findany rest
            | findkey ((k, (a, b, c)) :: more) =
              if IntMaths.pointinside (a, b, c) (x, y)
              then SOME (k, tri)
              else findkey more
        in
          findkey l
        end
    in
      findany (triangles s)
    end

  structure IIM = SplayMapFn(type ord_key = IntInf.int
                             val compare = IntInf.compare)
  structure IM = SplayMapFn(type ord_key = int
                            val compare = Int.compare)

  local
    structure W = WorldTF
  in
    fun totf ktos (s : keyedtesselation)
        : W.keyedtesselation * (node -> int) =
      let
        val next = ref 0
        val idmap : int NM.map ref = ref NM.empty
        fun getid n =
          case NM.find (!idmap, n) of
            NONE => (idmap := NM.insert (!idmap, n, !next);
                     next := !next + 1;
                     getid n)
          | SOME x => x

        fun onetriangle (a, b) = (getid a, getid b)
        fun onecoord (k, (x, y)) = (ktos k, x, y)
        fun onenode (node as (N (ref { id : IntInf.int,
                                       coords,
                                       triangles : (node * node) list }))) =
          W.N { id = getid node,
                coords = map onecoord (KM.listItemsi coords),
                triangles = map onetriangle triangles }
        val nodes = map onenode (nodes s)
      in
        print (todebugstring s ^ "\n");
        (W.KT { nodes = nodes },
         (fn n =>
          case NM.find (!idmap, n) of
            NONE => raise Key.exn "Node not found -- wrong tesselation?"
          | SOME id => id))
      end

    fun fromtf stok (W.KT { nodes } : W.keyedtesselation) :
        keyedtesselation * (int -> node) =
      let
        val ctr = ref 0
        val nodemap : node IM.map ref = ref IM.empty

        val allnodes : node list ref = ref nil

        fun makenode (W.N { id, coords, triangles = _ }) =
          case IM.find (!nodemap, id) of
            SOME _ => raise Key.exn "duplicate IDs in input"
          | NONE =>
              let
                val coords =
                  foldl (fn ((s, x, y), m) =>
                         case stok s of
                           NONE => raise Key.exn "unparseable key"
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
            NONE => raise Key.exn "bug"
          | SOME (node as N (r as ref { id = idi, coords, triangles = _ })) =>
              let
                fun oneid i =
                  case IM.find (!nodemap, i) of
                    NONE => raise Key.exn "unknown id in input"
                  | SOME n => n

                fun onet (a, b) =
                  let
                    val an = oneid a
                    val bn = oneid b

                    val ai = IntInf.fromInt a
                    val bi = IntInf.fromInt b
                  in
                    if idi = ai orelse idi = bi orelse ai = bi
                    then raise Key.exn
                      ("node " ^ IntInf.toString idi ^
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
        (K { ctr = ctr, nodes = allnodes, triangles = alltriangles },
         (fn i =>
          case IM.find (!nodemap, i) of
              NONE => raise Key.exn ("node " ^ Int.toString i ^
                                     " not found -- wrong tesselation?")
            | SOME node => node))
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
                            then raise Key.exn "degenerate triangle"
                            else ()
                    in
                        (case IIM.find (!seen, id) of
                             NONE => seen := IIM.insert (!seen, id, (node, ref false))
                           | SOME (nnn, _) =>
                               if nnn <> node
                               then raise Key.exn "Duplicate IDs"
                               else ());
                        app onetri triangles
                    end

                fun onetriangle (a, b, c) =
                    let fun looky (node as (N (ref { id, ... }))) =
                        case IIM.find (!seen, id) of
                          NONE => raise Key.exn ("Didn't find " ^
                                                 IntInf.toString id ^
                                                 " in node list")
                        | SOME (nnn, saw) =>
                            if nnn <> node
                            then raise Key.exn ("Node in triangle not " ^
                                                "the same as in node list")
                            else saw := true
                    in
                        looky a;
                        looky b;
                        looky c
                    end

                fun checkmissing (i, (_, ref false)) =
                    raise Key.exn ("Didn't find " ^ IntInf.toString i ^
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
        ignore (fromtf (totf s))
    end
*)

end
