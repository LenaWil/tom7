
structure Loop =
struct

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
    listener := SOME ` R.listen ` Params.asint 5555 port

end
