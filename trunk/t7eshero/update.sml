(* Updates files to match the versions on the server. This is much
   simpler than the escape ugprade system since users don't upload
   songs. We also don't attempt to upgrade the binary itself, for now.
   (That's actually easy on Linux and OSX but I think Windows is
   the most likely platform since you don't need any funny drivers
   for that.
   
   Updating works like this. We fetch a file at a known URL from the
   t7eshero. That file is a manifest for the game's data directory
   contents. The manifest looks like this

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
   if necessary. *)
structure Update =
struct
    
    exception Update of string
    
    (* get_url url callback
       get the specified url from a remote host. Returned as a
       string. 
       callback is called periodically with the number of
       bytes received so far and the total size, if known.
       *)
    fun get_url (url : string) (callback : int * int option -> unit) : string =
        let in
            print ("GET " ^ url ^ "\n");
            print ("XXX: Unimplemented: HTTP fetches!\n");
            "awesome   u    aaaaaaaaaaaaaaaa\n" ^
            "cooool.txt  u  bbbbbbbbbbbbbbbb\n"
        end

    (* Return the canonical URL for the update file f with SHA-1 hash h *)
    fun make_url (f : string) (h : string) : string =
        "http://t7eshero.spacebar.org/" ^ Platform.shortname ^ "/" ^ 
        StringUtil.replace "/" "$" f

    (* Compute the SHA-1 hash of a file on disk as a lowercase ASCII
       string, or return NONE if the file does not exist. *)
    fun sha1file file =
        if FSUtil.exists file
        then SOME (SHA1.bintohex (SHA1.hash_stream
                                  (SimpleStream.fromfilechunks 512 file)))
        else NONE
    
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
    fun prepare_actions (callback : string * int * int option -> unit) 
                        (actions : action list) =
       List.mapPartial
       (fn ActionDelete { file } => SOME (ReplaceDelete { file = file })
         | ActionGet { file, sha1 } => 
        let val data = get_url (make_url file sha1) 
                               (fn (i, t) => callback (file, i, t))
            val tempfile = FSUtil.tempfilename ("update-" ^ sha1 ^ "-")
        in
            if SHA1.bintohex (SHA1.hash data) = sha1
            then (StringUtil.writefile tempfile data;
                  SOME (ReplaceFile { file = file, tempfile = tempfile }))
            else raise Update ("Downloaded file " ^ file ^ " had wrong SHA-1 hash!")
        end) actions

end
