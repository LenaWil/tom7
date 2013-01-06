signature DRAW =
sig

  (* mixcolor (r, g, b, a) *)
  val mixcolor : Word32.word * Word32.word * Word32.word * Word32.word -> Word32.word

  (* drawline (pixels, x0, y0, x1, y1, color) *)
  val drawline : Word32.word Array.array * int * int * int * int * Word32.word -> unit

  (* Draws low-level noise background *)
  val randomize : Word32.word Array.array -> unit

  (* XXX Configurable? *)
  val scanline_postfilter : Word32.word Array.array -> unit

end