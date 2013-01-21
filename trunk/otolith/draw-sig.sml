signature DRAW =
sig

  (* mixcolor (r, g, b, a) *)
  val mixcolor : Word32.word * Word32.word * Word32.word * Word32.word -> Word32.word

  (* drawline (pixels, x0, y0, x1, y1, color) *)
  val drawline : Word32.word Array.array * int * int * int * int * Word32.word -> unit

  (* drawline (pixels, x0, y0, x1, y1, segment)
     Same, but give a non-empty segment to be repeated over and over.
     As a special case, if the value of the segment is 0, no pixel is drawn.
     Otherwise, its full RGBA value is written with no alpha blending.
     [0wxFFFFFFFF, 0wx00000000] gives a dotted line, for example. *)
  val drawlinewith : Word32.word Array.array *
                     int * int * int * int *
                     Word32.word Vector.vector -> unit

  (* drawcircle (pixels, x0, y0, radius, color) *)
  val drawcircle : Word32.word Array.array * int * int * int * Word32.word -> unit

  val blit : { dest : int * int * Word32.word Array.array,
               src : Images.image,
               srcrect : { x: int, y: int, width: int, height: int } option,
               dstx : int,
               dsty : int } -> unit

  val drawtext : Word32.word Array.array * Font.font * int * int * string -> unit

  (* Draws low-level noise background *)
  val randomize : Word32.word Array.array -> unit

  (* Draws louder noise background *)
  val randomize_loud : Word32.word Array.array -> unit

  (* XXX Configurable? *)
  val scanline_postfilter : Word32.word Array.array -> unit

  (* mixpixel_postfilter pctfrac mixfrac pixels
     pctfrac in [0, 1] tells us how often to mix color channels with
     adjacent pixels.
     mixfrac in [0, 1] tells us the strength of mixing. (Currently
     always behaves as though it's 1.0).
     *)
  val mixpixel_postfilter : real -> real -> Word32.word Array.array -> unit

end