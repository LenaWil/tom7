
structure Loop =
struct

  val passwd_file = 
      Params.param "/etc/passwd" 
                   (SOME ("-passwd", "The passwd file")) 
                   "passwd_file"

  val drop_privs =
        Params.flag true
           (SOME
            ("-drop-privs",
             "Setuid to an unprivileged account"))
           "drop_privs"
           
  val account =
        Params.param "nobody"
           (SOME
            ("-account",
             "Account to run as (if drop-privs set)"))
           "account"

  val port = Params.param "25"
        (SOME("-port",
              "The port to listen on."))
        "port"

  infixr 9 `
  fun a ` b = a b

  exception Loop of string

  structure R = RawNetwork

  val listener = ref NONE : R.sdesc option ref

  fun !!(ref (SOME x)) = x
    | !! _ = raise Loop "impossible !! NONE"

  fun loop children =
      let
          fun wait ps = 
              (case Posix.Process.waitpid_nh 
                   (Posix.Process.W_ANY_CHILD, nil) of
                   NONE => ps
                 | SOME (pid, _) => 
                       List.filter (fn p => p <> pid)
                       (wait ps)) handle _ => ps

          (* wait on zombies to get rid of them *)
          val children = wait children

          (* block waiting for connection... *)
          val () = print "waiting for connection..."
          val (peer, _) = R.accept (!! listener)
          val () = print "connected!\n"
      in 
          (* fork child.
             parent closes peer, child closes listener. *)
          case Posix.Process.fork () of
              NONE =>
                  let in
                      (* right?? *)
                      R.close (!! listener);
                      listener := NONE;
                      Child.child peer
                  end
            | SOME pid =>
                  let in
                      R.close peer;
                      loop (pid :: children)
                  end
      end

  fun init () =
      let in
          listener := SOME ` R.listen ` Params.asint 5555 port;
          (* then drop privileges immediately *)
          if (!drop_privs) then
            let in
              Passwd.readdb (!passwd_file);
              case Passwd.lookup (!account) of
                  NONE => 
                      let in
                          print ("Can't switch to user '" ^ !account ^ "'!\n");
                          raise Loop ("can't drop privileges")
                      end
                | SOME {uid, ...} => 
                      Posix.ProcEnv.setuid (Posix.ProcEnv.wordToUid 
                                            (SysWord.fromInt uid))
            end
          else ()
      end

end
