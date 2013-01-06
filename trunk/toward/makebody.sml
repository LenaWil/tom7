(* This is a body editor for a new game, codename TOWARD.

   It allows (or will, when it's workin'?) to build a collection of
   bodies, each of which is a collection of fixtures (low-vertex
   convex polygons) in fixed relative positions. It probably needs
   to associate some kind of graphic with the body (which is just
   for the physics simulation), but that will have to wait for
   GL support.
*)

structure MakeBody =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:

  structure BDD = BDDWorld(
    type fixture_data = unit
    type body_data = string
    type joint_data = unit)
  open BDD
  exception MakeBody of string

  structure U = Util
  open SDL
  structure Util = U

  structure M = Maths
  structure E = Editing

  val LETTERFILE = "letter.toward"
  val ALPHABETFILE = "alphabet.toward"

  structure Font = FontFn
  (val surf = Images.requireimage "font.png"
   val charmap =
       " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
       "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* " *)
   val width = 9
   val height = 16
   val styles = 6
   val overlap = 1
   val dims = 3)

  structure FontSmall = FontFn
  (val surf = Images.requireimage "fontsmalloutlined.png"
   val charmap =
       " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
       "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* " *)
   val width = 7
   val height = 7
   val styles = 1
   val overlap = 1
   val dims = 3)

  val WIDTH = 1024
  val HEIGHT = 768
  val PIXELS_PER_METER = ref 50.0
  (* val METERS_PER_PIXEL = 1.0 / real PIXELS_PER_METER *)
  val screen = makescreen (WIDTH, HEIGHT)

  val scrollx = ref 64  (* (WIDTH div 2) *)
  val scrolly = ref (HEIGHT - 128) (* (HEIGHT div 2) *)

  fun eprint s = TextIO.output (TextIO.stdErr, s)
  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  fun vtos v = rtos (vec2x v) ^ "," ^ rtos (vec2y v)

  type letter = Letter.letter

  val () = SDL.set_cursor Images.pointercursor

  fun tometers d = (* real d * METERS_PER_PIXEL *)
      real d / !PIXELS_PER_METER

  fun toworld (xp, yp) =
      let
          val xp = xp - !scrollx
          val yp = yp - !scrolly
      in
          (tometers xp, tometers yp)
      end

  (* Put the origin of the world at WIDTH / 2, HEIGHT / 2.
     make the viewport show 8 meters by 6. *)
  fun topixels d = d * !PIXELS_PER_METER
  fun toscreenx xm = Real.round (topixels xm) + !scrollx
  fun toscreeny ym = Real.round (topixels ym) + !scrolly
  fun toscreen (xm, ym) = (toscreenx xm, toscreeny ym)

  fun vectoscreen v = toscreen (vec2xy v)
  fun screentovec (x, y) = vec2 (toworld (x, y))
  fun screendistance ((x, y), (xx, yy)) =
      Math.sqrt (real ((x - xx) * (x - xx) +
                       (y - yy) * (y - yy)))

  fun screendistance_squared ((x, y), (xx, yy)) =
      (x - xx) * (x - xx) +
      (y - yy) * (y - yy)

  val DRAW_NORMALS = false
  val DRAW_DISTANCES = true
  val DRAW_RAYS = true
  val DRAW_COLLISIONS = true

  structure GA = GrowArray

  type poly = Maths.poly

  (* 0xRRGGBB *)
  fun hexcolor c =
      let
          val b = c mod 256
          val g = (c div 256) mod 256
          val r = ((c div 256) div 256) mod 256
      in
          SDL.color (Word8.fromInt r,
                     Word8.fromInt g,
                     Word8.fromInt b,
                     0w255)
      end

  val mousex = ref 0
  val mousey = ref 0
  val mousedown = ref false

  fun drawangle (v1, v2, v3) =
      let
          val a = M.angle (v1, v2, v3)
          val (x, y) = vectoscreen v2
      in
          Font.draw (screen, x, y, rtos a)
      end

  val PURPLE = hexcolor 0xFF00FF
  val RED = hexcolor 0xFF0000
  val WHITE = hexcolor 0xFFFFFF
  val GREY = hexcolor 0x888888
  val BROWN = hexcolor 0x999900
  fun drawpoly (poly : poly) =
      let
          val num = GA.length poly
          val vm = screentovec (!mousex, !mousey)

          val color = if M.issimple poly
                      then WHITE
                      else RED
      in
          Util.for 0 (num - 1)
          (fn i =>
           let val i2 = if i = num - 1
                        then 0
                        else i + 1
               val v1 = GA.sub poly i
               val v2 = GA.sub poly i2

               val (x, y) = vectoscreen v1
               val (xx, yy) = vectoscreen v2
           in
               SDL.drawline (screen, x, y, xx, yy, color);

               (* For debugging? Would be kind of nice to show
                  when/where we would insert a point, if clicking. *)
               case M.closest_point (vm, v1, v2) of
                   NONE => ()
                 | SOME v =>
                       let val (x, y) = vectoscreen v
                       in SDL.drawcircle (screen, x, y, 2, GREY)
                       end
           end)
      end

  (* Workspace state is maintained in Editing structure. *)
  val () = Editing.loadfromfile ALPHABETFILE

  (* These are not maintained in the workspace; so you lose them
     if you switch between letters. *)
  (* Holding space *)
  val dragging = ref false
  (* Holding shift *)
  val selecting = ref false
  (* If SOME, then this is the top-left of the selection. *)
  val selection = ref NONE : vec2 option ref
  fun getselection () =
      case !selection of
          SOME s => SOME (Maths.orienttobox (s, screentovec (!mousex, !mousey)))
        | NONE => NONE
  (* XXX way to set snapping preference *)
  val snapping = ref true

  fun drawpolyvertices (sel : int list, poly : poly) =
      let
          val num = GA.length poly

          (* Returns true if the point WOULD be selected if the user
             released the mouse button. This is only the case when we
             are in the midst of a selection. *)
          val wouldselect =
              (case getselection() of
                   NONE => (fn _ => false)
                 | SOME (a, b) =>
                   let
                       val (ax, ay) = vec2xy a
                       val (bx, by) = vec2xy b
                   in
                       fn v =>
                       let val (vx, vy) = vec2xy v
                       in
                           vx >= ax andalso vy >= ay andalso
                           vx <= bx andalso vy <= by
                       end
                   end)

      in
          Util.for 0 (num - 1)
          (fn i =>
           let
               val v = GA.sub poly i
               val (x, y) = vectoscreen v
           in
               if List.exists (fn x => x = i) sel
               then (SDL.drawcircle (screen, x, y, 3, RED);
                     SDL.drawcircle (screen, x, y, 4, RED))
               else if wouldselect v
                    then SDL.drawcircle (screen, x, y, 3, RED)
                    else SDL.drawcircle (screen, x, y, 2, PURPLE)
           end)
      end

  fun drawpolyangles poly =
      Util.for 0 (GA.length poly - 1)
      (fn i =>
       drawangle (M.previous_vertex poly i,
                  M.vertex poly i,
                  M.next_vertex poly i))

  fun drawletter ({ polys, ... } : letter) =
      let
          val num = GA.length polys
      in
          Util.for 0 (num - 1)
          (fn i => drawpoly (GA.sub polys i));

          (* Draw vertices. *)
          Util.for 0 (num - 1)
          (fn i => drawpolyvertices (List.mapPartial
                                     (fn (p, v) => if p = i then SOME v
                                                   else NONE) (E.selected()),
                                     GA.sub polys i));

          Util.for 0 (num - 1)
          (fn i => drawpolyangles (GA.sub polys i));

          ()
      end

  (* Can do better than this... *)
  fun trivialpolygon v =
      GA.fromlist [vec2 (~0.5, ~0.5) :+: v,
                   vec2 (1.0, 0.0) :+: v,
                   vec2 (0.0, 1.0) :+: v]

  (* For the following, we could use kd-trees to make the lookup much
     faster, but we have to maintain the tree, which is expensive and
     tricky. Realistically there won't be more than a few hundred
     vertices and the distance test is cheap. *)
  (* Find points within the given distance from v. *)
  fun pointswithinscreendistance dist v =
      let
          val dd = dist * dist
          val vs = ref (nil : (int * int) list)
      in
          GA.appi (fn (i, poly)  =>
                   GA.appi (fn (j, vertex) =>
                            if screendistance_squared (v,
                                                       vectoscreen vertex) <= dd
                            then vs := (i, j) :: !vs
                            else ()) poly
                   ) (#polys (E.letter()));
          !vs
      end

  fun pointswithinrectangle (a, b) =
      let
          val vs = ref (nil : (int * int) list)

          (* Is there a better trick for this? *)
          val (ax, ay) = vec2xy a
          val (bx, by) = vec2xy b
          fun inside v =
           let val (vx, vy) = vec2xy v
           in
               vx >= ax andalso vy >= ay andalso
               vx <= bx andalso vy <= by
           end
      in
          GA.appi (fn (i, poly)  =>
                   GA.appi (fn (j, vertex) =>
                            if inside vertex
                            then vs := (i, j) :: !vs
                            else ()) poly
                   ) (#polys (E.letter()));
          !vs
      end


  (* Return the indices of the vertices closest to the point.
     Ignores points on polygons whose indices are in the disallowed_polys
     list. *)
  (* XXX also don't allow selection of two points on the same poly!
     They would have to be coincident though, so maybe we can just
     maintain that as a representation invariant. *)
  fun findclosestpointsnoton disallowed_polys v =
      (* PERF could use kd-tree but have to maintain it, which is expensive.
         Realistically there won't be more than a few hundred vertices. *)
      let
          (* Every point that goes in here will be exactly coincident. *)
          val best_dist = ref 999999999999.0
          val best_vs = ref (nil : (int * int) list)
      in
          GA.appi (fn (i, poly)  =>
                   if not (List.exists (fn p => i = p) disallowed_polys)
                   then GA.appi (fn (j, vertex) =>
                                 let val d = distance_squared (v, vertex)
                                 in
                                     if d < !best_dist
                                     then (best_dist := d;
                                           best_vs := [(i, j)])
                                     else if Real.== (d, !best_dist)
                                          then (best_vs := (i, j) :: !best_vs)
                                          else ()
                                 end) poly
                   else ()
                   ) (#polys (E.letter()));
          (Math.sqrt (!best_dist), !best_vs)
      end

  (* val findclosestpoints = findclosestpointsnoton nil *)

  (* XXX *)
  fun drawmenu () =
      let
          val pfx = ("^3Toward body editor^<: " ^ Int.toString (!scrollx) ^
                     ", " ^ Int.toString (!scrolly))
          val items = [("n", "new")]

      in
          Font.draw (screen, 0, 0, pfx);
          Font.draw (screen, WIDTH - 100, 0,
                     "^1" ^
                     Int.toString (UndoState.history_length (E.undostate ())) ^
                     "^< undo ^1" ^
                     Int.toString (UndoState.future_length (E.undostate ())))
      end

  fun drawinterior () =
      let
          val DENSITY = 8
      in
          Util.for 0 (HEIGHT div DENSITY - 1)
          (fn y =>
           Util.for 0 (WIDTH div DENSITY - 1)
           (fn x =>
            (* Test against every polygon. *)
            let
                val v = screentovec (x * DENSITY, y * DENSITY)
            in
                if GA.exists (fn p => M.pointinside p v) (#polys (E.letter()))
                then SDL.drawpixel (screen, x * DENSITY, y * DENSITY, BROWN)
                else ()
            end
            ))
      end

  (* Draws 1m grid.
     PERF: This only depends on the zoom and pan so
     we should probably precompute it on a surface and just blit it. *)
  val GRIDCOLOR = hexcolor 0x222222
  val AXESCOLOR = hexcolor 0x444444
  val ORIGINCOLOR = hexcolor 0x772222
  fun drawgrid () =
      let
          (* Allow the window to be scrollable / zoomable. *)
          val (LEFT_EDGE, TOP_EDGE) = toworld (0, 0)
          val (RIGHT_EDGE, BOTTOM_EDGE) = toworld (WIDTH - 1, HEIGHT - 1)

          (* Determine the meter marks between which we draw. *)

          val (ox, oy) = toscreen (0.0, 0.0)
      in

          (* Grid lines every meter. *)
          Util.for (Real.floor TOP_EDGE) (Real.ceil BOTTOM_EDGE)
          (fn ym =>
           let val yp = toscreeny (real ym)
           in SDL.drawline (screen, 0, yp, WIDTH - 1, yp, GRIDCOLOR)
           end);

          Util.for (Real.floor LEFT_EDGE) (Real.ceil RIGHT_EDGE)
          (fn xm =>
           let val xp = toscreenx (real xm)
           in SDL.drawline (screen, xp, 0, xp, HEIGHT - 1, GRIDCOLOR)
           end);

          (* Draw axes. *)
          SDL.drawline (screen, 0, oy, WIDTH - 1, oy, AXESCOLOR);
          SDL.drawline (screen, ox, 0, ox, HEIGHT - 1, AXESCOLOR);

          (* Draw cross on origin. *)
          SDL.drawline (screen, ox - 3, oy, ox + 3, oy, ORIGINCOLOR);
          SDL.drawline (screen, ox, oy - 3, ox, oy + 3, ORIGINCOLOR)
      end


  val SELCOLOR = hexcolor 0xAAAA33
  fun drawselection () =
      case getselection() of
          SOME (a, b) =>
              let val (ax, ay) = vectoscreen a
                  val (bx, by) = vectoscreen b
              in
                  SDL.drawbox (screen, ax, ay, bx, by, SELCOLOR)
              end
        | NONE => ()

  fun draw () =
      let in
          (* XXX don't need to continuously be drawing. *)
          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          drawgrid ();

          drawletter (E.letter());
          drawinterior ();
          drawselection ();

          drawmenu ();

          flip screen
      end

  (* Prevent the polygon from becoming convex or non-simple.
     TODO: It would be better if we searched to find the closest legal
     spot. It's kind of a bad feeling to have the point just stick as you
     drag. *)
  fun okay_to_move_to idxs dest =
      List.all (fn (pi, vi) =>
                let
                    val p = GA.copy (GA.sub (#polys (E.letter())) pi)
                in
                    GA.update p vi dest;
                    M.issimple p
                end) idxs

  (* Same, but with the same delta rather than absolute destination. *)
  fun okay_to_move_by idxs delta =
      let
          (* Have to move the vertices at the same time to test if the
             polygon is still simple. *)
          val together = ListUtil.stratify Int.compare idxs
      in
          List.all (fn (pi, vis) =>
                    let
                        val p = GA.copy (GA.sub (#polys (E.letter())) pi)
                    in
                        app (fn vi =>
                             let val old = GA.sub p vi
                             in GA.update p vi (old :+: delta)
                             end) vis;
                        M.issimple p
                    end) together
      end

  (* XXX should put the polygon in correct winding order.
     (It currently seems impossible to turn them inside-out?) *)
  fun setvertices idxs vnew =
      let
          (* when snapping, only do it to vertices on OTHER polygons. *)
          val dest =
              case findclosestpointsnoton (map #1 idxs) vnew of
                  (dist, (pi, vi) :: _) =>
                      if !snapping andalso topixels dist < 5.0
                      then GA.sub (GA.sub (#polys (E.letter())) pi) vi
                      else vnew
                 | _ => vnew

      in
          if okay_to_move_to idxs dest
          then
              (* Don't save undo every time, because then we have the
                 whole history of dragging, which is silly. *)
              app (fn (pi, vi) =>
                   GA.update (GA.sub (#polys (E.letter())) pi) vi dest) idxs
          else ()
      end


  (* XXX HERE.
     This is nontrivial because moving the points might make polygons
     non-simple. *)
  fun nudge (dx, dy) =
    let val v = vec2 (tometers dx, tometers dy)
    in
        if okay_to_move_by (E.selected()) v
        then
          let in
              (* maybe should only save at the end of a series of nudges? *)
              E.savestate ();
              app
              (fn (pi, vi) =>
               let val old = GA.sub (GA.sub (#polys (E.letter())) pi) vi
               in
                   GA.update (GA.sub (#polys (E.letter())) pi) vi (old :+: v)
               end) (E.selected())
          end
        else ()
    end

  fun pan (dx, dy) =
      let in
          scrollx := !scrollx + dx;
          scrolly := !scrolly + dy
      end

  fun mousemotion (x, y) =
      if !dragging
      then
      let in
          pan (x - !mousex, y - !mousey);
          mousex := x;
          mousey := y
      end
      else if !selecting
      then
      let in
          mousex := x;
          mousey := y
      end
      else
      let in
          mousex := x;
          mousey := y;
          if !mousedown
          then setvertices (E.selected()) (screentovec (x, y))
          else ()
      end

  (* From a click at screen coordinates (x, y), maybe insert a
     point if it is close enough to a line segment on an existing
     polygon. *)
  fun maybeinsert (x, y) =
      let
          val v = screentovec (x, y)
          val closest_dist = ref 9999999.0

          (* Can be multiple. This is for the common case that we
             add a point on a coincident segment *)
          val closest_idx = ref (nil : (int * int) list)

          fun onepoly (j, poly) =
            let val num = GA.length poly
            in
                Util.for 0 (num - 1)
                (fn i =>
                 let val i2 = if i = num - 1
                              then 0
                              else i + 1
                 in
                     case M.closest_point (v, GA.sub poly i, GA.sub poly i2) of
                         NONE => ()
                       | SOME v' =>
                             let val d = distance (v', v)
                             in
                                if d < !closest_dist
                                then (closest_dist := d;
                                      closest_idx := [(j, i)])
                                else if Real.== (d, !closest_dist)
                                     then closest_idx := (j, i) :: !closest_idx
                                     else ()
                             end
                 end)
            end

          fun insert (pi, vi) =
              let val p = GA.sub (#polys (E.letter())) pi
              in
                  eprint "insert.\n";
                  GA.insertat p (vi + 1) v
              end

      in
          (* XXX should dedupe so that we only add once per poly;
             this would be quite difficult to make happen *)
          GA.appi onepoly (#polys (E.letter()));
          eprint ("Closest is " ^ rtos (topixels (!closest_dist)) ^ " away\n");
          (* Is the closest one close enough? *)
          if topixels (!closest_dist) <= 8.0
          then (app insert (!closest_idx);
                (* Select these. They're one after the index we recorded. *)
                E.set_selected (map (fn (p, v) => (p, v + 1)) (!closest_idx));
                true)
          else false
      end

  (* Left click is where a lot of action is.

     If we're close to a point, then we select that point and any that
     are coincident with it.

     If not, but we're close to a line segment, then we add a point
     there, and select it.

     TODO: dragging to draw a selction (should require shift) *)
  fun leftmouse (x, y) =
      if !dragging
      then ()
      else if !selecting
      (* If holding shift, then start a selection. *)
      then
        let
        in selection := SOME (screentovec (x, y));
           mousemotion (x, y)
        end
      else
        (* Plain click means either select a close-by point, create a new
           point if close to an edge, or otherwise make a new trivial poly. *)
        let
            val nearby = pointswithinscreendistance 8 (x, y)
            val () = eprint ("There are " ^ Int.toString (length nearby) ^ " nearby.\n")

            val mv = screentovec (x, y)
        in
            (* XXX won't need to save if dragging to select *)
            E.savestate ();
            mousedown := true;
            (* Always set, maybe clearing the selection if there
               were no nearby points. *)
            E.set_selected nearby;
            (* If there were no points selected, then maybe another
               action. *)
            if List.null nearby andalso not (maybeinsert (x, y))
            then
                (* If we didn't create a new point, then we make
                   a new polygon. *)
                GA.append (#polys (E.letter())) (trivialpolygon mv)
            else ();
            (* Simulate mouse motion. *)
            mousemotion (x, y)
        end

  (* Upon releasing the mouse, apply the selection if we have one. *)
  fun leftmouseup (x, y) =
      let in
          mousex := x;
          mousey := y;
          if !selecting
          then
              case getselection () of
                  SOME (a, b) =>
                      let in
                          (* Select every point within the box. *)
                          E.set_selected (pointswithinrectangle (a, b));
                          selection := NONE
                      end
                | _ => ()
          else ()
      end

  fun savetodisk () =
      (Editing.savetofile ALPHABETFILE;
       eprint "Saved.\n")

  fun updatecursor () =
      if !dragging
      then SDL.set_cursor Images.handcursor
      else if !selecting
           then SDL.set_cursor Images.selcursor
           else SDL.set_cursor Images.pointercursor

  exception Done

  fun switchto c =
      let in
          E.set_current (ord c);
          selection := NONE;
          selecting := false;
          updatecursor ();
          (* XXX force redraw? *)
          dragging := false;
          mousedown := false
      end

  (* XXX show menu!

     XXX Not possible to go to capital letters.
     *)
  fun get_goto () =
      case pollevent () of
          SOME E_Quit => raise Done
        | SOME (E_KeyDown { sym = SDLK_ESCAPE }) => ()
        | SOME (E_KeyDown { sym }) =>
           (case SDL.sdlkchar sym of
                NONE => get_goto ()
              | SOME c => switchto c)
        | _ => (delay 0; get_goto ())


  (* XXX require ctrl for undo/redo, etc. *)
  fun keydown SDLK_ESCAPE = raise Done
    | keydown SDLK_LSHIFT =
      (selecting := true;
       updatecursor ())
    | keydown SDLK_SPACE =
      (dragging := true;
       updatecursor ())
      (* XXX shouldn't allow undo when dragging / selecting. *)
    | keydown SDLK_z = E.undo ()
    | keydown SDLK_y = E.redo ()
    | keydown SDLK_s = savetodisk()

    | keydown SDLK_g = get_goto ()

    | keydown SDLK_UP = nudge (0, if !selecting then ~10 else ~1)
    | keydown SDLK_DOWN = nudge (0, if !selecting then 10 else 1)
    | keydown SDLK_LEFT = nudge (if !selecting then ~10 else ~1, 0)
    | keydown SDLK_RIGHT = nudge (if !selecting then 10 else 1, 0)

    | keydown _ = ()

  fun keyup SDLK_SPACE =
      (dragging := false;
       updatecursor ())
    | keyup SDLK_LSHIFT =
      (selecting := false;
       selection := NONE;
       updatecursor ())
    | keyup _ = ()

  fun events () =
      case pollevent () of
          NONE => ()
        | SOME evt =>
           case evt of
               E_Quit => raise Done
             | E_KeyDown { sym } => keydown sym
             | E_KeyUp { sym } => keyup sym
             | E_MouseMotion { state : mousestate, x : int, y : int, ... } =>
                   mousemotion (x, y)
             | E_MouseDown { button = 1, x, y, ... } => leftmouse (x, y)
             | E_MouseUp { button = 1, x, y, ... } =>
                   let in
                       mousedown := false;
                       leftmouseup (x, y)
                   end
             | E_MouseDown { button = 4, ... } =>
                   let in
                       PIXELS_PER_METER := !PIXELS_PER_METER + 2.0;
                       eprint ("scroll up\n")
                   end

             | E_MouseDown { button = 5, ... } =>
                   let in
                       PIXELS_PER_METER := !PIXELS_PER_METER - 2.0;
                       if !PIXELS_PER_METER <= 2.0
                       then PIXELS_PER_METER := 2.0
                       else ();
                       eprint ("scroll down\n")
                   end
             | _ => ()

  fun loop () =
      let in
          draw ();

          events ();
          delay 0;
          loop ()
      end
    handle Done => savetodisk ()

  val () = Params.main0 "No arguments." loop
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               BDDDynamics.BDDDynamics s => eprint s
             | BDDDynamicTree.BDDDynamicTree s => eprint s
             | BDDContactSolver.BDDContactSolver s => eprint s
             | BDDMath.BDDMath s => eprint s
             | MakeBody s => eprint s
             | Editing.Editing s => eprint s
             | Letter.Letter s => eprint s
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end

end
