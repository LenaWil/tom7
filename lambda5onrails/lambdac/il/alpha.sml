
(* XXX rewrite this into a wizard-like interface so that we
   can't help but alpha vary always. *)

(* alpha-vary (expression vars) in an IL expression *)
structure ILAlpha =
struct

  infixr 9 `
  fun a ` b = a b

  open IL

  exception Alpha of string
  fun err s = raise Alpha s
    
  structure V = Variable
  structure VM = Variable.Map

  (* alpha convert e wrt bound variable set G
     and renaming context R. *)
  fun alpha G R e =
    let
      fun renamer R v =
        case VM.find (R, v) of
          SOME v' => ((* print ("RENAME " ^ V.tostring v ^ " -> " ^ V.tostring v'^ "\n"); *) v')
        | NONE => v

      fun rename v = renamer R v

      (* process a series of variable bindings *)
      fun dobindsgr (G, R, acc, nil) = (G, R, rev acc)
        | dobindsgr (G, R, acc, h :: t) =
        (* note: always alpha vary, even if we haven't
           seen it before *)
        (case (* VM.find (G, h) *) SOME () of
           NONE => dobindsgr (VM.insert(G, h, ()), R, h :: acc, t)
         | SOME () => 
             (* shadowing! *)
             let 

               (* because we always alpha-vary *)
               val G = VM.insert(G, h, ())

               val h' = V.alphavary h
             in
(*               print ("shadow " ^ V.tostring h ^ " -> " ^ 
                      V.tostring h' ^ "\n"); *)

               dobindsgr (VM.insert(G, h', ()),
                          VM.insert(R, h, h'),
                          h' :: acc,
                          t)
             end)

      val dobindsgr = fn (G, R, l) => dobindsgr(G, R, nil, l)

      fun dobinds l = dobindsgr (G, R, l)

      val self = alpha G R

      (* return new (G, R, d) *)
      fun dodec G R d =
        let
        in
          (case d of
             Do e => (G, R, Do (alpha G R e))
           | Val (Poly ({worlds, tys}, (v,t,e))) =>
               (case dobindsgr (G, R, [v]) of
                  (G', R', [v]) =>
                    (* exp is in old scope *)
                    (G', R', Val ` Poly ({worlds=worlds, tys=tys}, (v, t, alpha G R e)))
                | _ => err "impossible/dec")
           | Tagtype v => (G, R, d)
           | Newtag (v, t, tv) =>
               (case dobindsgr (G, R, [v]) of
                  (G, R, [v]) =>
                    (G, R, Newtag(v, t, tv))
                | _ => err "impossible/newtag"))
        end

      fun doval v =
        case v of
          Polyvar {worlds, tys, var} => Polyvar { worlds=worlds, tys=tys, var = rename var }
        | Polyuvar {worlds, tys, var} => Polyuvar { worlds=worlds, tys=tys, var = rename var}
        | VRecord lvl => VRecord ` ListUtil.mapsecond doval lvl
        | Int _ => v
        | String _ => v
        | Fns fl =>
          let
            val (G, R, fs) = dobindsgr (G, R, map #name fl)
            fun onefun (name, { name=_, arg=args, dom, cod,
                                body, inline, recu, 
                                total }) =
              let
                val (G, R, args) = dobindsgr (G, R, args)
                val body = alpha G R body
              in
                { name = name, arg = args, dom = dom,
                  cod = cod, body = body, inline = inline,
                  recu = recu, total = total }
              end
          in
              Fns (map onefun ` ListPair.zip (fs, fl))
          end

    in
      case e of
         Value v => Value ` doval v
       | App (e, el) => App (self e, map self el)
       | Record lel => Record ` ListUtil.mapsecond self lel
       | Proj (l, t, e) => Proj(l, t, self e)
       | Get { addr, typ, body, dlist } => Get { addr = self addr, typ = typ,
                                                body = self body, 
                                                dlist = Option.map (ListUtil.mapsecond doval) dlist }
       | Raise (t, e) => Raise (t, self e)
       | Handle (e, v, e') =>
           (case dobinds [v] of
              (G, R, [v]) => Handle(self e, v, alpha G R e')
            | _ => err "impossible")
       | Seq(e1, e2) => Seq(self e1, self e2)
       | Let(d, e) => 
              let
                val (G, R, d) = dodec G R d
              in
                Let(d, alpha G R e)
              end
       | Roll (t, e) => Roll(t, self e)
       | Unroll e => Unroll(self e)
       | Throw (e1, e2) => Throw (self e1, self e2)
       | Letcc (v, t, e) =>
          (case dobinds [v] of
             (G, R, [v]) => Letcc(v, t, alpha G R e)
           | _ => err "impossible")
       | Tag(e1, e2) => Tag(self e1, self e2)
       | Tagcase (t, object, v, vel, def) => 
             (* XXX not clear if v is supposed to be bound
                inside def. assuming yes, like sumcase *)
          (case dobinds [v] of
             (G, R, [v]) => Tagcase(t, self object, v,
                                     map (fn (v, e) =>
                                          ((* wrt old R *)
                                           rename v, 
                                           alpha G R e)) vel,
                                     alpha G R def)
           | _ => err "impossible")
       | Primapp (po, el, tl) => Primapp(po, map self el, tl)
       | Sumcase (t, object, v, lel, def) =>
          (case dobinds [v] of
             (G, R, [v]) => Sumcase(t, self object, v,
                                    ListUtil.mapsecond (alpha G R) lel,
                                    alpha G R def)
           | _ => err "impossible")
       | Inject (t, l, eo) => Inject(t, l, Option.map self eo)
       | Jointext el => Jointext (map self el)

    end

  fun alphavary e = alpha VM.empty VM.empty e

end
