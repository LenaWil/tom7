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
          minx : real, maxx : real, miny : real, maxy : real }

    val home : LatLon.pos

    val fromkmlfile : string -> pactom
    val fromkmlfiles : string list -> pactom

    (* Put every point into a data structure for querying by location.
       Each is associated with the path it's from.
       *)
    val latlontree : (LatLon.pos * real) Vector.vector Vector.vector ->
        { path : int, pt : int } LatLonTree.latlontree

    val rand : unit -> Word32.word
    (* As hex string (rrggbb) *)
    val randomanycolor : unit -> string
    (* High saturation and value, random hue. *)
    val randombrightcolor : unit -> string

    (* Suitable for XML output. Avoids expontential notation
       and tilde for negative. (XXX should also cap out or fail on inf, nan) *)
    val rtos : real -> string

end