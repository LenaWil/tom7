
structure Window :> WINDOW =
struct

    datatype window =
        W of { 
               (* coordinates of window *)
               x : int ref,
               y : int ref,
               (* size of client area *)
               w : int ref,
               h : int ref,
               
               (* when dragging the window *)
               drag : (int * int) option ref,

               (* from arg *)
               click : int * int -> unit,
               keydown : SDL.sdlk -> bool,
               keyup   : SDL.sdlk -> bool,
               draw : SDL.surface * int * int * int * int -> unit,
               border : int,
               border_color : SDL.color,
               resizable : bool,
               title_height : int,
               drawtitle : SDL.surface * int * int -> unit }

    fun make { click, keydown, keyup, draw, border, border_color, resizable, 
               drawtitle,
               title_height, 
               x, y, w, h } =
        W { x = ref x, y = ref y, w = ref w, h = ref h,
            drag = ref NONE,
            resizable = resizable, border = border, border_color = border_color,
            title_height = title_height, 
            drawtitle = drawtitle, draw = draw, keyup = keyup, keydown = keydown,
            click = click }

    fun lighten c =
        let
            (* poor man's technique *)
            val (r, g, b, a) = SDL.components c
            fun l x = Word8.orb(Word8.<<(x, 0w1), x)
        in
            SDL.color (l r, l g, l b, a)
        end

    fun darken c =
        let
            val (r, g, b, a) = SDL.components c
            fun l x = Word8.div(x, 0w2)
        in
            SDL.color (l r, l g, l b, a)
        end

    fun draw (W { x = ref x, y = ref y, w = ref w, h = ref h,
                  title_height, drag,
                  border, border_color, drawtitle, 
                  draw = child_draw, ... }) surf =
        let
            val light_color = lighten border_color
            val dark_color  = darken  border_color

            val left = border
            val right = border
            val bottom = border
            val top = border + title_height
        in
            (* solid *)
            SDL.fillrect (surf, x, y,
                          w + left + right,
                          h + top + bottom,
                          if Option.isSome (!drag)
                          then light_color
                          else border_color);

            (* highlights *)
            (* XXX only if border *)
            SDL.fillrect (surf, x, y,
                          w + left + right,
                          1,
                          light_color);
            SDL.fillrect (surf, x, y,
                          1,
                          h + top + bottom,
                          light_color);

            SDL.fillrect (surf, x, y + h + top + bottom,
                          w + left + right,
                          1,
                          dark_color);
            SDL.fillrect (surf, x + w + left + right, y,
                          1,
                          h + top + bottom,
                          dark_color);

            drawtitle (surf, x + border, y + border);
            (* finally, draw child *)
            child_draw (surf, x + left, y + top, w, h)
        end

    val stfu = ref false
    (* XXX *)
    fun handleevent (W { x, y, w = ref w, h = ref h, 
                         border, title_height, click, drag,
                         ... }) evt =
        let 
            val left = border
            val right = border
            val bottom = border
            val top = border + title_height
        in
            case evt of 
            SDL.E_MouseUp { ... } => 
                (case !drag of
                     NONE => false
                   | _ => (drag := NONE; true))
          | SDL.E_MouseMotion { xrel, yrel, ... } =>
                (case !drag of
                     NONE => false
                   | SOME _ =>
                         let 
                             val x' = !x + xrel
                             val y' = !y + yrel
                             val x' = if x' < 0 then 0 else x'
                             val y' = if y' < 0 then 0 else y'
                         in
                             x := x';
                             y := y';
                             true
                         end)
          | SDL.E_MouseDown { x = mx, y = my, ... } =>
                    if mx >= !x andalso
                       mx < !x + w + left + right andalso
                       my >= !y andalso
                       my < !y + w + top + bottom
                    then 
                        let
                        (* clicked in window. what kind of click was it? *)
                        in
                            if my < !y + top
                            then
                                let in
                                    (* XXX assumes not already dragging.. *)
                                    drag := SOME (mx, my);
                                    print "start drag\n";
                                    true
                                end
                            else
                                let in
                                    print "CLIENT-click\n";
                                    click (mx - (!x + left),
                                           my - (!y + top));
                                    true
                                end
                        end
                    else false
              | _ => 
                let 
                in
                    if !stfu
                    then ()
                    else print "window event handler unimplemented\n";
                    stfu := true;
                    false
                end
        end


    fun dims (W { w, h, ...}) = { w = !w, h = !h }
end
