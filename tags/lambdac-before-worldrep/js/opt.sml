
structure JSOpt :> JSOPT =
struct
  
  open JSSyntax

  infixr 9 `
  fun a ` b = a b

  exception JSOpt of string

  fun unimp s = raise JSOpt ("unimplemented javascript construct '" ^ s ^ "' in optimization. (?)")

  structure IS = Id.Set
  structure IM = Id.Map

  type fvset = IS.set
  val empty = IS.empty
  fun -- (s, v) = IS.delete (s, v) handle _ => s
  fun ++ (s, v) = IS.add (s, v)
  fun ?? (s, v) = IS.member (s, v)
  fun || (s1, s2) = IS.union (s1, s2)
  fun unionl l = foldl || empty l
  infix -- ++ ?? ||

  fun anyeffect nil = false
    | anyeffect (true :: _) = true
    | anyeffect (false :: rest) = anyeffect rest

  fun vtol v = Vector.foldr op:: nil v
  val % = Vector.fromList

  val globalsave = empty ++ JSCodegen.codeglobal

  (* oe G exp

     G is a partial map from identifiers to replacements. A
     replacement is an arbitrary effectless expression paired with a
     set of free variables in that replacement. Substitutions are
     carried out in parallel; we do not substitute into replacements
     after carrying them out.
     
     process the expression exp. carries out any substitutions in the
     context G, and returns (e, fv, ef) where e is the transformed
     expression, fv is the set of free variables (after substitution),
     and ef is a boolean indicating whether the expression is
     effectful. (We assume only function calls have effect, because
     these are the only kinds of effects that we generate now. We
     should also consider assignments to fields, e.g. as we would do
     to compile := or array updates, etc. *)

  fun oe G exp =
    case exp of
      Array eov =>
        let
          val (eov, fvs, efs) =
                      ListUtil.unzip3 ` vtol ` Vector.map (oo G) eov
        in
          (Array ` % eov, unionl fvs, anyeffect efs)
        end
    | Id i => (case IM.find (G, i) of
                 NONE => (exp, empty ++ i, false)
               | SOME (rep, fv) => (rep, fv, false))
    | New _ => unimp "new"
    | Regexp _ => unimp "regexp"
    | String _ => (exp, empty, false)
    | Number _ => (exp, empty, false)
    | This => (exp, empty, false)
    | Null => (exp, empty, false)
    | Bool _ => (exp, empty, false)
    | Seq _ => unimp "seq"
    | Assign {lhs, oper, rhs} => unimp "assign"
    | Binary {lhs, oper, rhs} => 
        let
          val (lhs, fvl, el) = oe G lhs
          val (rhs, fvr, er) = oe G rhs
        in
          (* in generality, these can definitely have effects because they invoke
             the toString methods of objects. but we only use them on things that
             are supposed to be numbers, so we can consider them effectless here. 
             XXX maybe div-zero? probably just returns undefined or nan
             *)
          (Binary { lhs = lhs, rhs = rhs, oper = oper },
           fvl || fvr,
           el orelse er)
        end
    | Call { args, func } => 
        let
          val (func, fvf, _) = oe G func
          val (args, fval, _) = ListUtil.unzip3 ` map (oe G) ` vtol args
        in
          (Call { args = % args, func = func },
           unionl fval || fvf,
           true)
        end
    | Cond { test, thenn, elsee } => 
        let
          val (test, fvs, es) = oe G test
          val (thenn, fvt, et) = oe G thenn
          val (elsee, fve, ee) = oe G elsee
        in
          (Cond { test = test, thenn = thenn, elsee = elsee },
           fvs || fvt || fve,
           es orelse et orelse ee)
        end
    | Function { name, args, body } => 
        let
          val bound = (case name of NONE => nil | SOME n => [n]) @ vtol args
          val (body, fv) = osl G ` vtol body
            
          val fv = foldr (fn (v, fv) => fv -- v) fv bound
        in
          (* PERF could shorten variables names if we want here 
             (trivial if they are unused) *)
          (* PERF could remove recursive var if unused, but we don't make
             recursive or named functions *)
          (Function { name = name, args = args, body = % body },
           fv, false)
        end
    | Object oiv =>
        let
          val (oil, fvl, efs) = ListUtil.unzip3 ` map (oi G) ` vtol oiv
        in
          (Object ` % oil,
           unionl fvl,
           anyeffect efs)
        end
    | Select _ => unimp "Select"
    | SelectId { object, property } =>
        let val (object, fv, ef) = oe G object
        in  (SelectId { object = object, property = property }, fv, ef)
        end
    | Unary _ => unimp "unary"

(*
          | Select of {object : exp,
                       property : exp}
          | SelectId of {object : exp,
                         property : Id.t}

*)

  and oi G (Get _) = unimp "objectinit-get" (* what are these? can't find them in spec *)
    | oi G (Set _) = unimp "objectinit-set"
    | oi G (Property { property, value }) =
    let val (value, fv, ef) = oe G value
    in  (Property { property = property, value = value }, fv, ef)
    end

  and oo G NONE = (NONE, empty, false)
    | oo G (SOME e) =
    let val (e, fv, ef) = oe G e
    in (SOME e, fv, ef)
    end

  and small e =
    (case e of
       Id i => true
     | Object v => Vector.length v = 0
     (* generally, textually smaller than a var decl and use. if these
        chains are long though, it may not be worth it (could measure
        a cutoff here...) *)
     | SelectId { object, property } => small object
     (* PERF: others? *)
     | _ => false)

  (* os G sl

     optimize a statement list. G is as above. returns a
     list of statements that carry out the same behavior, after applying
     the substitution. Also returns a set of free variables. *)
  and osl G nil = (nil, empty)
    | osl G (Break b :: _) = ([Break b], empty)
    | osl G (Continue b :: _) = ([Continue b], empty)
    | osl G (Return NONE :: _) = ([Return NONE], empty)
    | osl G (Return (SOME e) :: _) =
    let val (e, fv, _) = oe G e
    in ([Return (SOME e)], fv)
    end
    | osl G (Throw e :: _) =
    let val (e, fv, _) = oe G e
    in ([Throw e], fv)
    end
    | osl G (Empty :: sl) = osl G sl
    | osl G (Exp e :: sl) =
    (case oe G e of
       (_, _, false) => osl G sl  (* unused, effectless *)
     | (e, fv, true) =>
         let val (sl, fv') = osl G sl
         in
           (Exp e :: sl, fv || fv')
         end)
    | osl G (Var v :: sl) =
       (case vtol v of
          nil => osl G sl
        (* we always initialize vars, and only make one at a time. *)
        | [(i, SOME e)] =>
            let
              val (e, fv, ef) = oe G e
            in
              if not ef andalso small e
              then
                (* substitute it *)
                let
                  val G = IM.insert(G, i, (e, fv))
                in
                  print ("JS-opt: substituting " ^ Id.toString i ^ "\n");
                  osl G sl
                end
              else
                (* too big to subst, but could maybe drop it. *)
                let
                  val (sl, fvs) = osl G sl
                in
                  (* also check whether this is one of the "exports" from
                     the whole program that we ought to keep even if it's
                     never used elsewhere (globalsave) *)
                  if ef orelse fvs ?? i orelse globalsave ?? i
                  then (* keep it *)
                    ((Var ` %[(i, SOME e)]) :: sl, fv || (fvs -- i))
                  else
                    (* drop the binding; unused *)
                    let in
                      print ("JS-opt: dropping unused var " ^ Id.toString i ^ "\n");
                      (sl, fvs)
                    end
                end
            end
        | _ => unimp "long-or-noinit-vars")

    | osl G (Block b :: sl) =
       let
         val (b, fv) = osl G ` vtol b
         (* according to the ECMAscript language definition, this is not a new
            execution context. (It only seems different from b @ sl in the
            behavior of early-return constructs like Break.) So variable declarations
            in this block have scope that extends outside the block. (Tested in
            Firefox, too. It's true.) However, we generate structured code that
            never uses this fact, so we'll pretend the scope extends only to
            the outskirts of the block (by using the original context G) for the
            purposes of optimization.
            *)
         val (sl, fv') = osl G sl
       in
         (case b of
            nil => (sl, fv || fv')
          | _ => ((Block ` %b) :: sl, fv || fv'))
       end
       
    | osl G (Switch { clauses, test } :: sl) =
       let
         val (clauses, cfv) = ListPair.unzip ` 
                              map (fn (eo, sv) =>
                                   let
                                     val (eo, fve, _) = oo G eo
                                     val (sl, fvl) = ListPair.unzip ` map (os G) ` vtol sv
                                   in
                                     ((eo, % sl), fve || unionl fvl)
                                   end) ` vtol clauses
         val (test, fvt, _) = oe G test
         val (sl, fvs) = osl G sl
       in
         (Switch { clauses = % clauses,
                   test = test } :: sl,
          unionl cfv || fvt || fvs)
       end
                                                           

    (* we should never see these in our code... *)
    | osl G (FunctionDec {args, body, name} :: _) = unimp "functiondec"
    | osl G (For _ :: _) = unimp "for"
    | osl G (ForIn _ :: _) = unimp "forin"
    | osl G (ForVar _ :: _) = unimp "forvar"
    | osl G (ForVarIn _ :: _) = unimp "forvarin"
    | osl G (If _ :: _) = unimp "if"
    | osl G (Labeled (t, s) :: sl) = unimp "labeled"
    | osl G (While {test, body} :: _) = unimp "while"
    | osl G (With {body, object} :: _) = unimp "with"
    | osl G (Do {body, test} :: sl) = unimp "do"
    | osl G (Try _ :: _) = unimp "try"
    | osl G (Const _ :: _) = unimp "const"


  and os G (Block s) = let val (sl, fv) = osl G ` vtol s
                       in (Block ` % sl, fv)
                       end
    | os G s = (case osl G [s] of
                       (nil, fv) => (Empty, fv)
                     | ([s], fv) => (s, fv)
                     | (sl, fv) => (Block ` % sl, fv))

  fun optimize p =
    let
      (* start with the lib one *)
      val Javascript.Program.T p = Javascript.Program.simplify p
      (* maybe loop it? *)
      val (p, fvs) = osl IM.empty ` vtol p
    in
      Javascript.Program.T ` % p
    end
end
