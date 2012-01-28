(* This is a cache to manage frames that live on disk.
   It behaves as an array of frames that can be accessed
   randomly, but may keep them cached so that repeated
   access does not require loading from disk each time. *)

signature FRAMECACHE =
sig

  exception FrameCache of string
  type cache

  (* create max_frames frame_names

     Create a cache that holds at most max_frames in
     memory at once. The list of frames form the
     array, in the given order. It must be non-empty.

     Once the cache is filled, updating it with a new
     frame is linear in its size (but costs are probably
     dominated by GC and disk access for any reasonable
     size cache).

     Any file that SDL_Image can load is supported.
     They must all have the same exact dimensions. *)
  val create : int -> string list -> cache

  (* To load "dancey0005.png" (as the 0th frame) and so on,
     { prefix = "dancey", suffix = ".png",
       padto = 4, first = 5, ... }

     At least one frame must actually exist.
     If the numbers are not padded, just use a padto of
     zero or one.
     *)
  val create_pattern : { max : int,
                         prefix : string,
                         padto : int,
                         first : int,
                         suffix : string } -> cache

  (* create_fn max_frames frame_name

     frame_name generates the filename from the frame number
     (expected to be constant). Frame 0 must exist, since it
     is used to determine the width and height. *)
  val create_fn : int -> (int -> string) -> cache

  (* Every frame must have the same width and height *)
  val height : cache -> int
  val width : cache -> int

  (* Returns 4 * width * height RGBA pixels. *)
  val get : cache -> int -> Word8.word Array.array

end
