structure Recession =
struct

  exception Recession of string
  datatype entry = datatype MySQL.entry

(*
  val configfile = Params.param "" (* XXX default location? *)
    (SOME("-config",
          "The file containing recession configuration.")) "configfile"
*)

  val aphconfig = Params.param "/var/www/aphid.conf"
    (SOME("-aphconfig",
          "The file containing Aphasia configuration.")) "aphconfig"

  (* XXX timeouts, etc. *)

  fun getconfigs mysql =
    let
      (* TODO: Allow user to configure which feeds are updated.
         Allow database to mark some as disabled. *)
      val res = case MySQL.query mysql
          ("select id, url, lastpost, algorithm, logof from " ^
           "rss.subscription where enabled='t'") of
          NONE => raise Recession ("Failed to get subscriptions: " ^ 
                                   getOpt (MySQL.error mysql, "??"))
        | SOME r => r

      fun row [SOME (Int id), SOME (String url), SOME (Int lastpost),
               SOME (String algorithm), SOME (Int logof)] =
          { id = id, url = url, lastpost = lastpost, 
            algorithm = algorithm, logof = logof }
        | row r = raise Recession ("Unexpected row type: " ^ 
                                   MySQL.rowtos r)

      val configs = map row (MySQL.readall mysql res)
    in
      MySQL.free res;
      configs
    end

  fun monthnum Date.Jan = 1
    | monthnum Date.Feb = 2
    | monthnum Date.Mar = 3
    | monthnum Date.Apr = 4
    | monthnum Date.May = 5
    | monthnum Date.Jun = 6
    | monthnum Date.Jul = 7
    | monthnum Date.Aug = 8
    | monthnum Date.Sep = 9
    | monthnum Date.Oct = 10
    | monthnum Date.Nov = 11
    | monthnum Date.Dec = 12

  fun query_check mysql query =
      case MySQL.query mysql query of 
          NONE => raise Recession ("Query failed: " ^ 
                                   getOpt (MySQL.error mysql, "??"))
        | SOME r => MySQL.free r

  fun query_noresult mysql query =
      case MySQL.query mysql query of 
          NONE => ()
        | SOME r => (MySQL.free r;
                     raise Recession "Wasn't expecting response from query!")

  fun main () =
    let
      val {lookup, alist, ...} = Script.alistfromfile (!aphconfig)
      (* It's optional, but most databases have this turned on. *)
      val password = lookup "MYSQL_APH_PASSWD"
      val unixsock = lookup "MYSQL_APH_SOCK"

      (* val () = app (fn (k, v) => print (k ^ "=" ^ v ^ "\n")) alist *)

      val mysql = MySQL.connectex "localhost" "root" password 0 unixsock

      val configs = getconfigs mysql
      val () = app (fn { id, url, lastpost, algorithm, logof } =>
                    print (Int.toString id ^ ". " ^ url ^ " (" ^ algorithm ^ ")\n")) 
                   configs

      fun process (raw, config as { id, url, lastpost, algorithm, logof }) =
        case Algorithms.getalgorithm algorithm of
            NONE => raise Recession ("Unknown algorithm " ^ algorithm)
          | SOME algorithm =>
          let
              (* val () = print ("Raw XML:\n" ^ raw ^ "\n") *)

              val xml = XML.parsestring raw
              (* val () = print ("Parsed:\n" ^ XML.tostring xml ^ "\n") *)
              val items = RSS.items xml

              fun datefromsec sec = Date.fromTimeLocal (Time.fromSeconds (LargeInt.fromInt sec))
              val lastpost = datefromsec lastpost
              val () = print ("Last post: " ^ Date.toString lastpost ^ "\n")

              fun date_max (a, b) =
                  case Date.compare (a, b) of
                      LESS => b
                    | _ => a

              (* only look at posts strictly after the lastpost. *)
              fun keep_new { date, ... } =
                  (case Date.compare (lastpost, date) of
                       LESS => true
                     | _ => false)

              val () = app (fn { date, title, ... } =>
                            let val s = IntInf.toString (Time.toSeconds (Date.toTime date))
                            in
                                print (s ^ " " ^ Date.toString date ^ "  " ^ title ^ "\n")
                            end) items

              val items = List.filter keep_new items
              val items = ListUtil.maptopartial algorithm items
          in
              case items of
                  nil => print "No new posts.\n"
                | all as (({ date, ... }, _) :: _) =>
                   let
                       val new_newest = foldl date_max date (map (#date o #1) all)
                       val new_newest_s = IntInf.toString (Time.toSeconds (Date.toTime new_newest))
                   in
                       (* First, update the current high water mark. *)
                       print ("Update lastpost to " ^ new_newest_s ^ "\n");
                       query_noresult mysql
                       ("update rss.subscription set lastpost = " ^ new_newest_s ^
                        " where id = " ^ Int.toString id);
                       
                       (* Now, insert each of the items. *)
                       app (fn ({ date, guid, ... }, { url, title }) =>
                            let in
                                print (" -> " ^ title ^ " on " ^ Date.toString date ^ "\n");
                                query_noresult mysql
                                ("insert into rss.item " ^
                                 "(subscriptionof, logof, postdate, postmonth, postyear, " ^
                                 "url, title, guid) values " ^
                                 MySQL.escapevalues mysql [Int id, Int logof,
                                                           Int (IntInf.toInt 
                                                                (Time.toSeconds 
                                                                 (Date.toTime
                                                                  date))),
                                                           Int (monthnum (Date.month date)),
                                                           Int (Date.year date),
                                                           String url,
                                                           String title,
                                                           String guid])
                            end) all;
                       print ("Inserted " ^ Int.toString (length all) ^ " new posts.\n")
                   end
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
          app onefeed configs
        end

    in
      Util.always prot (fn () => MySQL.close mysql)
    end

  val () = Params.main0 "Takes no arguments." main
     handle Recession s => print ("Error: " ^ s ^ "\n")
          | MySQL.MySQL s => print ("Database error: " ^ s ^ "\n")
end

