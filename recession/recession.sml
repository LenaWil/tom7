
structure Recession =
struct

  exception Recession of string

  val configfile = Params.param "" (* XXX default location? *)
    (SOME("-config",
          "The file containing recession configuration.")) "configfile"

  val aphconfig = Params.param "/var/www/aphid.conf"
    (SOME("-aphconfig",
          "The file containing Aphasia configuration.")) "aphconfig"

  (* XXX timeouts, etc. *)

  fun main () =
    let
      val {lookup, alist, ...} = Script.alistfromfile (!aphconfig)
      (* It's optional, but most databases have this turned on. *)
      val password = lookup "MYSQL_APH_PASSWD"
      val unixsock = lookup "MYSQL_APH_SOCK"

      val () = app (fn (k, v) => print (k ^ "=" ^ v ^ "\n")) alist

      val mysql = MySQL.connectex "localhost" "root" password 0 unixsock

      fun process (raw, config as { icon, summarizer, ... }) =
          let 
              val xml = XML.parsestring raw
              val items = RSS.items xml
          in
              print raw;
              print "\n\n as xml \n\n";
              print (XML.tostring xml);
              print "\n\n";
              app (fn { title, date, ... } => 
                   print (" -> " ^ title ^ " on " ^ Date.toString date ^ "\n")) items;
              print "\n\n";
              raise Recession "unimplemented"
          end

      (* Body, wrapped by error handlers. *)
      fun prot () =
        let
          fun onefeed (config as { url, ... }) =
              let in
                  (* XXX this can take arbitrarily long. should set an alarm. *)
                  print ("Fetch URL " ^ url ^ "...\n");
                  (case HTTP.get_url url ignore of
                       HTTP.Rejected s => raise HTTP.HTTP ("Rejected: " ^ s)
                     | HTTP.NetworkFailure s => raise HTTP.HTTP ("Network error: " ^ s)
                     | HTTP.Success s => process (s, config))
              end
          (* But keep going with the next one. *)
          handle HTTP.HTTP s => print ("Failed: HTTP error: " ^ s ^ "\n")

        in
            (* "http://connect.garmin.com/feed/rss/activities?feedname=Garmin%20Connect%20-%20brighterorange&owner=brighterorange", *)
          app onefeed [{url = "http://radar.spacebar.org/f/a/weblog/rss/1",
                        icon = "pactom.png",
                        summarizer = (fn _ => raise Recession "unimplemented")}]
        end

    in
      Util.always prot (fn () => MySQL.close mysql)
    end

  val () = Params.main0 "Takes no arguments." main
     handle Recession s => print ("Error: " ^ s ^ "\n")
          | MySQL.MySQL s => print ("Database error: " ^ s ^ "\n")
end

