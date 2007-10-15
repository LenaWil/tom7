
structure Window :> WINDOW =
struct

    datatype window =
        W of { x : int ref,
               y : int ref,
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
            SDL.fillrect (surf, x, y,
                          w + left + right,
                          1,
                          light_color);
            (* XXX left, right, bottom as well *)

            SDL.fillrect (surf, x, y,
                          w + left + right,
                          h + top + bottom,
                          border_color);

            drawtitle (surf, x + border, y + border);
            (* finally, draw child *)
            child_draw (surf, x + left, y + bottom, w, h)
        end

    (* XXX *)
    fun handleevent (W { ... }) evt =
(*
             andalso x >= !editx 
             andalso y >= !edity
             andalso x < !editx + (MARGIN * 2) + (TILEW * EDITW)
             andalso y < !edity + (MARGIN * 2 + MARGIN_TOP) + (TILEH * EDITH)
*)
        let in
            print "window event handler unimplemented\n";
            false
        end

end
