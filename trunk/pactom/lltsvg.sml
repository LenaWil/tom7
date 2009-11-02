(* Print the latlon tree for the western hemisphere, as svg. *)
structure Radial = 
struct
  structure G = PacTom.G

  fun msg s = TextIO.output(TextIO.stdErr, s ^ "\n")

  val pt = PacTom.fromkmlfiles ["pactom.kml", "pac2.kml"]
      handle e as (PacTom.PacTom s) =>
          let in
              msg s;
              raise e
          end

  val () = msg ("There are " ^ Int.toString (Vector.length (PacTom.paths pt)) ^ 
                " paths\n" ^
                "      and " ^ Int.toString (Vector.length (PacTom.overlays pt)) ^ 
                " overlays")

  val llt = PacTom.latlontree pt
  val () = LatLonTree.tosvg llt 12 true print 

end