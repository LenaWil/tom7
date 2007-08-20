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
  open CPS CPSUtil
  structure V = Variable
  structure ValMap = SplayMapFn (type ord_key = CPS.cval
                                 val compare = CPS.cval_cmp)

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)

  (* label to use for the program's entry point.
     (we should check that this label is not used anywhere else;
      right now the only other labels start with the prefix L_ so
      there's no possibility of collision.) *)
  val mainlab = "main"

  (* During hoisting, we imperatively collect up the globals that
     we've hoisted, as well as all of the Extern World declarations
     that we see.
     We also need to keep track of a counter to generate new labels. *)
  type hoistctx = { globals : (string * CPS.cglo) list ref,
                    ctr : int ref,
                    foundworlds : (string * CPS.worldkind) list ref,
                    already : string ValMap.map ref }

  fun new () = { globals = ref nil, 
                 ctr = ref 0,
                 foundworlds = ref nil,
                 already = ref ValMap.empty } : hoistctx

  fun existsglobal { globals, ctr, foundworlds, already } v =
    ValMap.find(!already, v)
  fun saveglobal ({ globals, ctr, foundworlds, already } : hoistctx) l v =
    already := ValMap.insert (!already, v, l)

  (* PERF. we should be able to merge alpha-equivalent labels here,
     which would probably yield substantial $avings. *)
  (* XXX could derive it from a function name if it's a Lams? *)
  fun nextlab { globals, ctr, foundworlds, already } () = 
    let in
      ctr := !ctr + 1; 
      "L_" ^ Int.toString (!ctr)
    end

  fun insertat { globals, ctr, foundworlds, already } l arg =
      globals := (l, arg) :: !globals

  (* Take a global and return a label after inserting it in the global
     code table. *)
  fun insert z arg = 
    let 
      val l = nextlab z ()
    in
      insertat z l arg;
      l
    end

  fun findworld { globals, ctr, foundworlds, already } (s : string, k : CPS.worldkind) =
    case ListUtil.Alist.find op= (!foundworlds) s of
      NONE => foundworlds := (s, k) :: !foundworlds
    | SOME k' => if k = k' 
                 then ()
                 else raise Hoist ("non-agreeing extern worlds: " ^ s)
                   
  structure HA : PASSARG where type stuff = hoistctx =
  struct
    type stuff = hoistctx
    structure ID = IDPass(type stuff = stuff
                          val Pass = Hoist)
    open ID


    (* types do not change. *)


    (* The only expression we touch is ExternWorld, which we hoist
       to global scope. *)

     (* we are also hoisting these declarations to the top level,
        so we eliminate this construct *)
    fun case_ExternWorld z ({selfv, selfe, selft}, G) (l, k, e) =
         let 
           val G = T.bindworldlab G l k
         in
           findworld z (l, k);
           selfe z G e
         end

    (* some things that we shouldn't see: *)

    fun case_Primop z ({selfv, selfe, selft}, G) (_, SAY, _, _) =
      raise Hoist "unexpected SAY after closure conversion"
      | case_Primop z sg e = ID.case_Primop z sg e

    fun case_ExternType _ _ (_, _, NONE, _) =
      raise Hoist "expected dict in externtype"
      | case_ExternType z sg e = ID.case_ExternType z sg e

    fun case_Go _ _ _ = raise Hoist "Hoist expects undict-converted code, but saw Go"
    fun case_Go_cc _ _ _ = raise Hoist "Hoist expects undict-converted code, but saw Go_cc"

    fun case_Dictfor _ _ _ = raise Hoist "Hoist expects undict-converted code, but saw dictfor"
    fun case_WDictfor _ _ _ = raise Hoist "Hoist expects undict-converted code, but saw wdictfor"


    (* values are where the action is. *)

    fun case_Lams z ({selfe, selfv, selft}, G) vael =
      let
         val value = Lams' vael
         val { w, t } = freesvarsv value

         (* Don't alllam-abstract over the world variable that the value
            is typed @, even if it is free in the value. We'll abstract this 
            by the PolyCode construct. *)
         val w = (case world ` worldfrom G of
                    W wv => (V.Set.delete (w, wv) handle _ => w)
                  | WC _ => w)

         val w = V.Set.foldr op:: nil w
         val t = V.Set.foldr op:: nil t

         (*
         val () = print "Hoist FWV: "
         val () = app (fn v => print (V.tostring v ^ " ")) w
         val () = print "\nHoist FTV: "
         val () = app (fn v => print (V.tostring v ^ " ")) t
         val () = print "\n"
         *)

         (* type of the lambdas *)
         (* just use annotations *)
         val contsty = Conts' (map (fn (_, args, _) => map #2 args) vael)
         val key = AllLam' { worlds = w, tys = t, vals = nil, body = value }
      in
        case existsglobal z key of
          SOME l =>
            let in
              print ("global " ^ l ^ " reused for " ^ 
                     StringUtil.delimit "/" (map (fn (v, _, _) =>
                                                  V.tostring v) vael) ^
                     "!!\n");
              (AllApp' { f = Codelab' l, worlds = map W' w, 
                         tys = map TVar' t, vals = nil },
               contsty)
            end
        | NONE => 
            (* then a new global. *)
          let
             (* recursive vars *)
             val G = foldl (fn ((v, args, _), G) =>
                            bindvar G v (Cont' ` map #2 args) ` worldfrom G) G vael

             (* get the label where this code will eventually reside; 
                we need to substitute the label for the recursive instances *)
             val l = nextlab z ()

             val vael =
               map (fn (f, args, e) =>
                    let
                      val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G args
                      val e = selfe z G e

                      (* for each friend g, substitute through this body... *)
                      fun subs (nil, _, e) = e
                        | subs (g :: rest, i, e) =
                        let
                        in
                          subs (rest, 
                                i + 1,
                                (* the label gives us some abstracted code, so we re-apply 
                                   it to our local type variables (no need for polymorphic
                                   recursion). But we want the individual function within 
                                   that code, so we project out the 'i'th component. *)
                                subve (Fsel' (AllApp' { f = Codelab' l, 
                                                        worlds = map W' w, 
                                                        tys = map TVar' t, 
                                                        vals = nil },
                                              i)) g e)
                        end
                      val e = subs (map #1 vael, 0, e)
                    in
                      (f, args, e)
                    end) vael


             (* global thing and its type *)
             val code = AllLam' { worlds = w, tys = t, vals = nil, body = Lams' vael }
             val ty = AllArrow' { worlds = w, tys = t, vals = nil, body = contsty }

             val glo =
               (case world ` worldfrom G of
                  W wv => PolyCode' (wv, code, ty)
                | WC l => Code' (code, ty, l))

             val () = insertat z l glo

           in
             saveglobal z l key;
             print ("insert Lams at " ^ l ^ "\n");
             (* in order to preserve the local type, we apply the label to the
                world and type variables. If it is PolyCode, we don't need to apply
                to that world, since it will be determined by context (like uvars are) *)
             (AllApp' { f = Codelab' l, worlds = map W' w, tys = map TVar' t, vals = nil },
              contsty)
           end
      end

    (* purely static alllams are not converted. *)
    fun case_AllLam z sg (e as { vals = nil, ... }) = ID.case_AllLam z sg e
      (* But we hoist the closure-converted alllam with value arguments. *)
      | case_AllLam z ({selfe, selfv, selft}, G)  (e as { worlds, tys, vals, body }) =
       let
         val value = AllLam' e
         val G = bindworlds G worlds
         val G = bindtypes G tys
         val vals = ListUtil.mapsecond (selft z G) vals
         val G = foldl (fn ((v, t), G) => bindvar G v t (worldfrom G)) G vals
         val (body, tb) = selfv z G body

         val { w, t } = freesvarsv value

         (* Don't alllam-abstract over the world variable that the value
            is typed @, even if it is free in the value. We'll abstract this 
            by the PolyCode construct. *)
         val w = (case world ` worldfrom G of
                    W wv => (V.Set.delete (w, wv) handle _ => w)
                  | WC _ => w)

         val w = V.Set.foldr op:: nil w
         val t = V.Set.foldr op:: nil t

         (*
         val () = print "Hoist alllam FWV: "
         val () = app (fn v => print (V.tostring v ^ " ")) w
         val () = print "\nHoist alllam FTV: "
         val () = app (fn v => print (V.tostring v ^ " ")) t
         val () = print "\n"
         *)

         (* type of the lambdas *)
         val lamty = 
           AllArrow' { worlds = worlds, 
                       tys = tys, 
                       vals = map #2 vals, 
                       body = tb }

         (* global thing and its type *)
         val code = AllLam' { worlds = w, 
                              tys = t, 
                              vals = nil, 
                              body = AllLam' { worlds = worlds, 
                                               tys = tys, 
                                               vals = vals,
                                               body = body }
                              }
         val ty = AllArrow' { worlds = w, 
                              tys = t, 
                              vals = nil, 
                              body = lamty }

         val glo =
           (case world ` worldfrom G of
              W wv => PolyCode' (wv, code, ty)
            | WC l => Code' (code, ty, l))

         val l = insert z glo

       in
         print ("insert AllLam at " ^ l ^ "\n");

         (AllApp' { f = Codelab' l, 
                    worlds = map W' w, 
                    tys = map TVar' t, 
                    vals = nil },
          lamty)
       end


  end

  structure H = PassFn(HA)

  fun hoist home homekind program =
    let
      val hoistctx as { globals, foundworlds, ... } = new ()

      val program' = H.converte hoistctx (T.empty home) program

      val homelab = (case world home of
                       WC h => h
                     | W _ => raise Hoist "can only begin hoist conversion at a constant world.")

      val () = findworld hoistctx (homelab, homekind)

      val entry = (mainlab, Code'((* no free static things, but conform to conventions *)
                                  AllLam' { worlds = nil, tys = nil, vals = nil,
                                            (* a single no-argument lambda *)
                                            body = Lams' [(V.namedvar mainlab,
                                                           nil,
                                                           program')] },
                                  AllArrow' { worlds = nil, tys = nil, vals = nil,
                                              body = Conts' [nil] },
                                  homelab))
    in
      { worlds = !foundworlds,
        globals = entry :: !globals,
        main = mainlab }
    end

end
