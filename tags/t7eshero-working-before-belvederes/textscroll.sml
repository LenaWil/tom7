
functor TextScroll(F : FONT) : TEXTSCROLL =
struct

    structure LN = LastNBuffer

    datatype textscroll =
        T of { x : int, y : int,
               w : int, h : int,
               border : SDL.color option,
               back : SDL.color option,
               content : string LN.buffer }

    (* XXX better failure mode if we can't fit ANY lines (we get div-by-zero I think) *)
    fun make { x, y, width, height, bordercolor, bgcolor } = T
        { x = x, y = y, w = width, h = height, border = bordercolor, back = bgcolor,
          (* number of full lines that can fit. start empty. *)
          content = LN.buffer (height div (F.height), "") }

    (* XXX from textscroll *)
    val DEFAULT_BGCOLOR = SDL.color (0wx26, 0wx26, 0wx26, 0wxAA)
    val DEFAULT_BORDERCOLOR = SDL.color (0wx00, 0wx00, 0wx00, 0wxFF)

    fun draw screen (T{ x, y, w, h, border, back, content }) =
        let in
            Option.app (fn b => SDL.fillrect (screen, x, y, w, h, b));
            (* XXX draw border *)
            Util.for 0 (LN.length content - 1)
            (fn i =>
             let val i = (LN.length content - 1) - i (* backwards *)
             in F.draw (screen, x, y + F.height * i, LN.sub(content, i))
             end)
        end

    fun write (T{ content, ... }) s = LN.push_back (content, s)
    fun rewrite (T{ content, ... }) s = LN.update (content, LN.length content - 1, s)
    fun clear (T{ content, ... }) =
        Util.for 0 (LN.length content - 1)
        (fn i => LN.update(content, i, ""))

end