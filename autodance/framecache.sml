structure FrameCache :> FRAMECACHE =
struct

  exception FrameCache of string

  structure IM = SplayMapFn(type ord_key = int
                            val compare = Int.compare)

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  type cache =
      { getfilename : int -> string,
        frames_left : int ref,
        width : int,
        height : int,
        (* XXX use intinf? *)
        seq : int ref,
        (* (age, pixels) *)
        frames : (int ref * Word8.word Array.array) IM.map ref }

  (* Load frame from disk. *)
  fun loadframe filename =
      case SDL.Image.load filename of
          NONE => raise FrameCache ("Can't load file " ^ filename)
        | SOME surf =>
              let in
                  eprint ("[cache] Loaded " ^ filename ^ "\n");
                  SDL.pixels surf
                  before
                  SDL.freesurface surf
              end

  fun create_fn mf f =
      let
          (* Must exist. Used to determine width and height. *)
          val (width, height, pixels) = loadframe (f 0)

          val im = IM.insert (IM.empty, 0, (ref 0, pixels))
      in
          if mf <= 0
          then raise FrameCache "max_frames must be at least 1"
          else ();

          { getfilename = f,
            frames_left = ref (mf - 1),
            width = width,
            height = height,
            seq = ref 1,
            frames = ref im }
      end

  fun create _ nil = raise FrameCache "must be at least one frame."
    | create mf l =
      let val v = Vector.fromList l
      in create_fn mf (fn i => Vector.sub(v, i))
      end

  fun create_pattern { max, prefix, padto, first, suffix } =
      let
          fun f n =
              let val s = Int.toString (first + n)
                  val s = StringUtil.padex #"0" (~padto) s
              in prefix ^ s ^ suffix
              end
      in
          create_fn max f
      end

  fun width ({ width, ... } : cache) = width
  fun height ({ height, ... } : cache) = height

  fun get (cache as { getfilename, frames_left, width, height, seq, frames }) framenum =
      (* If it's in the cache, easy. Update its sequence so that we know it's
         recently used. *)
      case (IM.find (!frames, framenum), !frames_left) of
          (NONE, 0) =>
              (* No space for more frames. Erase the oldest frame and
                 recurse. *)
              let
                  fun older (k, (s, _), (seqno, key)) =
                      if !s < seqno
                      then (!s, k)
                      else (seqno, key)
              in
                  case IM.foldli older (!seq, ~1) (!frames) of
                      (_, ~1) => raise FrameCache "bug"
                    | (_, k) =>
                      let in
                          eprint ("[cache] discarded " ^ Int.toString k ^ "\n");
                          frames_left := 1;
                          frames := #1 (IM.remove (!frames, k));
                          get cache framenum
                      end
              end
        | (NONE, _) =>
              (* Before we've filled the cache, or after the recursive
                 call in the preceding case. *)
              let
                  val (w, h, pixels) = loadframe (getfilename framenum)
              in
                  if width <> w orelse height <> h
                  then raise FrameCache ("Frame " ^ Int.toString framenum ^
                                         " did not have consistent dimension")
                  else ();

                  frames := IM.insert (!frames, framenum, (ref (!seq), pixels));
                  seq := !seq + 1;
                  frames_left := !frames_left - 1;
                  pixels
              end
        | (SOME (age, pixels), _) =>
              (* Already got it. Just need to update age. *)
              let in
                  age := !seq;
                  seq := !seq + 1;
                  pixels
              end

end
