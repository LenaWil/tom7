
structure Constants =
struct

  val WIDTH = 320
  val HEIGHT = 200

  (* obviously not this small... *)
  val WORLD_WIDTH = 8
  val WORLD_HEIGHT = 8

  val PIXELSCALE = 4

  exception Impossible of string


end