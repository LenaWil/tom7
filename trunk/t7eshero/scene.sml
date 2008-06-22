(* This is the description of what is currently "displayed", and the
   routine to draw that display to the actual screen. *)
(* XXX sig *)
functor SceneFn(val screen : SDL.surface
                val missnum : int ref) =
struct

  (* PERF could keep 'lastscene' and only draw changes? *)
  structure S = Sprites
  structure Font = S.Font
  structure FontHuge = S.FontHuge
  val height = S.height
  val width = S.width

  open SDL

  val TICKSPERPIXEL = 2
  (* how many ticks forward do we look? *)
  val MAXAHEAD = 1200
  (* how many MIDI ticks in the past do we draw? *)
  val DRAWLAG = S.NUTOFFSET * TICKSPERPIXEL

  val BEATCOLOR    = color(0wx77, 0wx77, 0wx77, 0wxFF)
  val MEASURECOLOR = color(0wxDD, 0wx22, 0wx22, 0wxFF)
  val TSCOLOR      = color(0wx22, 0wxDD, 0wx22, 0wxFF)

  (* color, x, y *)
  val stars = ref nil : (int * int * int * Match.scoreevt) list ref
  (* rectangles the liteup background to draw. x,y,w,h *)
  val spans = ref nil : (int * int * int * int) list ref
  (* type, y, message, height *)
  val bars  = ref nil : (color * int * string * int) list ref

  val texts = ref nil : (string * int) list ref

  (* XXX strum, etc. *)

  fun clear () =
    let in
      stars := nil;
      spans := nil;
      bars  := nil;
      texts := nil
    end

  val mynut = 0

  fun addstar (finger, stary, evt) =
    (* XXX fudge city *)
    stars := 
    (finger,
     (S.STARWIDTH div 4) +
     6 + finger * (S.STARWIDTH + 18),
     (* hit star half way *)
     (height - (mynut + S.STARHEIGHT div TICKSPERPIXEL)) - (stary div TICKSPERPIXEL),
     evt) :: !stars

  fun addtext (s, t) =
      let in
          texts := (s, (height - mynut) - (t div TICKSPERPIXEL)) :: !texts
      end

  fun addbar (b, t) = 
    let 
      val (c, s, h) = 
        case b of
          Hero.Beat => (BEATCOLOR, "", 2)
        | Hero.Measure => (MEASURECOLOR, "", 5)
        | Hero.Timesig (n, d) => (TSCOLOR, "^3" ^ Int.toString n ^ "^0/^3" ^ Int.toString d ^ "^4 time", 8)
    in
        bars := (c, (height - mynut) - (t div TICKSPERPIXEL), s, h) :: !bars
    end

  fun addspan (finger, spanstart, spanend) =
    spans :=
    (21 + finger * (S.STARWIDTH + 18), 
     (height - mynut) - spanend div TICKSPERPIXEL,
     18 (* XXX *),
     (spanend - spanstart) div TICKSPERPIXEL) :: !spans

  fun draw () =
    let in
      (* entire background first first *)
      blitall(S.background, screen, 0, 0);
      (* spans first *)

      app (fn (x, y, w, h) => blit(S.backlite, x, y, w, h, screen, x, y)) (!spans);

      (* tempo *)
      app (fn (c, y, s, h) => 
           if y < (height - S.NUTOFFSET)
           then 
               let in
                   fillrect(screen, 16, y - (h div 2), width - 32, h, c);
                   FontHuge.draw(screen, 4, y - (h div 2) - FontHuge.height, s)
               end
           else ()) (!bars);

      (* stars on top *)
      app (fn (f, x, y, e) => 
           let 
               fun drawnormal () =
                   let in
                       if Match.hammered e
                       then blitall(Vector.sub(S.hammers, f), screen, x, y)
                       else blitall(Vector.sub(S.stars, f), screen, x, y)
                   end
           in
               (* blitall(Vector.sub(S.stars, f), screen, x, y); *)

               (* plus icon *)
               (case Match.state e of
                    Hero.Missed => blitall(S.missed, screen, x, y)
                  | Hero.Hit n =>
                        if y >= ((height - S.NUTOFFSET) - (S.STARHEIGHT div 2))
                        then
                            (if !n >= Vector.length S.zaps
                             then ()
                             else (blitall(Vector.sub(S.zaps, !n), screen, 
                                           x - ((S.ZAPWIDTH - S.STARWIDTH) div 2),
                                           y - ((S.ZAPHEIGHT - S.STARHEIGHT) div 2));
                                   n := !n + 1))
                        else drawnormal ()
                  | _ => drawnormal ())
           end) (!stars);

      (* finger state *)
      Util.for 0 (Hero.FINGERS - 1)
      (fn i =>
       if Array.sub(State.fingers, i)
       then blitall(Vector.sub(S.fingers, i), screen, 
                    (S.STARWIDTH div 4) + 6 + i * (S.STARWIDTH + 18),
                    (height - S.NUTOFFSET) - (S.STARWIDTH div 2))
       else ());

      app (fn (s, y) =>
           if FontHuge.sizex_plain s > (width - 64)
           then Font.draw(screen, 4, y - Font.height, s) 
           else FontHuge.draw(screen, 4, y - FontHuge.height, s)) (!texts);

      if !missnum > 0
      then FontHuge.draw (screen, 4, height - (FontHuge.height + 6),
                          "^2" ^ Int.toString (!missnum) ^ " ^4 misses")
      else ()

    end

end
