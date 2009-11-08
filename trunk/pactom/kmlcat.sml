(* Concatenates KML files. This is not actually correct; it just
   recognizes the normal format that Earth-exported KML files take,
   and works in that special case. It wouldn't be that hard to
   extend to any valid KML file, but there's not really any point,
   either. *)
structure KMLCat =
struct

    fun go files =
        let
            fun g f =
                let
                    val s = StringUtil.readfile f
                    val v = Vector.fromList (List.filter (fn "" => false | _ => true)
                                             (String.tokens (fn #"\n" => true
                                                              | #"\r" => true
                                                              | _ => false) s))
                in
                    if Vector.length v >= 3 andalso
                       StringUtil.matchhead "<?xml version" (Vector.sub(v, 0)) andalso
                       StringUtil.matchhead "<kml xmlns=" (Vector.sub(v, 1)) andalso
                       (Vector.sub (v, Vector.length v - 1)) = "</kml>"
                    then
                        Util.for 2 (Vector.length v - 2)
                        (fn i =>
                         let 
                             val s = Vector.sub (v, i)
                         in
                             case s of
                                 "<Document>" => print "<Folder>"
                               | "</Document>" => print "</Folder>"
                               | s => print s;
                             print "\n"
                         end)
                    else
                        let 
                            val msg = ("Error: KML file '" ^ f ^ 
                                       "' format unexpected/unsupported")
                        in
                            TextIO.output (TextIO.stdErr, msg ^ "\n");
                            raise Fail msg
                        end
                end
        in
            print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
            print ("<kml xmlns=\"http://www.opengis.net/kml/2.2\" " ^ 
                   "xmlns:gx=\"http://www.google.com/kml/ext/2.2\" " ^
                   "xmlns:kml=\"http://www.opengis.net/kml/2.2\" " ^
                   "xmlns:atom=\"http://www.w3.org/2005/Atom\">\n");
            print ("<Document>\n");
            (* XXX TODO: Add flag for document name *)
            app g files;
            print "</Document>\n";
            print "</kml>\n"
        end

    val () = go (CommandLine.arguments ())
end