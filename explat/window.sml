
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
                  title_height,
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
                          border_color);

            (* highlights *)
            (* XXX only if border *)
            SDL.fillrect (surf, x, y,
                          w + left + right,
                          1,
                          light_color);
            (* XXX left, right, bottom as well *)


            drawtitle (surf, x + border, y + border);
            (* finally, draw child *)
            child_draw (surf, x + left, y + top, w, h)
        end

    (* XXX *)
    fun handleevent (W { x = ref x, y = ref y, w = ref w, h = ref h, 
                         border, title_height, click,
                         ... }) evt =
        let 
            val left = border
            val right = border
            val bottom = border
            val top = border + title_height
        in
            case evt of 
                SDL.E_MouseDown { x = mx, y = my, ... } =>
                    if mx >= x andalso
                       my >= y andalso
                       mx < x + w + left + right andalso
                       my < y + w + top + bottom
                    then 
                        let
                        (* clicked in window. what kind of click was it? *)
                        in
                            if my < y + top
                            then
                                let in
                                    print "TITLEBAR-click\n";
                                    true
                                end
                            else
                                let in
                                    print "CLIENT-click\n";
                                    click (mx - (x + left),
                                           my - (y + top));
                                    true
                                end
                        end
                    else false
              | _ => 
                let in
                    print "window event handler unimplemented\n";
                    false
                end
        end


    fun dims (W { w, h, ...}) = { w = !w, h = !h }
end
