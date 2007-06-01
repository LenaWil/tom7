
structure ElabUtil :> ELABUTIL =
struct

    exception Elaborate of string
    structure V = Variable

    infixr 9 `
    fun a ` b = a b

    val ltos = Pos.toString

    fun error loc msg =
        let in
            print ("Error at " ^ Pos.toString loc ^ ": ");
            print msg;
            print "\n";
            raise Elaborate "error"
        end

    fun new_evar ()  = IL.Evar  ` Unify.new_ebind ()
    fun new_wevar () = IL.WEvar ` Unify.new_ebind ()

    (* XXX5 compile flag *)
    fun warn loc s =
      let in
        print ("Warning at " ^ Pos.toString loc ^ ": " ^ s ^ "\n")
      end

    (* unify context location message actual expected *)
    fun unify ctx loc msg t1 t2 =
            Unify.unify ctx t1 t2
            handle Unify.Unify s => 
                let 
                    val $ = Layout.str
                    val % = Layout.mayAlign
                in
                    Layout.print
                    (Layout.align
                     [%[$("Type mismatch (" ^ s ^ ") at "), $(Pos.toString loc),
                        $": ", $msg],
                      %[$"expected:", Layout.indent 4 (ILPrint.ttolex ctx t2)],
                      %[$"actual:  ", Layout.indent 4 (ILPrint.ttolex ctx t1)]],
                     print);
                    print "\n";
                    raise Elaborate "type error"
                end

    (* unify context location message actual expected *)
    fun unifyw ctx loc msg w1 w2 =
            Unify.unifyw ctx w1 w2
            handle Unify.Unify s => 
                let 
                    val $ = Layout.str
                    val % = Layout.mayAlign
                in
                    Layout.print
                    (Layout.align
                     [%[$("World mismatch (" ^ s ^ ") at "), $(Pos.toString loc),
                        $": ", $msg],
                      %[$"expected:", Layout.indent 4 (ILPrint.wtol w2)],
                      %[$"actual:  ", Layout.indent 4 (ILPrint.wtol w1)]],
                     print);
                    print "\n";
                    raise Elaborate "type error"
                end

    val itos = Int.toString

    val newstr = LambdacUtil.newstr

    (* fixed. uses outer context to determine what evars
       should be generalized. *)
    fun polygen ctx ty =
        let val acc = ref nil
            fun go t =
                (case t of
                     IL.TRef tt => IL.TRef ` go tt
                   | IL.TVec tt => IL.TVec ` go tt
                   | IL.Sum ltl => IL.Sum ` ListUtil.mapsecond (IL.arminfo_map go) ltl
                   | IL.Arrow (b, tl, tt) => IL.Arrow(b, map go tl, go tt)
                   | IL.TRec ltl => IL.TRec ` ListUtil.mapsecond go ltl
                   | IL.TVar v => t
                   | IL.TCont tt => IL.TCont ` go tt
                   | IL.TTag (tt, v) => IL.TTag (go tt, v)
                   | IL.Mu (n, vtl) => IL.Mu (n, ListUtil.mapsecond go vtl)
                   | IL.TAddr w => t
                   (* XXX5 polygen worlds too? *)
                   | IL.At (t, w) => IL.At(go t, w)
                   | IL.Evar er =>
                         (case !er of
                              IL.Free n =>
                                  if Context.has_evar ctx n
                                  then t
                                  else
                                      let 
                                          val tv = V.namedvar "poly"
                                      in
                                          acc := tv :: !acc;
                                          er := IL.Bound (IL.TVar tv);
                                          IL.TVar tv
                                      end
                            | IL.Bound ty => go ty))
        in
            (go ty, rev (!acc))
        end

    (* (old, fixed now??) problems with polygen:

       Need to substitute through term, too, 
       since types appear in terms (like val x : t = ...)

       can't generalize all bound evars, see:

       fun f x =
          let val y = x
          in y
          end

          does NOT have type A a,b . a -> b

       ... I think the thing to do is to only generalize evars
       that don't appear in the surrounding context (ie, as
       the type of some variable). In that case we can use
       the strategy above, except we don't even need
       Substituted (we never did), as we can just make them
       be Bound (TVar new_v).

       *)

    fun evarizes (IL.Poly({worlds, tys}, mt)) =
        let
          (* make the type and world substitutions *)
            fun mkts nil m ts = (m, rev ts)
              | mkts (tv::rest) m ts =
              let val e = IL.Evar (Unify.new_ebind ())
              in
                mkts rest (V.Map.insert (m, tv, e)) (e :: ts)
              end

            fun mkws nil m ws = (m, rev ws)
              | mkws (tv::rest) m ws =
              let val e = IL.WEvar (Unify.new_ebind ())
              in
                mkws rest (V.Map.insert (m, tv, e)) (e :: ws)
              end

            val (wsubst, ws) = mkws worlds V.Map.empty nil
            val (tsubst, ts) = mkts tys V.Map.empty nil

            fun wsu t = Subst.wsubst wsubst t
            fun tsu t = Subst.tsubst tsubst t

        in
          (map (wsu o tsu) mt, ws, ts)
        end

    fun evarize (IL.Poly({worlds, tys}, mt)) = 
      case evarizes ` IL.Poly({worlds=worlds, tys=tys}, [mt]) of
        ([m], ws, ts) => (m, ws, ts)
      | _ => raise Elaborate "impossible"


  (* used to deconstruct bool, which the compiler needs internally.
     implemented for general purpose (except evars?) *)
  fun unroll loc (IL.Mu(m, tl)) =
      (let val (_, t) = List.nth (tl, m)
           val (s, _) =
               List.foldl (fn((v,t),(mm,idx)) =>
                           (V.Map.insert
                            (mm, v, (IL.Mu (idx, tl))), idx + 1))
                          (V.Map.empty, 0)
                          tl
       in
           Subst.tsubst s t
       end handle _ => error loc "internal error: malformed mu")
    | unroll loc _ =
      error loc "internal error: unroll non-mu"

    (* I implemented it again,
       and then thought, this would be useful utility code!

  fun unroll (wholemu as I.Mu(n, mubod)) =>
    (* get the nth thing *)
    let 
      (* alist var->index *)
      val vn = ListUtil.mapi Util.I mubod
      val (_, thisone) = List.nth (mubod, n)
        
      val sub =
        Subst.fromlist
        (map (fn (v, n) => 
              (v, I.Mu(n, mubod))) vn)
    in
      Subst.tsubst sub thisone
    end handle Subscript =>
      raise Pattern "bad mu!"
        *)

  fun mono t = IL.Poly({worlds= nil, tys = nil}, t)


  local
    val mobiles = ref nil : (Pos.pos * string * IL.typ) list ref

    (* mobility test.
       if force is true, then unset evars are set to unit
       to force mobility.
       if force is false and evars are seen, then defer this type for later *)
    fun emobile pos s force t =
      let

        (* argument: set of mobile type variables *)
        fun em G t =
          case t of
            IL.Evar (ref (IL.Bound t)) => em G t
          | IL.Evar (ev as ref (IL.Free _)) => 
              if force
              then 
                let in
                  warn pos (s ^ ": unset evar in mobile check; setting to unit");
                  ev := IL.Bound (IL.TRec nil);
                  true
                end
              else (mobiles := (pos, s, t) :: !mobiles; true)

          | IL.TVar v => V.Set.member (G, v)
          | IL.TRec ltl => ListUtil.allsecond (em G) ltl
          | IL.Arrow _ => false
          | IL.Sum ltl => List.all (fn (_, IL.NonCarrier) => true 
                                     | (_, IL.Carrier { carried = t, ...}) => em G t) ltl

          (* no matter which projection this is, all types have to be mobile *)
          | IL.Mu (i, vtl) => 
              let val G = V.Set.addList(G, map #1 vtl)
              in ListUtil.allsecond (em G) vtl
              end

          (* assuming immutable. 
             there should be a separate array type *)
          | IL.TVec t => em G t
          | IL.TCont t => raise Elaborate "unimplemented emobile/cont"
          | IL.TRef _ => false
          | IL.TTag _ => (* XXX5 ? *) false
          | IL.At _ => true
          | IL.TAddr _ => true

      in
        em Initial.mobiletvars t
      end


    fun notmobile ctx loc msg t =
      let 
        val $ = Layout.str
        val % = Layout.mayAlign
      in
        Layout.print
        (Layout.align
         [%[$("Error: Type is not mobile at "), $(Pos.toString loc),
            $": ", $msg],
          %[$"type:  ", Layout.indent 4 (ILPrint.ttolex ctx t)]],
         print);
        print "\n";
        raise Elaborate "type error"
      end

  in
    fun clear_mobile () = mobiles := nil

    fun check_mobile () =
      let in
        List.app (fn (pos, msg, t) => 
                  if emobile pos msg true t
                  then () 
                  else notmobile Context.empty pos msg t) (!mobiles);
        clear_mobile ()
      end
 
    fun require_mobile ctx loc msg t =
        if emobile loc msg false t
        then ()
        else notmobile ctx loc msg t

  end

end