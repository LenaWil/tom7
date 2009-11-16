signature PACTOM =
sig

    exception PacTom of string

    (* Pactom data *)
    type pactom
    val paths : pactom -> (LatLon.pos * real) Vector.vector Vector.vector
    val overlays : pactom -> { href : string, 
                               rotation : real, 
                               alpha : Word8.word,
                               north : real, south : real,
                               east : real, west : real } Vector.vector

    val projectpaths : LatLon.projection -> pactom ->
        { (* x, y, elevation *)
          paths : (real * real * real) Vector.vector Vector.vector,
          (* bounding rectangle in projected space *)
          bounds : Bounds.bounds }


    val home : LatLon.pos

    val fromkmlfile : string -> pactom
    val fromkmlfiles : string list -> pactom

    (* Loads neighborhoods kml, normalizes, and returns the data.
       The kml must consist only of <LinearRing> geometric elements,
       because it assumes that all <coordinates> tags contain polygons. *)
    val neighborhoodsfromkml : string -> (string * LatLon.pos Vector.vector) Vector.vector

(*
    val projectnormalizepolys : LatLon.projection 
(real * real) list
*)

    (* Distances are accurate great-circle distances, ignoring elevation. *)
    structure G : UNDIRECTEDGRAPH where type weight = real

    (* As indices into the vector of paths, and into those paths. *)
    type waypoint = { path : int, pt : int }
    (* Put every point into a data structure for querying by location.
       Each is associated with the path it's from, by index into the vector. *)
    val latlontree : pactom -> waypoint LatLonTree.tree

    (* Compute the graph of reachability, which is all of the points in the
       paths, connected when they are close enough to imply connectedness. *)
    val graph : pactom -> { graph : waypoint G.graph,
                            (* Same indices as in original paths. *)
                            promote : waypoint -> waypoint G.node,
                            (* Same as above. *)
                            latlontree : waypoint LatLonTree.tree }

    (* A minimal spanning tree, rooted at the node closest to the given
       position.
       For each node, it has its distance back to the root (or NONE, if
       unreachable), and if it is reachable, then the parent node to 
       take to get there (except for the root, which is NONE). *)
    val spanning_graph : pactom -> LatLon.pos ->
                           { graph : waypoint G.span G.graph,
                             promote : waypoint -> waypoint G.span G.node }

    val rand : unit -> Word32.word
    (* As hex string (rrggbb) *)
    val randomanycolor : unit -> string
    (* High saturation and value, random hue. *)
    val randombrightcolor : unit -> string

    (* Suitable for XML output. Avoids expontential notation
       and tilde for negative. (XXX should also cap out or fail on inf, nan) *)
    val rtos : real -> string

    (* Give viewport. Generator is a freeform html-safe string; ignored if blank. *)
    val svgheader : { x : int, y : int, 
                      width : int, height : int, 
                      generator : string } -> string
    val svgfooter : unit -> string

end