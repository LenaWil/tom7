
structure HighlightMain =
struct

  val mapsrc = Params.param "locator_map_base.svg"
        (SOME("-source",
              "The source map."))
        "source"

  val out = Params.param ""
        (SOME("-o",
              "The file to write."))
        "out"

  val () =
    case Params.docommandline () of
      [n, c] =>
        let
          val m = !mapsrc
          val out = (case !out of
                       "" => let val (base, ext) = FSUtil.splitext m
                             in
                               base ^ n ^ "." ^ ext
                             end
                     | f => f)

          val s = StringUtil.readfile m
          val s = Highlight.highlight s n c
        in
          StringUtil.writefile out s
        end
    | _ =>
        let in
          print "highlight [-source map.svg] [-o out.svg] neighborhood_name COLORX\n"
        end

end