(* This is the description of what is currently "displayed", and the
   routine to draw that display to the actual screen. *)
functor SceneFn(val screen : SDL.surface) :> SCENE =
struct

  (* PERF could keep 'lastscene' and only draw changes? *)
  structure S = Sprites
  structure U = Util
  structure Font = S.Font
  structure FontHuge = S.FontHuge
  structure FontSmall = S.FontSmall
  val height = S.height
  val width = S.gamewidth

  open SDL

  val TICKSPERPIXEL = 2
  val MAXAHEAD = 1200
  val DRAWLAG = S.NUTOFFSET * TICKSPERPIXEL

  val BEATCOLOR    = color(0wx77, 0wx77, 0wx77, 0wxFF)
  val MEASURECOLOR = color(0wxDD, 0wx22, 0wx22, 0wxFF)
  val TSCOLOR      = color(0wx22, 0wxDD, 0wx22, 0wxFF)

  (* for random mode *)
  val lastcolor = ref(SDL.color (0wx00, 0wx55, 0wx00, 0wxFF))
  val nexttime = ref (SDL.getticks())

  val background =
    ref (Setlist.BG_SOLID (SDL.color (0wx00, 0wx55, 0wx00, 0wxFF)))
    : Setlist.background ref

  val title = ref ""
  val artist = ref ""
  val year = ref ""
  val timesig = ref ""
  val progress = ref ""

  (* in ms. *)
  val STATSTIME = 0w13000

  (* Stats end after this time. *)
  val statstime = ref (0w0 : Word32.word)
  val prev = ref (NONE : { song : string,
                           medals : Hero.medal list,
                           percent : real } option)

  fun settimesig (n, d) =
    timesig := "^3" ^ Int.toString n ^ "^1/^3" ^ Int.toString d ^ "^1 time"


  (* XXX maybe init from stats so we don't get staging of
     push and this wrong? *)
  fun initfromsong ({ artist = aa, year = yy, title = tt, fave, hard, ... } :
                    Setlist.songinfo, thislevel, totallevels) =
    let in
      title := tt;
      artist := aa;
      year := yy;
      statstime := (SDL.getticks() + STATSTIME);
      prev :=
      (case Stats.prev () of
         NONE => NONE
       | SOME { final = ref NONE, ... } => NONE (* ?? *)
       | SOME { song, final = ref (SOME { percent, medals, ... }), ... } =>
           SOME { song = #title (Setlist.getsong song),
                  percent = percent,
                  medals = medals });
      if totallevels > 1
      then progress := "^2level ^3" ^ Int.toString thislevel ^ "^2/^3" ^
               Int.toString totallevels
      else progress := ""
    end

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
     (height - (mynut + S.STARHEIGHT div TICKSPERPIXEL)) -
         (stary div TICKSPERPIXEL),
     evt) :: !stars

  fun addtext (s, t) =
    let in
      (* XXX *)
      (* print ("Add text: '" ^ s ^ "' @" ^ Int.toString t ^ "\n"); *)
      texts := (s, (height - mynut) - (t div TICKSPERPIXEL)) :: !texts
    end

  fun addbar (b, t) =
    let
      val (c, s, h) =
        case b of
          Hero.Beat => (BEATCOLOR, "", 2)
        | Hero.Measure => (MEASURECOLOR, "", 5)
        | Hero.Timesig (n, d) => (TSCOLOR, "^3" ^ Int.toString n ^ "^0/^3" ^
                                  Int.toString d ^ "^4 time", 8)
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
    let
      val now = SDL.getticks ()
    in
      (* clear non-game area *)
      (case !background of
         Setlist.BG_SOLID c =>
           SDL.fillrect (screen, Sprites.gamewidth, 0,
                         Sprites.width - Sprites.gamewidth, Sprites.height, c)
       | Setlist.BG_RANDOM ticks =>
           let in
             if now >= !nexttime
             then
               let in
                 lastcolor :=
                 SDL.color(Word8.fromInt (Random.random_int() mod 256),
                           Word8.fromInt (Random.random_int() mod 256),
                           Word8.fromInt (Random.random_int() mod 256),
                           0wxFF);
                 nexttime := now + (Word32.fromInt ticks)
               end
             else ();
             SDL.fillrect (screen,
                           Sprites.gamewidth, 0,
                           Sprites.width - Sprites.gamewidth, Sprites.height,
                           !lastcolor)
           end);

      (* background image first *)
      blitall(S.background, screen, 0, 0);

      (* Song info. *)
      Font.draw (screen, Sprites.gamewidth + 16, 4, "^3" ^ !title);
      Font.draw (screen, Sprites.gamewidth + 16, 4 + Font.height + 2,
                 "^4by ^0" ^ !artist);
      Font.draw (screen, Sprites.gamewidth + 16, 4 + (Font.height + 2) * 2,
                 "   ^1(" ^ !year ^ ")");

      (* Prev stats. *)
      (case (now <= !statstime, !prev) of
         (true, SOME { song, medals, percent }) =>
           let in
             FontSmall.draw (screen, Sprites.gamewidth + 16,
                             Sprites.height - 128, "^3Last: ^0" ^ song);
             ListUtil.appi
             (fn (m, i) =>
              let
                val x = Sprites.gamewidth + 16 + i * 72
              in
                SDL.blitall(Sprites.medalg m, screen, x, Sprites.height - 100);
                FontSmall.draw(screen,
                               x, Sprites.height - 32, Sprites.medal1 m);
                FontSmall.draw(screen,
                               x, Sprites.height - 16, Sprites.medal2 m)
              end) medals;

             FontHuge.draw(screen, Sprites.width - (FontHuge.width * 4 + 8),
                           Sprites.height - 128,
                           "^1" ^ Int.toString (Real.trunc percent) ^ "^4%")
           end
         | _ => ());

      (* spans first *)
      app (fn (x, y, w, h) =>
           blit(S.backlite, x, y, w, h, screen, x, y)) (!spans);

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
      U.for 0 (Hero.FINGERS - 1)
      (fn i =>
       if Array.sub(State.fingers, i)
       then blitall(Vector.sub(S.fingers, i), screen,
                    (S.STARWIDTH div 4) + 6 + i * (S.STARWIDTH + 18),
                    (height - S.NUTOFFSET) - (S.STARWIDTH div 2))
       else ());

      app (fn (s, y) =>
           let in
             (* XXX *)
             (* print ("Text at y=" ^ Int.toString y ^ ": " ^ s ^ "\n"); *)
             if FontHuge.sizex_plain s > (width - 16)
             then Font.draw(screen, 4, y - Font.height, s)
             else FontHuge.draw(screen, 4, y - FontHuge.height, s)
           end) (!texts);

      (if Stats.misses() > 0
       then FontHuge.draw (screen, 4, height - (FontHuge.height + 6),
                           "^2" ^ Int.toString (Stats.misses()) ^ " ^4 misses")
       else ());

      let
        val s = Match.streak()
        val (fd, fh, ff) =
          if s > 75
          then (Sprites.FontMax.draw, Sprites.FontMax.height, Chars.fancy)
          else if s > 50
               then (FontHuge.draw, FontHuge.height, Chars.fancy)
               else (FontHuge.draw, FontHuge.height, (fn s => "^4" ^ s))
      in
        if s > 25
        then fd (screen, 4, height div 2 - (fh div 2),
                 ff (Int.toString s ^ " streak!"))
        else ()
      end;

      FontHuge.draw(screen,
                    Sprites.gamewidth + 16,
                    height - (FontHuge.height * 4),
                    !timesig);

      FontHuge.draw(screen,
                    Sprites.gamewidth + 16,
                    height - (FontHuge.height * 8),
                    !progress);

      FontSmall.draw(screen,
                     Sprites.gamewidth + 16,
                     height - (FontHuge.height * 3),
                     "Dance distance: ^2" ^
                     Real.fmt (StringCvt.FIX (SOME 3)) (!State.dancedist) ^
                     "^0m")
    end

end
