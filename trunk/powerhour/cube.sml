
structure SampleCube =
struct
  val minutesp = Params.param "60" (SOME ("-minutes",
                                        "Number of minutes.")) "minutes"
  val statesp = Params.param "3" (SOME ("-states",
                                        "Number of cup states.")) "states"
  val playersp = Params.param "2" (SOME ("-players",
                                        "Number of players.")) "players"

  val nolinesp = Params.flag false (SOME ("-nolines",
                                          "Don't draw grid lines.")) "nolines"

  val nonumsp = Params.flag false (SOME ("-nonums",
                                         "Don't number labels.")) "nonums"

  val yawp = Params.param "0.0" (SOME ("-yaw", "Yaw in degrees.")) "yaw"
  val pitchp = Params.param "0.0" (SOME ("-pitch", "Pitch in degrees.")) "pitch"
  val rollp = Params.param "0.0" (SOME ("-roll", "Roll in degrees.")) "roll"


  structure IIM = SplayMapFn(type ord_key = IntInf.int
                             val compare = IntInf.compare)

  fun torad d = (d / 360.0) * 2.0 * Math.pi

  type mat3 = (real * real * real *
               real * real * real *
               real * real * real)
  (* column vector *)
  type vec3 = (real *
               real *
               real)

  fun mul33 (a, b, c,
             d, e, f,
             g, h, i) (aa, bb, cc,
                       dd, ee, ff,
                       gg, hh, ii) =
      (a*aa + b*dd + c*gg, a*bb + b*ee + c*hh, a*cc + b*ff + c*ii,
       d*aa + e*dd + f*gg, d*bb + e*ee + f*hh, d*cc + e*ff + f*ii,
       g*aa + h*dd + i*gg, g*bb + h*ee + i*hh, g*cc + h*ff + i*ii)

  fun rot_yaw a : mat3 =
      let val cosa = Math.cos a
          val sina = Math.sin a
      in
          (cosa, ~sina, 0.0,
           sina, cosa, 0.0,
           0.0, 0.0, 1.0)
      end

  fun rot_pitch a : mat3 =
      let val cosa = Math.cos a
          val sina = Math.sin a
      in
          (cosa, 0.0, sina,
           0.0, 1.0, 0.0,
           ~sina, 0.0, cosa)
      end

  fun rot_roll a : mat3 =
      let val cosa = Math.cos a
          val sina = Math.sin a
      in
          (1.0, 0.0, 0.0,
           0.0, cosa, ~sina,
           0.0, sina, cosa)
      end

  fun vec3timesmat33 (a, b, c,
                      d, e, f,
                      g, h, i) (x,
                                y,
                                z) : vec3 =
      (a * x + b * y + c * z,
       d * x + e * y + f * z,
       g * x + h * y + i * z)

  fun rot (yaw, pitch, roll) =
      let
          val mr = rot_roll roll
          val mp = rot_pitch pitch
          val my = rot_yaw yaw
          val m = mul33 mp my
          val m = mul33 mr m
      in
          vec3timesmat33 m
      end

  fun go () =
  let
    val MINUTES = Params.asint 60 minutesp
    val NSTATES = Params.asint 7 statesp
    val NPLAYERS = Params.asint 2 playersp
    val DRAWLINES = not (!nolinesp)
    val DRAWNUMS = not (!nonumsp)

    val YAW = torad (Params.asreal 0.0 yawp)
    val PITCH = torad (Params.asreal 0.0 pitchp)
    val ROLL = torad (Params.asreal 0.0 rollp)

    val rotate : vec3 -> vec3 = rot (YAW, PITCH, ROLL)

    val cxpointfile = "checkpoint-" ^ Int.toString MINUTES ^ "m-" ^
        Int.toString NPLAYERS ^ "p-" ^
        Int.toString NSTATES ^ "s.tf"

    val SamplesTF.DB { entries = db } = SamplesTF.DB.fromfile cxpointfile

    exception Illegal
    val allcounts = ref (IIM.empty)
    val totalcount = ref (0 : IntInf.int)
    fun setct (_, _, s) =
        case IntInf.fromString s of
            NONE => raise Illegal
          | SOME i =>
                let in
                    totalcount := !totalcount + i;
                    allcounts := IIM.insert(!allcounts, i, ())
                end
    val () = app setct db

    (* All unique counts, ascending *)
    val allcounts = map (fn (k, ()) => k) (IIM.listItemsi (!allcounts))
    val allcounts : IntInf.int vector = Vector.fromList allcounts

    val maxcount = Real.fromLargeInt (Vector.sub (allcounts,
                                                  Vector.length allcounts - 1))

    (* Get the rank of i within 0..|maxcount|-1. It is expected
       that the number appears in the list! *)
    exception Bug
    (* PERF can use binary search obviously, but this whole program finishes
       in under a second *)
    fun getrank i =
        case VectorUtil.findi (fn x => x = i) allcounts of
            NONE => raise Bug
          | SOME (idx, _) => idx
    fun getfrac i =
        real (getrank i) / real (Vector.length allcounts - 1)

    val rtos = Real.fmt (StringCvt.FIX (SOME 2))
    val rtos3 = Real.fmt (StringCvt.FIX (SOME 3))
    val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

    (* Open and write... *)

    val f = TextIO.openOut ("sample" ^ Int.toString MINUTES ^ "min" ^
                            Int.toString NPLAYERS ^ "players" ^
                            Int.toString NSTATES ^ "states.svg")
    fun fprint s = TextIO.output (f, s)

    val GRAPHIC_SIZE = 1024
    val LABEL_WIDTH = 64
    val LABEL_HEIGHT = 64
    val LABEL_GAP = 7

    (* XXX make parameters or derive from rotation *)
    val SCALE = 0.66
    val OMSCALE = 1.0 - SCALE
    val SCALE_SIZE = real GRAPHIC_SIZE * SCALE
    val XOFFSET = real GRAPHIC_SIZE * OMSCALE * 0.5
    val YOFFSET = real GRAPHIC_SIZE * OMSCALE * 0.5 + 24.0

    val CELL_WIDTH = real GRAPHIC_SIZE / real (MINUTES + 1)

    (* All cells with their z depth, so that we can
       output them in order. *)
    val allcells = ref (nil : (real * string) list)

    fun onecell (x :: y :: z :: _, _, s) =
      let
          val pt = (real x / real MINUTES,
                    real y / real MINUTES,
                    real z / real MINUTES)
          val pt = rotate pt

          val ct = (valOf (IntInf.fromString s))
          val f = getfrac ct
          val ff = 1.0 - f
          val ff = 0.175 + 0.825 * f
          (* lighten points so that we can see
             through them *)
          val ff = ff * 0.25

          val (xx, yy, zz) = pt

          val xx = xx * SCALE_SIZE + XOFFSET
          val yy = yy * SCALE_SIZE + YOFFSET
          (* val rad = 2.0 + (1.0 - zz) * 4.0 *)
          val rad = 3.0 + (1.0 - zz) * 7.0
          val rad = if rad < 0.01 then 0.01 else rad
      in
          allcells :=
          (zz, "<circle cx=\"" ^ rtos xx ^ "\" " ^
           "cy=\"" ^ rtos yy ^ "\" " ^
           "r=\"" ^ rtos rad ^ "\" fill=\"#000\" " ^
           "opacity=\"" ^ rtos3 ff ^ "\" />\n") :: !allcells
      end

    val () = app onecell db
    val order = Util.byfirst (Util.descending Real.compare)
    val allcells = ListUtil.sort order (!allcells)

  in
      print ("There are " ^ Int.toString (length db) ^ " possibilities\n" ^
             "from " ^ IntInf.toString (!totalcount) ^ " samples.\n");

      fprint (TextSVG.svgheader { x = 0, y = 0,
                                  width = GRAPHIC_SIZE +
                                  (if DRAWNUMS then LABEL_WIDTH else 0),
                                  height = GRAPHIC_SIZE +
                                  (if DRAWNUMS then LABEL_HEIGHT else 0),
                                  generator = "grid.sml" });

      if DRAWLINES
      then
      let in
        (* Vertical grid lines *)
        Util.for 0 MINUTES
        (fn i =>
         let val x = CELL_WIDTH * real i
         in
             fprint ("<polyline fill=\"none\" stroke=\"#AAA\" " ^
                     "stroke-width=\"0.5\" points=\""); (* " *)
             fprint (rtos x ^ "," ^ rtos 0.0 ^ " " ^
                     rtos x ^ "," ^ rtos (real GRAPHIC_SIZE));
             fprint ("\" />\n") (* " *)
         end);

        (* Horizontal grid lines *)
        Util.for 0 MINUTES
        (fn i =>
         let val y = CELL_WIDTH * real i
         in
             fprint ("<polyline fill=\"none\" stroke=\"#AAA\" " ^
                     "stroke-width=\"0.5\" points=\""); (* " *)
             fprint (rtos 0.0 ^ "," ^ rtos y ^ " " ^
                     rtos (real GRAPHIC_SIZE) ^ "," ^ rtos y);
             fprint ("\" />\n") (* " *)
         end)
      end else ();

      (* Fill in the grid *)
      app (fn (z, line) => fprint line) allcells;

      if DRAWNUMS
      then
      let in
        (* Vertical labels, at right. *)
        Util.for 0 MINUTES
        (fn i =>
         fprint (TextSVG.svgtext
                 { x = CELL_WIDTH * real (MINUTES + 1) + real LABEL_GAP,
                   y = real i * CELL_WIDTH + (0.7 * CELL_WIDTH),
                   face = "Franklin Gothic Medium",
                   size = 0.6 * CELL_WIDTH,
                   text = [("#000", Int.toString i)] } ^ "\n"));

        (* Horizontal labels, on bottom *)
        Util.for 0 MINUTES
        (fn i =>
         fprint (TextSVG.svgtext
                 { x = real i * CELL_WIDTH + (0.2 * CELL_WIDTH),
                   y = CELL_WIDTH * real (MINUTES + 1) + real LABEL_GAP * 1.5,
                   face = "Franklin Gothic Medium",
                   size = 0.6 * CELL_WIDTH,
                   text = [("#000", Int.toString i)] } ^ "\n"))
      end else ();

      fprint (TextSVG.svgfooter ());
      TextIO.closeOut f;
      print "Done.\n"
  end
end

val () = Params.main0 "This program takes no arguments." SampleCube.go
