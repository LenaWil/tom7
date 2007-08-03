(* Prior to closure conversion we perform a translation to establish
   an invariant: that every bound type variable within a value or
   expression has associated with it in context a value that
   corresponds to that type's dictionary. (At this level, a dictionary
   is an abstract thing; ultimately it will be used to contain the
   marshaling functions for the type so that polymorphic code can
   transfer data over the network.) The output of this translation
   achieves the binding invariant by a set of representation
   guarantees, which are listed below.

   Type variables are bound in only three places in the CPS language.
   The AllLam construct abstracts over worlds, types, and values. The
   ExternType imports an abstract type and binds it to a variable. The
   third is the TUnpack construct, which unpacks a existential type.
   However, we do not expect to see TPack and TUnpack until after
   closure conversion, so we do not translate them here. In all cases,
   the bound type has kind 0, so we do not need to worry about
   dictionaries taking other dictionaries.

   Type variables are bound by the type constructor Mu as well, but
   not by the corresponding term constructors. We do not need to worry
   about these type variables at all because they cannot appear in
   terms.

   Because types are not associated with worlds (although we may have
   such "located types" in future work; see notes/typeatworld.txt),
   the dictionaries should not be associated with worlds either--we
   might transfer control to another world in the scope of some
   abstract type and then need to marshal some value of that abstract
   type. The dictionary passing invariant ensures that the dictionary
   is always bound as a universal variable.

   Representation Invariant 1: 
    For AllLam { worlds, types = t1..tn, vals = x1..xm, body },
    m >= n and x1..xn are the universal dictionaries for the types t1..tn, 
    respectively. Each should be shamrocked, and they are immediately
    unshamrocked in the body.

   Representation Invariant 2: 
    For AllApp { f, worlds, types = t1..tn, vals = v1..vm },
    m >= n and v1..vn are the dictionaries for types t1..tn, respectively,
    each shamrocked.

   Representation Invariant 3: 
    For ExternType (v, lab, vlo, _), vlo is SOME (v', lab')
    where lab' is a symbol standing for the dictionary for the 
    abstract type at the label lab. The dictionary must be exported as 
    a uvar. 

   (the following two are irrelevant here since there will be no
    tpacks/tunpacks, but they will be introduced in CPS conversion.
    These are also permanent: we need to keep the dictionaries inside
    existential packages for the purposes of marshaling at runtime;
    see undict.sml)

   Representation Invariant 4: 
    For TUnpack, the first element of the list will always be the
    shamrocked dictionary for the type existentially bound. It is
    immediately unshamrocked in the body to put it in the context.
     (Notwithstanding the above, this unshamrocking can be eliminated
      as an optimization, since it is irrelevant for marshaling.)

   Representation Invariant 5: 
    TPack always packs a list (sham dict :: ...) as in #4.


   We also do the same for worlds, associating each static world
   variable in scope with a representation. This is considerably
   simpler because worlds are unstructured (just constants or
   variables). 

     XXXWD: world representation invariants here
     
     for allarrow, we put the wdicts first in the val list.
     for {}A, we translate it to {w} allarrow{w wdict}.A
*)

