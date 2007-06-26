(* A session is a running instance of a program along with
   the connections with the client and a unique integer that
   identifies it.

   XXX in failure situations, we shouldn't shut down the
   entire server...
   
   *)

structure Session :> SESSION =
struct

  infixr 9 `
  fun a ` b = a b

  structure N = Network

  datatype toclient =
    Open of N.sock
    (* the last time we saw the socket open *)
  | Closed of Time.time

  datatype toserver =
    Waiting of N.sock
  | Data of string

  local
    val ctr = ref 0
  in
    fun newid () =
      let in
        ctr := !ctr + 1;
        !ctr
      end
  end

  datatype session = S of { id : int,
                            (* sockets the client is using to send us messages *)
                            toserver : toserver list ref,
                            (* socket the client keeps open for us to send
                               messages on *)
                            toclient : toclient ref,
                            
                            inst : Execute.instance 
                            
                            }

  (* A session is no longer valid *)
  exception Expired
  exception Session of string

  val sessions = ref (nil : session list)

  fun id (S { id, ... }) = id
  fun getsession i = ListUtil.example (fn (S { id, ...}) => id = i) ` !sessions

  fun opensockets (S { toserver, toclient, ... }) =
    (List.concat ` map (fn Waiting s => [s] | _ => nil) ` !toserver) @
    (case !toclient of Open s => [s] | Closed _ => nil)

  fun getbysock sock =
      ListUtil.extract
      (fn session => List.exists (fn s' => N.eq (sock, s')) ` 
       opensockets session) ` !sessions

  (* Any toserver/toclient sockets that we have open *)
  fun sockets () =
    List.concat ` 
      map opensockets ` !sessions

  (* doesn't remove it from the list, just removes any resources *)
  fun destroy session =
    app (fn s => N.disconnect s handle _ => ()) ` opensockets session

  fun closed sock =
    case getbysock sock of
      NONE => raise Session "(closed) no such socket active in sessions??"
    | SOME (session as S { toserver, toclient, ... }, rest) =>
        let
          fun fatal () =
            let in
              destroy session;
              sessions := rest
            end
        in
          (* Client is only allowed to close toserver connections. Filter 'em. *)
          toserver := List.filter (fn Data _ => true | Waiting s => not ` N.eq (s, sock)) ` !toserver;

          (* If this closes, game over *)
          (case !toclient of
             Open s' => if N.eq (s', sock) then fatal () else ()
           | Closed _ => ())
        end

  fun packet (Http.Headers _, _) = raise Session "got headers again??"
    | packet (Http.Content c, sock) =
    case getbysock sock of
      NONE => raise Session "(packet) no such socket active in sessions??"
    | SOME (session as S { toserver, toclient, ... }, rest) =>
        let in
          (* maybe we'll see empty content, depending on the browser.
             anyway we don't care about it. *)
          (case !toclient of
             Open s' => if N.eq (s', sock) 
                        then print "content for toclient? ignored!\n"
                        else ()
           | Closed _ => ());
          
          (* should be for a toserver connection. *)
          toserver := map (fn Data d => Data d
                            | Waiting s' => if N.eq(s', sock) 
                                            then (print ("DATA " ^ c ^ "\n");
                                                  N.disconnect s'; 
                                                  Data c)
                                            else Waiting s') ` !toserver

          (* XXX step here to deliver messages? *)
        end
    

  fun failnew s prog str =
    let in
      N.sendraw s
      ("HTTP/1.1 404 URL Not Found\r\n" ^
       "Date: " ^ Version.date () ^ "\r\n" ^
       "Server: " ^ Version.version ^ "\r\n" ^
       "Connection: close\r\n" ^
       "Content-Type: text/html; charset=utf-8\r\n" ^
       "\r\n" ^
       "The program '<b>" ^ prog ^ "</b>' was not found: " ^ str ^ "\n");
      N.disconnect s
    end

  fun new s prog =
    let
      val id = newid ()

      (* XXX paths should be from a config file *)
      val sbc = BytecodeParse.parsefile ("../lambdac/tests/" ^ prog ^ "_server.b5")
      val rt = StringUtil.readfile "../lambdac/js/runtime.js"
      val js = StringUtil.readfile ("../lambdac/tests/" ^ prog ^ "_home.js")

      val sessiondata =
        (* XXX should be from a config file *)
        "var session_serverurl = 'http://gs82.sp.cs.cmu.edu:5555/toserver/';\n" ^
        "var session_clienturl = 'http://gs82.sp.cs.cmu.edu:5555/toclient/';\n" ^
        "var session_id = " ^ Int.toString id ^ ";\n"

      (* this could be better... ;) 
         probably it should act like a javascript <link> so that we
         can write the html elsewhere? *)
      val data =
        "<html><head>\n" ^
        "<title>Server 5 Test Page!</title>\n" ^
        "<script language=\"JavaScript\">\n" ^ sessiondata ^ "</script>\n" ^
        "<script language=\"JavaScript\">\n" ^ rt ^ "\n</script>\n" ^
        "<script language=\"JavaScript\">\n" ^ js ^ "\n</script>\n" ^
        "</head>\n" ^
        "<body>\n" ^
        "Welcome to Server 5!\n" ^
        "<p><div id=\"messages\"></div>\n" ^ 
        "</body></html>\n";

      val res = ("Content-Type: text/html; charset=utf-8\r\n" ^
                 "\r\n" ^
                 data)

    in
      N.sendraw s
      ("HTTP/1.1 200 OK\r\n" ^
       "Date: " ^ Version.date () ^ "\r\n" ^
       "Server: " ^ Version.version ^ "\r\n" ^
       "Connection: close\r\n" ^
       "X-Program: " ^ prog ^ "\r\n" ^
       "X-Sessionid: " ^ Int.toString id ^ "\r\n" ^
       "Content-Type: text/html; charset=utf-8\r\n" ^
       "\r\n" ^
       data);
      N.disconnect s;
      sessions := S { id = id, toserver = ref nil, 
                      toclient = ref ` Closed ` Time.now (),
                      inst = Execute.new sbc } :: !sessions
    end handle BytecodeParse.BytecodeParse msg => failnew s prog ("parse error: " ^ msg)

  (* make progress on any instance where we can *)
  fun step () =
    let
      fun onesession (S { inst, toserver, toclient, ... }) =
        let
          (* process incoming requests in order. *)
          fun incoming nil = nil
            | incoming (Data d :: rest) = (Execute.come inst d;
                                           incoming rest)
            | incoming l = l

          fun outgoing (ref (Closed _)) = () (* XXX should expire old sessions here *)
            | outgoing (r as ref (Open sock)) =
            case Execute.message inst of
              NONE => ()
            | SOME m =>
                let in
                  N.sendraw sock m;
                  N.disconnect sock;
                  (* one message per connection *)
                  r := (Closed ` Time.now ())
                end
        in
          (* incoming requests. *)
          toserver := incoming ` !toserver;

          (* an outgoing message (at most one) *)
          outgoing toclient;

          (* run some waiting thread *)
          Execute.step inst
        end
    in
      (* print "step..\n"; *)
      List.app onesession ` !sessions
    end

  fun toserver sock id =
    case getsession id of
       SOME (S { toserver, ... }) => toserver := !toserver @ [Waiting sock]
     | NONE => raise Expired

  fun toclient sock id = 
    case getsession id of
      (* what to do if it's already open?? should be fatal? *)
      SOME (S { toclient, ...}) =>
        (case !toclient of
           Open _ => raise Session "client made a second toclient socket"
         | Closed _ => toclient := Open sock)
    | NONE => raise Expired

end
