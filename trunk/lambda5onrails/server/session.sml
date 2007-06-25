(* A session is a running instance of a program.
   Each session has a unique integer that identifies it.
   
   *)

structure Session :> SESSION =
struct

  infixr 9 `
  fun a ` b = a b

  structure N = Network

  datatype pull =
    Open of N.sock
    (* the last time we saw the socket open *)
  | Closed of Time.time

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
                            (* socket the client uses to send us a message *)
                            push : N.sock option ref,
                            (* socket the client keeps open for us to send
                               messages on *)
                            pull : pull ref,
                            
                            prog : Execute.instance 
                            
                            }

  (* A session is no longer valid *)
  exception Expired
  exception Session of string

  val sessions = ref (nil : session list)

  fun id (S { id, ... }) = id
  fun getsession i = ListUtil.example (fn (S { id, ...}) => id = i) ` !sessions

  fun opensockets (S { push, pull, ... }) =
    (case !push of SOME s => [s] | NONE => nil) @
    (case !pull of Open s => [s] | Closed _ => nil)

  (* Any push/pull sockets that we have open *)
  fun sockets () =
    List.concat ` 
      map opensockets ` !sessions

  (* doesn't remove it from the list, just removes any resources *)
  fun destroy session =
    app (fn s => N.disconnect s handle _ => ()) ` opensockets session

  fun closed sock =
    case
      ListUtil.extract
      (fn session => List.exists (fn s' => N.eq (sock, s')) ` 
       opensockets session) ` !sessions of
      NONE => raise Session "no such socket active in sessions??"
    | SOME (session as S { push, pull, ... }, rest) =>
        let
          fun fatal () =
            let in
              destroy session;
              sessions := rest
            end
        in
          (* Not an error in either case. So, just clear it out. *)
          (case !push of
             SOME s' => if N.eq (s', sock)
                        then push := NONE
                        else ()
           | NONE => ());
          (case !pull of
             Open s' => fatal ()
           | Closed _ => ())
        end

  (* XXX *)
  fun packet _ = ()

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

      val sbc = BytecodeParse.parsefile ("../lambdac/tests/" ^ prog ^ "_server.b5")
      val rt = StringUtil.readfile "../lambdac/js/runtime.js"
      val js = StringUtil.readfile ("../lambdac/tests/" ^ prog ^ "_home.js")

      (* this could be better... ;) *)
      val data =
        "<html><head>\n" ^
        "<title>Server 5 Test Page!</title>\n" ^
        "<script language=\"JavaScript\">\n" ^ rt ^ "\n</script>\n" ^
        "<script language=\"JavaScript\">\n" ^ js ^ "\n</script>\n" ^
        "</head>\n" ^
        "<body>\n" ^
        "Welcome to Server 5!\n" ^
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
      sessions := S { id = id, push = ref NONE, 
                      pull = ref ` Closed ` Time.now (),
                      prog = Execute.new sbc } :: !sessions
    end handle BytecodeParse.BytecodeParse msg => failnew s prog ("parse error: " ^ msg)

  (* make progress on any instance where we can *)
  fun step () =
      List.app (fn (S { prog, ... }) => Execute.step prog) ` !sessions

  fun push _ _ = raise Session "unimplemented"
  fun pull _ _ = raise Session "unimplemented"

end
