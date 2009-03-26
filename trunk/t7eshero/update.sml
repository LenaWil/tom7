(* Updates files to match the versions on the server. This is much
   simpler than the escape ugprade system since users don't upload
   songs. We also don't attempt to upgrade the binary itself, for now.
   (That's actually easy on Linux and OSX but I think Windows is
   the most likely platform since you don't need any funny drivers
   for that.)
   
   Updating works like this. We fetch a file at a known URL from the
   t7eshero server for the platform (platform.manifests) which lists
   all of the available components for that platform:

   component1   r   This is some required component.
   component2   o   This is an optional component.
   component3   o   This is another optional component.

   Each filename (first field) is the name of a manifest available in
   that same directory. The next token indicates whether the component
   is required or optional. The player is subscribed to a component n
   when he has the file componentn.subscribed in the game directory,
   or when the component is required. (Some .subscribed files ship
   with the game so that those components are subscribed by default.)
   Each line ends with a description for that component, which can use
   font codes or whatever.

   Each componentn has a manifest at a known url (componentn.manifest),
   which looks like this:

   filename      u     SHA1-or-command\n
   filename      u     SHA1-or-command\n
   filename      u     SHA1-or-command\n
   filename      u     SHA1-or-command\n
   
   u stands for uncompressed, the only file encoding that we currently
   support. The filename uses forward slash to indicate relative
   subdirectories (.. and absolute paths should be rejected).
   Subdirectories are created automatically. SHA1-or-command is either
   the SHA1 hash of the contents of the file, or a * indicating that
   the file should be deleted if it exists. (This allows us to rename
   or remove files as part of the update process.)

   After reading the manifest, the client checks to see if it has
   those files. If its files match the manifest, we are done.
   Otherwise we confirm with the user that we want to do an upgrade,
   then we download each of the files that we need in order to
   complete the installation. These are found in some known directory
   root on the HTTP server, following the same directory structure and
   filenames as in the manifest. If all are successful, we move away
   the old versions, then move in the replacements. We should then
   tell the various modules in the application to reload their stuff,
   if necessary.

   TODO: Platform-specific manifest that allows updating the game and
   its libraries.
*)
structure Update (* XXX SIG *) =
struct
    
    exception Update of string
    structure F = Sprites.FontSmall
    val screen = Sprites.screen

    (* Return the canonical URL for the update file f with SHA-1 hash h *)
    fun make_url (f : string) (h : string) : string =
        "http://t7eshero.spacebar.org/data/" ^ 
        StringUtil.replace "/" "$" f

    fun manifest_url m = "http://t7eshero.spacebar.org/" ^ m ^ ".manifest"

    fun manifests_url () = "http://t7eshero.spacebar.org/" ^
        Platform.shortname ^
        ".manifests"
    
    (* get_url url callback
       get the specified url from a remote host. Returned as a
       string. 
       callback is called periodically with the number of
       bytes received so far and the total size, if known.

       XXX needs a way to fail
       *)
    fun get_url (url : string) (callback : int * int option -> unit) : string =
        (case url of
             "http://t7eshero.spacebar.org/osx.manifests" =>
                 ("main r The main data files.\n" ^
                  "songs o Free song collection.\n" ^
                  "songs-nonfree o Pirate radio\n" ^
                  "gifts o Wardrobe expansion pack\n")
           | url => 
             let in
                 callback (0, NONE);
                 print ("GET " ^ url ^ "\n");
                 callback (0, SOME 1000);
                 print ("XXX: Unimplemented: HTTP fetches!\n");
                 ("awesome   u    aaaaaaaaaaaaaaaa\n" ^
                  "garbage   u    *\n" ^
                  "cooool.txt  u  bbbbbbbbbbbbbbbb\n")
                 before
                 callback (1000, SOME 1000)
             end)

    (* Compute the SHA-1 hash of a file on disk as an uppercase ASCII
       string, or return NONE if the file does not exist. *)
    fun sha1file file =
        if FSUtil.exists file
        then SOME (SHA1.bintohex (SHA1.hash_stream
                                  (SimpleStream.fromfilechunks 512 file)))
        else NONE

    datatype componentstatus = Required | Optional
    fun parse_manifests m =
        let
            val lines = String.tokens (fn #"\n" => true | #"\r" => true
                                        | _ => false) m
        in
            List.mapPartial
            (fn line =>
             case String.tokens (fn #" " => true | _ => false) line of
                 filename :: code :: desc => 
                     SOME(filename,
                          (case code of
                               "r" => Required
                             | "o" => Optional
                             | _ => raise Update "Ill-formed manifests."),
                          StringUtil.delimit " " desc)
               | nil => NONE
               | _ => raise Update "Ill-formed manifests.") lines
        end

    datatype subscription = MustSubscribe | Subscribed | NotSubscribed
    fun check_subscriptions m =
        map (fn (f, Required, desc) => (f, MustSubscribe, desc)
              | (f, Optional, desc) =>
             (f, (if FSUtil.exists (f ^ ".subscribed") 
                  then Subscribed
                  else NotSubscribed), desc)) m

    datatype action =
        ActionGet of { file : string, sha1 : string }
      | ActionDelete of { file : string }

    (* Given the manifest as a string, parse into a series of actions that
       we need to take in order to perform the upgrade. This checks
       the filesystem and doesn't record an action if there's nothing
       to do for that file. Therefore, an empty list of actions means
       that we're already up to date. *)
    fun parse_manifest m =
        let
            val lines = String.tokens (fn #"\n" => true | #"\r" => true
                                       | _ => false) m
        in
            List.mapPartial 
            (fn line =>
             case String.tokens (fn #" " => true | _ => false) line of
                 [filename, _, "*"] =>
                     (* XXX relative to some data directory? *)
                     if FSUtil.exists filename
                     then SOME (ActionDelete { file = filename })
                     else NONE
               | [filename, encoding, sha1] =>
                     if sha1 = Option.getOpt (sha1file filename, "z")
                     then NONE
                     else SOME (ActionGet { file = filename,
                                            sha1 = sha1 })
               (* ignore blank lines *)
               | nil => NONE
               | _ => raise Update "Ill-formed manifest.") lines
        end

    datatype replacement =
        ReplaceDelete of { file : string }
      | ReplaceFile of { file : string, tempfile : string }

    (* Given an action, do what we gotta do get ready to perform it.
       This basically means downloading files we need to temporary
       locations and checking that their hashes are correct. 

       Raises Update if we can't make progress.
       *)
    fun prepare_replacements (callback : string * int * int option -> unit) 
                             (actions : action list) =
       List.mapPartial
       (fn ActionDelete { file } => SOME (ReplaceDelete { file = file })
         | ActionGet { file, sha1 } => 
        (* PERF should download straight to disk, but we can expect these files
           to generally be small (we load them into ram anyway later). *)
        let val data = get_url (make_url file sha1) 
                               (fn (i, t) => callback (file, i, t))
            val tempfile = FSUtil.tempfilename ("update-" ^ sha1 ^ "-")
        in
            if SHA1.bintohex (SHA1.hash data) = sha1
            then (StringUtil.writefile tempfile data;
                  SOME (ReplaceFile { file = file, tempfile = tempfile }))
            else raise Update ("Downloaded file " ^ file ^ " had wrong SHA-1 hash!")
        end) actions

    fun perform_replacements (replacements : replacement list) =
        app (fn ReplaceDelete { file } => 
                 (OS.FileSys.remove file 
                  handle _ => raise Update ("Couldn't remove " ^ file))
              | ReplaceFile { file, tempfile } =>
                 let in
                     (OS.FileSys.remove file) handle _ => ();
                     OS.FileSys.rename { old = tempfile, new = file } 
                       handle _ => raise Update ("couldn't rename " ^ 
                                                 tempfile ^ " to " ^ file)
                 end) replacements

    structure TS = TextScroll(Sprites.FontSmall)

    fun show_actions ts draw nil = (TS.write ts (Chars.GREEN ^ "All files up to date.");
                                    draw())
      | show_actions ts draw acts =
        let in
            app (fn ActionDelete { file } => TS.write ts (Chars.RED ^ "(^0x^<) " ^ file)
                  | ActionGet { file, sha1 } => TS.write ts (Chars.BLUE ^ "(^0v^<) " ^ 
                                                             file)) acts;
            draw ()
        end

    structure LM = ListMenuFn(val screen = screen)

    fun update () =
        let
            (* Gotta turn off sound because we'll freeze otherwise during
               HTTP requests *)
            val () = Sound.all_off ()

            val lf = ref ""
            val ts = TS.make { x = 0, y = 0, 
                               width = Sprites.gamewidth, 
                               height = Sprites.height,
                               bgcolor = SOME (SDL.color (0w0, 0w0, 0w0, 0w255)),
                               bordercolor = NONE }
                
            fun saysame file s = (if file = !lf
                                  then TS.rewrite
                                  else (lf := file; TS.write)) ts s
            fun draw () = 
                let in
                    SDL.fillrect (screen, 0, 0, 
                                  Sprites.gamewidth, 
                                  Sprites.height, 
                                  SDL.color (0w20, 0w30, 0w40, 0w255));
                    TS.draw screen ts
                end
            fun redraw () = (draw (); SDL.flip screen)
            val this = Drawable.drawable { draw = draw, 
                                           resize = Drawable.don't, 
                                           heartbeat = Drawable.don't }

            (* XXX display to SDL surface *)
            fun show_progress (file, i, NONE) = saysame file ("Get " ^ file ^ " @ " ^
                                                              Int.toString i ^ "\n")
              | show_progress (file, i, SOME t) = saysame file ("Get " ^ file ^ " @ " ^
                                                                Int.toString i ^ "/" ^
                                                                Int.toString t ^ "\n")
            fun show_draw x = (show_progress x; redraw ())

            val manifests = get_url (manifests_url ()) (fn (a, b) =>
                                                        show_draw ("manifests", a, b))
            val manifests = parse_manifests manifests

            fun loop_subscribe () =
                let
                    datatype element =
                        ECancel
                      | EDoUpgrade
                      | EItem of string * subscription * string

                    val ms = check_subscriptions manifests
                    val items = EDoUpgrade :: (map EItem ms) @ [ECancel]

                    fun itemheight _ = F.height + 1
                    fun drawitem (item, x, y, sel) =
                        case item of
                            ECancel => F.draw(screen, 
                                              x + (F.width - 
                                                   F.overlap) * 3,
                                              y, Chars.RED ^ "Cancel")
                          | EDoUpgrade => F.draw(screen,
                                                 x + (F.width -
                                                      F.overlap) * 3,
                                                 y, Chars.GREEN ^ "Update now")
                          | EItem (f, d, desc) =>
                                let in
                                    (case d of
                                         MustSubscribe =>
                                             F.draw(screen, x, y,
                                                    Chars.GREY ^ Chars.CHECKMARK)
                                       | Subscribed => 
                                             F.draw(screen, x, y, 
                                                    Chars.BLUE ^ Chars.CHECKMARK)
                                       | _ => ());
                                    F.draw(screen, 
                                           x + (F.width - 
                                                F.overlap) * 3, y, 
                                           Chars.YELLOW ^ f ^ Chars.GREY ^ 
                                           " - " ^ Chars.WHITE ^ desc)
                                end
                in
                    case LM.select { x = 8, y = 40,
                                     width = Sprites.gamewidth - 12,
                                     height = Sprites.height - 80,
                                     items = items,
                                     drawitem = drawitem,
                                     itemheight = itemheight,
                                     bgcolor = SOME LM.DEFAULT_BGCOLOR,
                                     selcolor = SOME (SDL.color (0wx44, 0wx44, 0wx77, 
                                                                 0wxFF)),
                                     bordercolor = SOME LM.DEFAULT_BORDERCOLOR,
                                     parent = Drawable.drawable 
                                     { draw = draw, 
                                       heartbeat = Drawable.don't,
                                  resize = Drawable.don't } } of
                        NONE => NONE
                      | SOME ECancel => NONE
                      | SOME EDoUpgrade => SOME (List.mapPartial 
                                                 (fn (f, MustSubscribe, _) => SOME f
                                               | (f, Subscribed, _) => SOME f
                                               | (f, NotSubscribed, _) => NONE) ms)

                      | SOME (EItem (f, MustSubscribe, _)) => loop_subscribe ()
                      | SOME (EItem (f, NotSubscribed, _)) =>
                            let in
                                StringUtil.writefile (f ^ ".subscribed") "yes";
                                TS.write ts ("Subscribed to " ^ Chars.YELLOW ^ f);
                                loop_subscribe()
                            end
                      | SOME (EItem (f, Subscribed, _)) => 
                            let in
                                OS.FileSys.remove (f ^ ".subscribed");
                                TS.write ts ("Unsubscribed from " ^ Chars.YELLOW ^ f);
                                loop_subscribe()
                            end

                end


        in
            (case loop_subscribe () of
                 NONE => ignore (Prompt.yesno this "Cancelled bye")
               | SOME ms => 
                 let in
                   app (fn mf =>
                        let
                            val manifest = get_url (manifest_url mf) 
                                (fn (a, b) => show_draw (mf ^ ".manifest", a, b))
                            val () = TS.write ts "^1Checking files^<..."
                            val () = redraw ()
                            val actions = parse_manifest manifest
                        in
                            show_actions ts draw actions;
                            TS.write ts "^Downloding files^<...";
                            redraw ();
                            let val replacements = 
                                prepare_replacements show_draw actions
                            in
                                perform_replacements replacements
                            end
                        end) ms;
                   ignore (Prompt.yesno this "Success!")
                 end)
                 handle Update s => Prompt.bug this ("Update failed:\n" ^ s)
                             | e => Prompt.bug this ("Update failed?!\n" ^ exnName e)
        end

end
