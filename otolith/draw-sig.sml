signature DRAW =
sig

  (* mixcolor (r, g, b, a) *)
  val mixcolor : Word32.word * Word32.word * Word32.word * Word32.word -> Word32.word

  (* drawline (pixels, x0, y0, x1, y1, color) *)
  val drawline : Word32.word Array.array * int * int * int * int * Word32.word -> unit

  (* drawcircle (pixels, x0, y0, radius, color) *)
  val drawcircle : Word32.word Array.array * int * int * int * Word32.word -> unit

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