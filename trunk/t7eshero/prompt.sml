
functor Prompt(F : FONT) :> PROMPT =
struct

    exception Prompt of string

    (* Perhaps should be functorized over this and instantiated in Sprites? *)
    val screen = Sprites.screen

    fun prompt { x, y, width, height, question,
                 ok, cancel, icon, 
                 bordercolor, bgcolortop, bgcolorbot,
                 parent } =
        let
            (* First figure out how big this thing should be.
               The layout is like this
                Margin LEFTM
                |        Horizontal Margin MIDM
                |        |                Margin RIGHTM
                v        v                v
               +---------------------------+
               | ,______, (MARGIN TOPM)    | \
               | | icon | Question line 1  |  |
               | '``````' Question line 2  |  > qheight
               |          Question line 3  |  |
               |          . . .            | /
               |  (vertical margin SKIPM)  | 
               | OK Message                | \ 
               | Cancel Message            | /  aheight
               | (MARGIN BOTM)             |
               +---------------------------+
                          \_______._____/
                                  qwidth
                 \____.______/
                      awidth

              If there is no icon we treat that as a 0-size icon and
              also ignore the middle margin MIDM. If the icon is longer
              than the prompt text, we use that height instead of the
              height of the question lines. *)

            fun maxlinelength l = List.foldl Int.max 0 (map F.sizex l)

            val TOPM = 4
            val MIDM = 8
            val LEFTM = 8
            val RIGHTM = 8
            val SKIPM = 4
            val BOTM = 4
            val (iwidth, iheight) = 
                case icon of 
                    NONE => (~MIDM, 0)
                  | SOME i => (SDL.surface_width i, SDL.surface_height i)
            val qlines = String.fields (fn #"\n" => true | _ => false) question
            val qheight = Int.max (iheight, length qlines * F.height)
            val aheight = F.height + (if Option.isSome cancel then F.height else 0)
            val awidth = maxlinelength (ok :: (case cancel of NONE => nil | SOME c => [c]))
            val qwidth = maxlinelength qlines

            val width = 
                case width of
                    NONE => LEFTM + RIGHTM + Int.max (iwidth + MIDM + qwidth, awidth)
                  | SOME w => w
                        
            val height =
                case height of
                    NONE => TOPM + qheight + SKIPM + aheight + BOTM
                  | SOME h => h

        in
            false (* XXX *)
        end

    fun yesno _ = raise Prompt "unimplemented"
    fun okcancel _ = raise Prompt "unimplemented"
    fun no _ = raise Prompt "unimplemented"
end