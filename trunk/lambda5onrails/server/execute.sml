
structure Execute :> EXECUTE =
struct

  infixr 9 `
  fun a ` b = a b

  structure B = Bytecode
  structure Q = Queue
  structure SM = StringMap

  exception Execute of string

  (* a paused thread, ready to execute. *)
  type thread = { global : int * int,
                  (* rep invt.: all values *)
                  args : B.exp list }  

  datatype instance =
    I of { prog : B.program,
           threads : thread Q.queue ref,
           messages : string Q.queue ref }

  (* no threads, messages... *)
  fun new p = I { prog = p, threads = ref ` Q.empty (), messages = ref ` Q.empty () }

  fun step (i as I { prog, threads } : instance) =
    (* if there are threads, then do some work on the first one *)
    case Q.deq (!threads) of
      (NONE, _) => ()
    | (SOME { global = (g, f), args }, q') => 
        let in
          threads := q';
          (case Vector.sub (#globals prog, g) of
             B.FunDec v =>
               let 
                 val (params, stmt) = Vector.sub (v, f)
                 (* XXX error when arg lengths don't match *)
                 val binds = ListUtil.wed params args
                 val G = SM.empty
                 val G = foldr (fn ((p, a), G) =>
                                SM.insert(G, p, a)) G binds
               in
                 execute i G stmt
               end
           | B.Absent => raise Execute "thread jumped out of this world!")
        end

  and execute (i as I { threads, ... } : instance) 
              (G : B.exp SM.map) (s : B.statement) =
    case s of
      B.End => ()
    | B.Bind (s, e, st) =>
        execute i (SM.insert(G, s, evaluate i G e)) st
    | B.Case { obj, var, arms, def } =>
        (case evaluate i G obj of
           B.Inj (l, e) =>
               (case ListUtil.Alist.find op= arms l of
                    NONE => execute i G def
                  | SOME arm => execute i (SM.insert(G, var, e)) arm)
         | _ => raise Execute "case obj not sum")

    | B.Jump (ef, eg, args) =>
        (case (evaluate i G ef, 
               evaluate i G eg,
               map (evaluate i G) args) of
           (B.Int f, B.Int g, args) => 
             threads := Q.enq ({ global = (IntConst.toInt f, 
                                           IntConst.toInt g),
                                 args = args }, !threads)
         | _ => raise Execute "jump needs two ints, args")
    | B.Error s => raise Execute ("error: " ^ s)

  and evaluate (i : instance) (G : B.exp SM.map) (exp : B.exp) =
    case exp of
      B.Int _ => exp
    | B.String _ => exp
    | B.Inj (l, e) => B.Inj (l, evaluate i G e)
    | B.Record lel => B.Record ` ListUtil.mapsecond (evaluate i G) lel
    | B.Project (l, e) =>
        (case evaluate i G exp of
           B.Record lel => 
             (case ListUtil.Alist.find op= lel l of
                NONE => raise Execute ("label not found: " ^ l)
              | SOME e => e)
         | _ => raise Execute ("project from non-record: label " ^ l))
    | B.Primcall (s, el) =>
        let
          val vl = map (evaluate i G) el
        in
          raise Execute ("primcall " ^ s ^ " not implemented")
        end
    | B.Var s => 
        (case SM.find (G, s) of
           NONE => raise Execute ("unbound variable " ^ s)
         | SOME e => e)

  fun message (I { messages, ... }) =
    case Q.deq ` !messages of
      (NONE, _) => NONE
    | (SOME m, q) => (messages := q; SOME m)

  fun come _ s =
    let in
      print ("Come: " ^ s ^ " (unimplemented)\n")
    end

end
