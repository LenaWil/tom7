(* Deletes stuff like attribution and timestamps that account for a large amount of
   the space used by an OSM file, but are seldom useful. *)
structure FilterOSM =
struct

  datatype chunk = datatype XMLChunk.chunk

  fun runone f =
    let
      fun filter_attribute ("changeset", _, _) = false
        | filter_attribute ("version", _, _) = false
        | filter_attribute ("user", _, _) = false
        | filter_attribute ("timestamp", _, _) = false
        | filter_attribute _ = true

      (* Only standalone ones, otherwise we have to keep track of matching. *)
      fun remove_tag (Tag { name = "tag", attrs, endslash = true, startslash = false, ... }) =
        List.exists (fn ("k", _, "source") => true
                      | ("k", _, "attribution") => true
                      | ("k", _, "tiger:upload_uuid") => true
                      | ("k", _, "tiger:tlid") => true
                      | ("k", _, "tiger:source") => true
                      | ("k", _, "gnis:import_uuid") => true
                      | _ => false) attrs
        | remove_tag _ = false

      fun process_chunk (Text s) = Text s
        (*
        if StringUtil.all StringUtil.whitespec
        then Text "\n"
        else Text s
        *)
        | process_chunk (tag as Tag { startslash, name, attrs, endslash }) =
        if remove_tag tag
        then Text ""
        else
        Tag { startslash = startslash, name = name,
              attrs = List.filter filter_attribute attrs,
              endslash = endslash }
      val (file, ext) = FSUtil.splitext f

      val lastpct = ref 0
      fun progress r =
        let val pct = Real.floor (100.0 * r)
        in
          if pct > !lastpct
          then (TextIO.output (TextIO.stdErr, Int.toString pct ^ "%\n");
                lastpct := pct)
          else ()
        end
    in
      XMLChunk.process_file_progress progress process_chunk f (file ^ "-filtered." ^ ext)
    end

  fun run fl = app runone fl

end

val () = Params.main "Command-line argument: OSM files." FilterOSM.run