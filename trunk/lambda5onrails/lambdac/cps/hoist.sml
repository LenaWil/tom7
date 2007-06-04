(* After closure conversion and undictionarying, all functions are
   closed to dynamic variables and uvariables. This means that we can
   hoist this code out of its nestled environs to the top-level and
   give it a global name. At run-time, we pass around these names
   instead of the code itself.
   
   Though the code is closed to dynamic variables, it may have free
   static (world and type) variables. When we extract the code from
   the scope of these variables, we need to abstract the code over
   those variables and apply it to them back in its original location.

   In fact, the code might be typed @ a free world variable. So the
   hoisted code might be polymorphic in the world at which it is typed,
   that is, valid. (Actually, we really parameterize the typing judgment
   here by the world, so the world parameter can appear in the type of
   the code as well, unlike with traditional valid things.)
   
*)

structure Hoist :> HOIST =
struct

  infixr 9 `
  fun a ` b = a b

  exception Hoist of string
  open CPS
  structure V = Variable

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)


  fun hoist home program =
    let
      val accum = ref nil
      val ctr = ref 0
      (* PERF. we should be able to merge alpha-equivalent labels here,
         which would probably yield substantial $avings. *)
      (* Take code and return a label after inserting it in the global
         code table. *)
      fun insert (arg as (ws, ts, vael)) =
          let
              (* XXX could derive it from a function name in vael? *)
              val l = "L_" ^ Int.toString (!ctr)
          in
              ctr := !ctr + 1;
              accum := arg :: !accum;
              l
          end

      (* types do not change. *)
      fun ct t = t

      (* don't need to touch expressions, but we do need to set up the
         typing context... *)
      fun ce G exp =
    (case cexp exp of
       Call (f, args) =>
         let
           val (f, _) = cv G f
           val (args, _) = ListPair.unzip ` map (cv G) args
         in
           Call' (f, args)
         end
         
     | Halt => exp
     | ExternVal (v, l, t, wo, e) =>
         let val t = ct t
         in
           ExternVal'
           (v, l, t, wo, 
            ce (case wo of
                  NONE => binduvar G v t
                | SOME w => bindvar G v t w) e)
         end

     | ExternWorld (l, e) => ExternWorld' (l, ce (T.bindworldlab G l) e)

     | Primop ([v], LOCALHOST, [], e) =>
           Primop' ([v], LOCALHOST, [], 
                    ce (binduvar G v ` Addr' ` worldfrom G) e)
           
     | Primop ([v], BIND, [va], e) =>
         let
           val (va, t) = cv G va
           val G = bindvar G v t ` worldfrom G
         in
           Primop' ([v], BIND, [va], ce G e)
         end

     | Primop ([v], PRIMCALL { sym, dom, cod }, vas, e) =>
         let
           val vas = map (fn v => #1 ` cv G v) vas
           val cod = ct cod
         in
           Primop'([v], PRIMCALL { sym = sym, dom = map ct dom, cod = cod }, vas,
                   ce (bindvar G v cod ` worldfrom G) e)
         end

     | Leta (v, va, e) =>
         let val (va, t) = cv G va
         in
           case ctyp t of
             At (t, w) => 
               Leta' (v, va, ce (bindvar G v t w) e)
           | _ => raise Hoist "leta on non-at"
         end

     | Letsham (v, va, e) =>
         let val (va, t) = cv G va
         in
           case ctyp t of
             Shamrock t => 
               Letsham' (v, va, ce (binduvar G v t) e)
           | _ => raise Hoist "letsham on non-shamrock"
         end

     | Put (v, t, va, e) => 
         let
           val t = ct t
           val (va, _) = cv G va
           val G = binduvar G v t
         in
           Put' (v, t, va, ce G e)
         end


     | TUnpack (tv, td, vvs, va, ve) =>
           let
             val (va, t) = cv G va
           in
             case ctyp t of
               TExists (vr, tl) =>
                 let
                   val tl = map (subtt (TVar' tv) vr) tl

                   (* new type, can't be mobile *)
                   val G = bindtype G tv false
                   val vvs = ListUtil.mapsecond ct vvs

                   val vs = map #2 vvs
                   (* the dict *)
                   val G = binduvar G td ` Dictionary' ` TVar' tv
                   (* some values now *)
                   val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vvs
                 in
                   TUnpack' (tv, td, vvs, va, ce G ve)
                 end
             | _ => raise Hoist "tunpack non-exists"
           end

     | Go (w, addr, body) => raise Hoist "Hoist expects undict-converted code, but saw Go"
     | Go_cc _ => raise Hoist "Hoist expects undict-converted code, but saw Go_cc"


     (* XXX Go_mar *)

     | _ =>
         let in
           print "HOIST: unimplemented exp:\n";
           Layout.print (CPSPrint.etol exp, print);
           raise Hoist "unimplemented EXP"
         end

           )


      (* for values, only Lams is relevant

         XXX I think we need to hoist alllam when it has a value argument,
         since it is also closure-converted.
         *)
      and cv G value =
        (case cval value of
           Lams vael =>
             let
               val { w, t } = freesvarsv value
               val w = V.Set.foldr op:: nil w
               val t = V.Set.foldr op:: nil t

               val () = print "Hoist FWV: "
               val () = app (fn v => print (V.tostring v ^ " ")) w
               val () = print "\nHoist FTV: "
               val () = app (fn v => print (V.tostring v ^ " ")) t
               val () = print "\n"

               val l = insert (w, t, vael)
                   
             in
           (* AllApp' { f = Codelab' l, worlds = map W w, tys = map TVar' t, vals = nil }; *)
               raise Hoist "unimplemented"
             end
           
         | Int _ => (value, Zerocon' INT)
         | String _ => (value, Zerocon' STRING)
             
         | Record lvl =>
             let 
               val (l, v) = ListPair.unzip lvl
               val (v, t) = ListPair.unzip ` map (cv G) v
             in
               (Record' ` ListPair.zip (l, v),
                Product' ` ListPair.zip (l, t))
             end
           
         | Var v => 
             let in
               (* print ("Lookup " ^ V.tostring v ^ "\n"); *)
               (value, #1 ` T.getvar G v)
             end
           
         | UVar v => 
             let in
               (* print ("Lookup " ^ V.tostring v ^ "\n"); *)
               (value, T.getuvar G v)
             end
           
         | Inj (s, t, vo) => let val t = ct t 
                             in (Inj' (s, ct t, Option.map (#1 o cv G) vo), t)
                             end
                           
         | Hold (w, va) => 
                     let
                       val G = T.setworld G w
                       val (va, t) = cv G va
                     in
                       (Hold' (w, va),
                        At' (t, w))
                     end

         | Sham (w, va) =>
                     let
                       val G' = bindworld G w
                       val G' = T.setworld G' (W w)
                         
                       val (va, t) = cv G' va
                     in
                       (Sham' (w, va),
                        Shamrock' t)
                     end
                   
         | Roll (t, va) => 
                     let
                       val t = ct t
                       val (va, _) = cv G va
                     in
                       (Roll' (t, va), t)
                     end
                   
         | Proj (l, va) =>
            let val (va, t) = cv G va
            in
              case ctyp t of
                Product stl => (case ListUtil.Alist.find op= stl l of
                                  NONE => raise Hoist ("proj label " ^ l ^ " not in type")
                                | SOME t => (Proj' (l, va), t))
              | _ => raise Hoist "proj on non-product"
            end

         | Fsel ( va, i ) =>
            let val (va, t) = cv G va
            in
              case ctyp t of
                Conts tll => (Fsel' (va, i), Cont' ` List.nth (tll, i))
              | _ => raise Hoist "fsel on non-conts"
            end

         | AllApp { f, worlds, tys, vals } =>
             let
               val (f, t) = cv G f
             in
               case ctyp t of
                AllArrow { worlds = ww, tys = tt, vals = vv, body = bb } =>
                  let
                    (* discard types; we'll use the annotations *)
                    val vals = map #1 ` map (cv G) vals
                    val tys = map ct tys
                    val () = if length ww = length worlds andalso length tt = length tys
                             then () 
                             else raise Hoist "allapp to wrong number of worlds/tys"
                    val wl = ListPair.zip (ww, worlds)
                    val tl = ListPair.zip (tt, tys)
                    fun subt t =
                      let val t = foldr (fn ((wv, w), t) => subwt w wv t) t wl
                      in foldr (fn ((tv, ta), t) => subtt ta tv t) t tl
                      end

                  in
                    (AllApp' { f = f, worlds = worlds, tys = tys, vals = vals },
                     subt bb)
                  end
              | _ => raise Hoist "allapp to non-allarrow"
             end

         | Dictfor _ => raise Hoist "Should not see dictfor after undictionarying"

         | VTUnpack (tv, td, vvs, va, ve) =>
               let
                 val (va, t) = cv G va
               in
                 case ctyp t of
                   TExists (vr, tl) =>
                     let
                       val tl = map (subtt (TVar' tv) vr) tl

                       (* new type, can't be mobile *)
                       val G = bindtype G tv false
                       val vvs = ListUtil.mapsecond ct vvs

                       val vs = map #2 vvs
                       (* the dict *)
                       val G = binduvar G td ` Dictionary' ` TVar' tv
                       (* some values now *)
                       val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vvs

                       val (ve, et) = cv G ve
                     in
                       (VTUnpack' (tv, td, vvs, va, ve),
                        (* better not use tv *)
                        et)
                     end
                 | _ => raise Hoist "vtunpack non-exists"
               end

         | VLetsham (v, va, ve) =>
               let
                 val (va, t) = cv G va
               in
                 case ctyp t of
                   Shamrock t' =>
                     let
                       val G = binduvar G v t'
                       val (ve, te) = cv G ve
                     in
                       (VLetsham'(v, va, ve), te)
                     end
                 | _ => raise Hoist "vletsham non-shamrock"
               end

         | VLeta (v, va, ve) =>
               let
                 val (va, t) = cv G va
               in
                 case ctyp t of
                   At (t', w') =>
                     let
                       val G = bindvar G v t' w'
                       val (ve, te) = cv G ve
                     in
                       (VLeta'(v, va, ve), te)
                     end
                 | _ => raise Hoist "vleta non-at"
               end

         | TPack (t, tas, vd, vs) =>
           let
             val tas = ct tas
             val (vd, _) = cv G vd
             val (vs, _) = ListPair.unzip ` map (cv G) vs
           in
             (TPack' (t, tas, vd, vs),
              (* assume annoation is correct *)
              tas)
           end

         | Dict tf =>
           let
             fun edict' s (Primcon(DICTIONARY, [t])) = t
               | edict' s _ = raise Hoist (s ^ " dict with non-dicts inside")

             fun edict s t = edict' s ` ctyp t
           in
             case tf of
                Primcon(pc, dl) =>
                  let
                    val (dl, tl) = ListPair.unzip ` map (cv G) dl
                    val ts = map (edict "primcon") tl
                  in
                    (Dict' ` Primcon (pc, dl), Dictionary' ` Primcon'(pc, tl))
                  end
              | Product sdl =>
                  let
                    val (ss, ds) = ListPair.unzip sdl
                    val (ds, ts) = ListPair.unzip ` map (cv G) ds
                    val stl = ListPair.zip (ss, ts)
                    val sdl = ListPair.zip (ss, ds)
                  in
                    (Dict' ` Product sdl, Dictionary' ` Product' stl)
                  end
              | Shamrock d => 
                  let
                    val (d, t) = cv G d
                  in
                    (Dict' ` Shamrock d,
                     Dictionary' ` Shamrock' ` edict "sham" ` t)
                  end

              | Cont dl => 
                  let
                    val (dl, tl) = ListPair.unzip ` map (cv G) dl
                  in
                    (Dict' ` Cont dl,
                     Dictionary' ` Cont' ` map (edict "cont") tl)
                  end

              | Addr w => (Dict' ` Addr w, Dictionary' ` Addr' w)
              | At (d, w) => 
                  let
                    val (d, t) = cv G d
                  in
                    (Dict' ` At (d, w),
                     Dictionary' ` At' (edict "at" t, w))
                  end

              | TExists((v1, v2), vl) =>
                  let
                    val G = bindtype G v1 false
                    val G = binduvar G v2 (Dictionary' ` TVar' v1)

                    val (dl, tl) = ListPair.unzip ` map (cv G) vl
                  in
                    (Dict' ` TExists((v1, v2), dl),
                     Dictionary' ` TExists' (v1, map (edict "texists") tl))
                  end

              | _ => raise Hoist "unimplemented dict typefront"
           end


         | _ => 
             let in
               print "HOIST: unimplemented val\n";
               Layout.print (CPSPrint.vtol value, print);
               raise Hoist "unimplemented VAL"
             end)

      val program' = ce (T.empty home) program
    in
      (* FIXME wrap program' with global bindings *)
      raise Hoist "unimplemented"
    end

end