structure CPSDict :> CPSDICT =
struct

    exception CPSDict of string

    open CPS

    infixr 9 `
    fun a ` b = a b

    val DICT_SUFFIX = "_dict"
    val DICT_LAB = "dict"
    val VALUE_LAB = "value"

    structure T = CPSTypeCheck
    val bindvar = T.bindvar
    val binduvar = T.binduvar
    val bindu0var = T.bindu0var
    val bindtype = T.bindtype
    val bindworld = T.bindworld
    val worldfrom = T.worldfrom
    val bindworlds = foldl (fn (v, c) => bindworld c v)
    (* assuming not mobile *)
    val bindtypes  = foldl (fn (v, c) => bindtype c v false)

    (* unlike DICT_SUFFIX, this is arbitrary *)
    fun mkdictvar v = Variable.namedvar (Variable.tostring v ^ "_d")

    structure VS = Variable.Set

    structure DA : PASSARG where type stuff = VS.set =
    struct
      type stuff = VS.set
      structure ID = IDPass(type stuff = stuff)
      open ID

      (* types. we only need to convert allarrow (takes new world args) and shamrock (nested allarrow). *)
      fun case_AllArrow z ({selfe, selfv, selft}, G)  {worlds, tys, vals, body} =
        let
          val G = bindworlds G worlds
          val G = bindtypes G tys
        in
           AllArrow' { worlds = worlds, 
                       tys = tys,
                       vals = 
                         map (Shamrock0' o TWdict' o W) worlds @
                         map (Shamrock0' o Dictionary' o TVar') tys @ 
                         map (selft z G) vals,
                       body = selft z G body }
        end

      fun case_Shamrock z ({selfe, selfv, selft}, G) (w : Variable.var, t) =
           Shamrock' (w, AllArrow' { worlds = nil, tys = nil, vals = [TWdict' (W w)], body = selft z (bindworld G w) t })

       (* actually, letd might generate these when it is implemented in the frontend *)
      fun case_WExists _ = raise CPSDict "BUG: shouldn't have existential worlds yet (?)"
       (* these are bugs *)
      fun case_TExists _ = raise CPSDict "BUG: shouldn't have existential types yet"
      fun case_Primcon _ _ (DICTIONARY, _) = raise CPSDict "BUG: shouldn't see dicts before introducing dicts!"
        | case_Primcon z s t = ID.case_Primcon z s t


      (* Expressions. We rewrite extern type to expect a dictionary. We also record when
         we bind a uvar with letsham, since these need to be rewritten at any use. *)

      fun case_ExternType z ({selfe, selfv, selft}, G) (v, s, NONE, e) =
        (* kind of trivial *)
        let
          val G = bindtype G v false
          val G = bindu0var G (mkdictvar v) (Dictionary' ` TVar' v)
        in
           ExternType' (v, s, SOME (mkdictvar v, s ^ DICT_SUFFIX), selfe z G e)
        end
        | case_ExternType _ _ _ = raise CPSDict "BUG: extern type already had dict?"

      fun case_Letsham z ({selfe, selfv, selft}, G) (v, va, e) =
        let 
          val (va, t) = selfv z G va
        in
          (*
          print ("DEBUG: letsham " ^ V.tostring v ^ "...\n";
          Layout.print (CPSPrint.ttol t, print);
          *)

          case ctyp t of
            Shamrock (w, t) => Letsham' (v, va, selfe (VS.add(z, v)) (binduvar G v (w,t)) e)
          | _ => raise CPSDict "letsham on non-shamrock"
        end

      (* actually, letd might generate these when it is implemented in the frontend *)
      fun case_WUnpack _ = raise CPSDict "BUG: shouldn't see existential world wunpack yet (?)"
      fun case_TUnpack _ = raise CPSDict "BUG: shouldn't see existential type tunpack yet"

      (* Values. AllLam needs to take new arguments and AllApp needs to provide them.
         We also rewrite Shamrock introduction, and UVars that were instances of the shamrock. *)
      fun case_AllLam z ({selfe, selfv, selft}, G) { worlds : var list, tys : var list, vals : (var * ctyp) list, body : cval } =
           let 
             (* the argument variable, the unshamrocked uvar, its type *)
             (* These shamrocks are exempt from the Sham-AllLam conversion we perform above,
                since they are known to not use their arguments. *)
             val wvars = map (fn w => (mkdictvar w, mkdictvar w, TWdict' ` W w)) worlds
             val dvars = map (fn t => (mkdictvar t, mkdictvar t, Dictionary' ` TVar' t)) tys

             val G = bindworlds G worlds
             val G = bindtypes G tys
             val G = foldr (fn ((sh, di, t), G) => 
                            let val G = bindvar G sh (Shamrock0' t) (worldfrom G)
                            in bindu0var G di t
                            end) G (wvars @ dvars)

             val vals = map (fn (sh, _, t) => (sh, Shamrock0' t)) wvars @ 
                        map (fn (sh, _, t) => (sh, Shamrock0' t)) dvars @ 
                        vals

             val (body, bodt) = selfv z G body
           in
             (AllLam' { worlds = worlds, 
                        tys = tys,
                        vals = vals,
                        body = 
                        (* open up the shamrocks, then continue with translated body.
                           (world dicts and typ dicts are treated the same here) *)
                        (* ... and because this shamrock is exempt, we won't put it in our set *)
                            foldr (fn ((sh, di, _), v) => VLetsham'(di, Var' sh, v)) body (wvars @ dvars)
                       },
              (* vletsham wrappers don't change type of body *)
              AllArrow' { worlds = worlds, tys = tys, vals = map #2 vals, body = bodt })
           end

      fun case_AllApp z ({selfe, selfv, selft}, G)  { f : cval, worlds : world list, tys : ctyp list, vals : cval list } =
         let
           val (f, t) = selfv z G f
         in
           case ctyp t of
            AllArrow { worlds = ww, tys = tt, vals = _, body = bb } =>
              let
                (* this converted allarrow has extra val args, but we
                   don't care about those... *)

                (* discard types; we'll use the annotations *)
                val vals = map #1 ` map (selfv z G) vals
                val tys = map (selft z G) tys
                val () = if length ww = length worlds andalso length tt = length tys
                         then () 
                         else raise Pass "allapp to wrong number of worlds/tys"
                val wl = ListPair.zip (ww, worlds)
                val tl = ListPair.zip (tt, tys)
                fun subt t =
                  let val t = foldr (fn ((wv, w), t) => subwt w wv t) t wl
                  in foldr (fn ((tv, ta), t) => subtt ta tv t) t tl
                  end

              in
                (AllApp' { f = f, worlds = worlds, tys = tys, 
                           vals = 
                           (* also exempt from shamrock translation *)
                              map (fn w => Sham0' ` WDictfor' w) worlds @
                              map (fn t => Sham0' ` Dictfor' t) tys @ 
                              vals },
                 subt bb)
              end
          | _ => raise CPSDict "allapp to non-allarrow"
         end


      fun case_Sham z (s as {selfe, selfv, selft}, G)  (w, va) =
        let
          val wd = mkdictvar w

          val G = bindworld G w
          val G = T.setworld G (W w)
          val G = bindu0var G wd (TWdict' (W w))
            
          val (va, t) = selfv z G va
        in
          (Sham' (w, AllLam' { worlds = nil, tys = nil, vals = [(wd, TWdict' (W w))], body = va }), 
           Shamrock' (w, AllArrow' { worlds = nil, tys = nil, vals = [TWdict' (W w)], body = t }))
        end

      fun case_VLetsham z ({selfe, selfv, selft}, G) (v, va, e) =
        let 
          val (va, t) = selfv z G va
        in
          print "VLETSHAM.\n";
          case ctyp t of
            Shamrock (w, t) => 
              let
                val z = VS.add (z, v)
                val G = binduvar G v (w,t)
                val (e, te) = selfv z G e
              in 
                (VLetsham' (v, va, e), te)
              end
          | _ => raise CPSDict "vletsham on non-shamrock"
        end

      fun case_UVar z (s as {selfe, selfv, selft}, G)  u =
        if VS.member (z, u)
        then
          let
            val (w, t) = T.getuvar G u
            val here = worldfrom G
            val t = subwt here w t
          in
            (AllApp' { worlds = nil, tys = nil, vals = [WDictfor' here], f = UVar' u },
             (case ctyp t of
                AllArrow { worlds = nil, tys = nil, vals = [wd], body } => body
              | _ => 
                  let in
                    print "BUG: invariant violation in CPSdict\n";
                    Layout.print (CPSPrint.ttol t, print);
                    print ("\nuvar: " ^ Variable.tostring u ^"\n");
                    raise CPSDict "for UVars in our set, they should have AllArrow type"
                  end))

          end
        else ID.case_UVar z (s, G) u

      (* Bugs. *)
      fun case_TPack _ = raise CPSDict "BUG: shouldn't see extential type tpack yet"
      fun case_VTUnpack _ = raise CPSDict "BUG: shouldn't see extential type vtunpack yet"
      fun case_Dictfor _ = raise CPSDict "BUG: shouldn't see dicts yet"

    end

    structure D = PassFn(DA)
    fun translate ctx e = D.converte VS.empty ctx e

end
