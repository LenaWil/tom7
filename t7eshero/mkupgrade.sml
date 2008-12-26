(* Makes a manifest file. See update.sml for information on what this
   file contains. 
   
   The manifest is created from two files: A file metafest, and a deletion
   metafest. Each is just a list of filenames; the file ones will be SHA-1'd
   and the deletion ones will be listed for deletion. The manifest is written
   on standard output.
   *)
structure MakeUpgrade =
struct

    exception MakeUpgrade of string

    val files = Params.param "" (SOME ("-files", 
                                       "The file metafest file.")) "files"
        
    val deletes = Params.param "" (SOME ("-deletes", 
                                         "The deletes metafest file.")) "deletes"

    fun sha1file file =
        if FSUtil.exists file
        then SOME (SHA1.bintohex (SHA1.hash_stream
                                  (SimpleStream.fromfilechunks 512 file)))
        else NONE

    fun go () =
        let
            val ldels = Script.linesfromfile (!deletes)
            val lfiles = Script.linesfromfile (!files)
        in
            app (fn d => print (d ^ " u *\n")) ldels;
            app (fn f =>
                 case sha1file f of
                     NONE => raise MakeUpgrade ("Can't find " ^ f)
                   | SOME sh => print (f ^ " u " ^ sh ^ "\n")) lfiles
        end

end

val () = Params.main0 "Writes on standard out. Takes no arguments." MakeUpgrade.go
           handle MakeUpgrade.MakeUpgrade s => TextIO.output(TextIO.stdErr, "fail: " ^ s ^ "\n")