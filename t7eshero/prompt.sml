
structure Prompt :> PROMPT =
struct

    exception Prompt of string

    (* Perhaps should be functorized over this and instantiated in Sprites?
       Basically we should extract a library for this that can go in sdlml/
       and requires only SDL and sml-lib. We need to tell it how to interpret
       SDL events as confirming or canceling. The yesno utility functions
       need icons. *)
    structure F = Sprites.FontSmall
    val screen = Sprites.screen
    val TICKS = 0w60

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
            (* XXXX word wrap. *)
            val qlines = String.fields (fn #"\n" => true | _ => false) question
            val qheight = Int.max (iheight, length qlines * F.height)
            val aheight = F.height + (if Option.isSome cancel then F.height else 0)
            (* XXX need to add [enter] and [esc] remarks? *)
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

            (* TODO: allow negative absolute offsets *)
            val x = 
                case x of
                    NONE => (Sprites.width - width) div 2
                  | SOME x => x

            val y = 
                case y of
                    NONE => (Sprites.height - height) div 2
                  | SOME y => y

            (* If not given, then treat as totally transparent. *)
            val ctop = Option.getOpt (bgcolortop, SDL.color(0w0, 0w0, 0w0, 0w0))
            val cbot = Option.getOpt (bgcolorbot, SDL.color(0w0, 0w0, 0w0, 0w0))
            (* XXX this could be an SDL util or general util *)
            fun withsurf f =
                let
                    val surf = SDL.Util.makealpharectgrad { w = width, h = height,
                                                            ctop = ctop, cbot = cbot,
                                                            bias = 0.5 }
                in
                    (f surf handle e => (SDL.freesurface surf; raise e))
                    before
                    SDL.freesurface surf
                end
        in
            withsurf 
            (fn surf =>
             let
                 (* XXX draw icons and text! *)
                 val () =
                     let in
                         Option.app (fn s => SDL.blitall(s, surf, LEFTM, TOPM)) icon;
                         ListUtil.appi (fn (l, i) =>
                                        F.draw(surf,
                                               LEFTM + iwidth + MIDM,
                                               TOPM + i * F.height,
                                               l)) qlines;
                         F.draw (surf, LEFTM, qheight + SKIPM, ok);
                         Option.app (fn c => F.draw(surf, LEFTM, qheight + SKIPM + F.height, c)) cancel;
                         Option.app (fn bc => SDL.Util.outline (surf, 2, bc)) bordercolor
                     end

                 exception Done of bool
                 fun input () =
                     case SDL.pollevent () of
                         SOME (SDL.E_KeyDown { sym = SDL.SDLK_ESCAPE }) => raise Done false
                       | SOME SDL.E_Quit => raise Hero.Exit
                       | SOME e =>
                             (case Input.map e of
                                  SOME (_, Input.ButtonDown 0) => raise Done true
                                | SOME (_, Input.ButtonDown 1) => raise Done false
                                (* XXX could support focus? *)
                                (*
                                | SOME (_, Input.StrumUp) => move_up ()
                                | SOME (_, Input.StrumDown) => move_down ()
                                  *)
                                | SOME _ => ()
                                | NONE =>
                                      (case e of
                                           (* If these are unmapped, then they have default behaviors. *)
                                           (*
                                           E_KeyDown { sym = SDLK_UP } => move_up ()
                                         | E_KeyDown { sym = SDLK_DOWN } => move_down ()
                                         | *) SDL.E_KeyDown { sym = SDL.SDLK_KP_ENTER } => raise Done true
                                         | SDL.E_KeyDown { sym = SDL.SDLK_RETURN } => raise Done true
                                         | _ => ()))
                        | _ => ()

                  fun draw () =
                      let in
                          Drawable.draw parent;
                          SDL.blitall(surf, screen, x, y);
                          SDL.flip screen
                      end

                  fun go next =
                      let 
                          val () = Drawable.heartbeat parent
                          val () = input ()
                          val now = SDL.getticks()
                      in
                          if now > next
                          then (draw();
                                go (now + TICKS))
                          else go next
                      end
              in
                  go (SDL.getticks()) handle Done b => b
              end)
        end

    val DEFAULTBORDER = SDL.color(0w0, 0w0, 0w200, 0w127)
    val DEFAULTCTOP = SDL.color(0w100, 0w100, 0w150, 0w150)
    val DEFAULTCBOT = SDL.color(0w80, 0w80, 0w80, 0w110)
        
    fun yesno p s = prompt { x = NONE, y = NONE, width = NONE, height = NONE,
                             question = s, ok = "Yes", cancel = SOME "No",
                             icon = NONE, (* XXX get one *)
                             bordercolor = SOME DEFAULTBORDER,
                             bgcolortop = SOME DEFAULTCTOP,
                             bgcolorbot = SOME DEFAULTCBOT,
                             parent = p }

    fun okcancel _ = raise Prompt "unimplemented"
    fun no _ = raise Prompt "unimplemented"

    fun bug p s = ignore (prompt { x = NONE, y = NONE, width = NONE, height = NONE,
                                   question = Chars.RED ^ s, ok = "Drat", cancel = NONE,
                                   icon = NONE, (* XXX get one *)
                                   bordercolor = SOME (SDL.color (0w200, 0w0, 0w0, 0w127)),
                                   bgcolortop = SOME DEFAULTCTOP,
                                   bgcolorbot = SOME DEFAULTCBOT,
                                   parent = p })

end