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

  val WIDTH = 1024
  val HEIGHT = 768
  val PIXELS_PER_METER = 50
  val METERS_PER_PIXEL = 1.0 / real PIXELS_PER_METER
  val screen = makescreen (WIDTH, HEIGHT)

  fun eprint s = TextIO.output (TextIO.stdErr, s)
  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  (* fun vtos v = rtos (vec2x v) ^ "," ^ rtos (vec2y v) *)

  (* val () = SDL.show_cursor false *)

  fun tometers d = real d * METERS_PER_PIXEL
  fun toworld (xp, yp) =
      let
          val xp = xp - (WIDTH div 2)
          val yp = yp - (HEIGHT div 2)
      in
          (tometers xp, tometers yp)
      end

  val DRAW_NORMALS = false
  val DRAW_DISTANCES = true
  val DRAW_RAYS = true
  val DRAW_COLLISIONS = true

  structure GA = GrowArray

  type poly = vec2 GA.growarray
  type letter =
      (* Add graphics, ... *)
      { polys: poly GA.growarray }

  fun copyletter { polys } =
      { polys = GA.fromlist (map GA.copy (GA.tolist polys)) }
      handle Subscript => (eprint "copyletter"; raise Subscript)

  (* Only if they are structurally equal (order of polygons and
     vertices matters). Used to deduplicate undo state. *)
  local exception NotEqual
  in
      fun lettereq ({ polys = ps }, { polys = pps }) =
          let in
              if GA.length ps <> GA.length pps
              then raise NotEqual
              else ();
              Util.for 0 (GA.length ps - 1) 
              (fn i =>
               let val p = GA.sub ps i
                   val pp = GA.sub pps i
               in
                   if GA.length p <> GA.length pp
                   then raise NotEqual
                   else ();
                   Util.for 0 (GA.length p - 1)
                   (fn j =>
                    if not (vec2eq (GA.sub p j, GA.sub pp j))
                    then raise NotEqual
                    else ())
               end);
              true
          end handle NotEqual => false
  end

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

     
  (* Put the origin of the world at WIDTH / 2, HEIGHT / 2.
     make the viewport show 8 meters by 6. *)
  fun topixels d = d * real PIXELS_PER_METER
  fun toscreen (xm, ym) =
      let
          val xp = topixels xm
          val yp = topixels ym
      in
          (Real.round xp + (WIDTH div 2),
           Real.round yp + (HEIGHT div 2))
      end

  fun vectoscreen v = toscreen (vec2xy v)
  fun screentovec (x, y) = vec2 (toworld (x, y))
  fun screendistance ((x, y), (xx, yy)) =
      Math.sqrt (real ((x - xx) * (x - xx) +
                       (y - yy) * (y - yy)))

  fun screendistance_squared ((x, y), (xx, yy)) =
      (x - xx) * (x - xx) +
      (y - yy) * (y - yy)

  val mousex = ref 0
  val mousey = ref 0
  val mousedown = ref false

  (* returns the point on the line segment between v1 and v2 that is
     closest to the pt argument. If this is one of v1 or v2, NONE is
     returned. *)
  fun closest_point (pt : vec2, v1 : vec2, v2 : vec2) : vec2 option =
    let
        val (px, py) = vec2xy pt
        val (v1x, v1y) = vec2xy v1
        val (v2x, v2y) = vec2xy v2
        val u = ((px - v1x) * (v2x - v1x) +
                 (py - v1y) * (v2y - v1y)) / distance_squared (v1, v2)
    in
        (* PERF: could do negative test before dividing *)
        if u < 0.0 orelse u > 1.0
        then NONE
        else SOME (vec2 (v1x + u * (v2x - v1x),
                         v1y + u * (v2y - v1y)))
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
               SDL.drawline (screen, x, y, xx, yy, WHITE);

               (* For debugging? Would be kind of nice to show
                  when/where we would insert a point, if clicking. *)
               case closest_point (vm, v1, v2) of
                   NONE => ()
                 | SOME v =>
                       let val (x, y) = vectoscreen v
                       in SDL.drawcircle (screen, x, y, 2, GREY)
                       end
           end)
      end

  (* Currently selected vertices. First index is the polygon,
     second is the vertex on that polygon. Often nil. *)
  val selected = ref nil : (int * int) list ref

  fun drawpolyvertices (sel : int list, poly : poly) =
      let
          val num = GA.length poly
      in
          Util.for 0 (num - 1)
          (fn i =>
           let 
               val (x, y) = vectoscreen (GA.sub poly i)
           in
               if List.exists (fn x => x = i) sel
               then SDL.drawcircle (screen, x, y, 3, RED)
               else SDL.drawcircle (screen, x, y, 2, PURPLE)
           end)
      end


  fun drawletter (letter as { polys, ... } : letter) =
      let
          val num = GA.length polys
      in
          Util.for 0 (num - 1)
          (fn i => drawpoly (GA.sub polys i));

          (* Draw vertices. *)
          Util.for 0 (num - 1)
          (fn i => drawpolyvertices (List.mapPartial 
                                     (fn (p, v) => if p = i then SOME v
                                                   else NONE) (!selected),
                                     GA.sub polys i));
          ()
      end

  (* From the BSD-licensed code by Wm. Randolph Franklin.
     See sml-lib/geom/polygon.sml, which is the same but uses
     a different representation of polygons. *)
  fun pointinside (p : poly) (v : vec2) =
      let
          (* val () = eprint ("pointinside " ^ vtos v ^ "?\n") *)
          val (x, y) = vec2xy v
          fun xcoord i = vec2x (GA.sub p i)
          fun ycoord i = vec2y (GA.sub p i)
          val nvert = GA.length p
          fun loop odd idx jdx =
              if idx = nvert
              then odd
              else loop (if ((ycoord idx > y) <> (ycoord jdx > y)) andalso
                             (x < ((xcoord jdx - xcoord idx) * (y - ycoord idx) / 
                                   (ycoord jdx - ycoord idx) + xcoord idx))
                         then not odd
                         else odd) (idx + 1) idx
      in
          loop false 0 (nvert - 1)
      end

  exception Done

  (* Can do better than this... *)
  fun trivialpolygon v =
      GA.fromlist [vec2 (0.0, 1.0) :+: v,
                   vec2 (1.0, 0.0) :+: v,
                   vec2 (~0.5, ~0.5) :+: v]

  (* XXX way to set snapping preference *)
  val snapping = ref true
  val undostate = UndoState.undostate () : letter UndoState.undostate
  val letter = ref { polys = GA.fromlist [trivialpolygon (vec2 (0.0, 0.0))] }

  (* Call before making a modification to the state. Keeps the buffer
     length from exceeding MAX_UNDO. Doesn't duplicate the state if it
     is already on the undo buffer. *)
  val MAX_UNDO = 100
  fun savestate () =
      let in
          (case UndoState.peek undostate of
               NONE => UndoState.save undostate (copyletter (!letter))
             | SOME prev =>
                   if lettereq (prev, !letter)
                   then ()
                   else UndoState.save undostate (copyletter (!letter)));
          UndoState.truncate undostate MAX_UNDO
      end

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
                   ) (#polys (!letter));
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
                   ) (#polys (!letter));
          (Math.sqrt (!best_dist), !best_vs)
      end

  (* val findclosestpoints = findclosestpointsnoton nil *)

  (* XXX *)
  fun drawmenu () =
      let
          val pfx = "^3Toward body editor^<: "
          val items = [("n", "new")]

      in
          Font.draw (screen, 0, 0, pfx);
          Font.draw (screen, WIDTH - 100, 0,
                     "^1" ^
                     Int.toString (UndoState.history_length undostate) ^ 
                     "^< undo ^1" ^
                     Int.toString (UndoState.future_length undostate))
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
                if GA.exists (fn p => pointinside p v) (#polys (!letter))
                then SDL.drawpixel (screen, x * DENSITY, y * DENSITY, BROWN)
                else ()
            end
            ))
      end

  fun draw () =
      let in
          drawletter (!letter);
          drawinterior ();
          drawmenu ()
      end

  (* XXX should prevent the polygon from becoming concave or non-simple. *)
  (* XXX should put the polygon in correct winding order. *)
  fun setvertices idxs vnew =
      let 
          (* when snapping, only do it to vertices on OTHER polygons. *)
          val dest =
              case findclosestpointsnoton (map #1 idxs) vnew of
                  (dist, (pi, vi) :: _) =>
                      if !snapping andalso topixels dist < 5.0
                      then GA.sub (GA.sub (#polys (!letter)) pi) vi
                      else vnew
                 | _ => vnew

      in
          (* Don't save undo every time, because then we have the whole history
             of dragging, which is silly. *)
          app (fn (pi, vi) => 
               GA.update (GA.sub (#polys (!letter)) pi) vi dest) idxs
      end

  fun mousemotion (x, y) =
      let in 
          mousex := x;
          mousey := y;
          if !mousedown
          then setvertices (!selected) (screentovec (x, y))
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
                     case closest_point (v, GA.sub poly i, GA.sub poly i2) of
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
              let val p = GA.sub (#polys (!letter)) pi
              in 
                  eprint "insert.\n";
                  GA.insertat p (vi + 1) v
              end

      in
          (* XXX should dedupe so that we only add once per poly;
             this would be quite difficult to make happen *)
          GA.appi onepoly (#polys (!letter));
          eprint ("Closest is " ^ rtos (topixels (!closest_dist)) ^ " away\n");
          (* Is the closest one close enough? *)
          if topixels (!closest_dist) <= 8.0
          then (app insert (!closest_idx);
                (* Select these. They're one after the index we recorded. *)
                selected := map (fn (p, v) => (p, v + 1)) (!closest_idx);
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
      (* Currently, select the closest point. *)
      let 
          fun nearenough (i, j) =
              let val (xx, yy) = 
                  vectoscreen
                  (GA.sub (GA.sub (#polys (!letter)) i) j)
              in
                  (x - xx) * (x - xx) +
                  (y - yy) * (y - yy) < 8 * 8
              end

          val nearby = pointswithinscreendistance 8 (x, y)
          val () = eprint ("There are " ^ Int.toString (length nearby) ^ " nearby.\n")
              (*
          val nearby = List.filter nearenough nearby
          val () = eprint ("filt: " ^ Int.toString (length nearby) ^ " nearby.\n")
          *)

          val mv = screentovec (x, y)
      in
          (* XXX won't need to save if dragging to select *)
          savestate ();
          mousedown := true;
          (* Always set, maybe clearing the selection if there
             were no nearby points. *)
          selected := nearby;
          (* If there were no points selected, then maybe another
             action. *)
          if List.null nearby andalso not (maybeinsert (x, y))
          then 
              (* If we didn't create a new point, then we make
                 a new polygon. *)
              GA.append (#polys (!letter)) (trivialpolygon mv)
          else ();
          (* Simulate mouse motion. *)
          mousemotion (x, y)
      end

  (* XXX require ctrl for undo/redo, etc. *)
  fun keydown SDLK_ESCAPE = raise Done
    | keydown SDLK_z =
      (* XXX shouldn't allow undo when dragging? *)
      (case UndoState.undo undostate of
           NONE => ()
         | SOME s => letter := copyletter s)
    | keydown SDLK_y =
      (case UndoState.redo undostate of
           NONE => ()
         | SOME s => letter := copyletter s)
    | keydown _ = ()

  fun events () =
      case pollevent () of
          NONE => ()
        | SOME evt =>
           case evt of
               E_Quit => raise Done
             | E_KeyDown { sym } => keydown sym
             | E_MouseMotion { state : mousestate, x : int, y : int, ... } =>
                   mousemotion (x, y)
             | E_MouseDown { button = 1, x, y, ... } => leftmouse (x, y)
             | E_MouseUp _ =>
                   let in
                       mousedown := false
                   end
             | _ => ()

  fun loop () =
      let in
          (* XXX don't need to continuously be drawing. *)          
          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          draw ();

          flip screen;

          events ();
          delay 0;
          loop ()
      end

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
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end
                   
end

