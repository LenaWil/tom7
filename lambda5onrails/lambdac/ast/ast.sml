(* This simple version of the AST caches counts of free
   variables in order to speed up substitution and
   free variable checks. *)

(* TODO: 
         use vectors instead of lists?
         hash cons?
         hash for quick equality tests 
*)

(* Tried:

   de Bruijn - speeds up compares, but is quite complicated.
               debruijnizing costs at bind time, and then again
               at unbind time.
               biggest problem: free var counts are impossible
               to maintain with explicit (var/db) substitutions
               unless we also have free db sets, which are
               more difficult to maintain. (When computing the
               free vars of an explicit substitution, we only
               count the vars in the codomain when the correpsonding
               index in the domain is free.)

   delayed substitutions:

*)

functor ASTFn(A : ASTARG) :> AST where type var  = A.var
                                   and type leaf = A.leaf =
struct
  open A

  fun I x = x
  infixr 9 `
  fun a ` b = a b

  structure VM = SplayMapFn(type ord_key = var
                            val compare = var_cmp)
  structure VMU = MapUtil(structure M = VM)

  datatype 'ast front =
    $ of leaf
    (* bind, bind list *)
  | \ of var * 'ast
  | B of var list * 'ast
    (* sequence, sequence list *)
  | / of 'ast * 'ast
  | S of 'ast list
  | V of var

  infixr / \ // \\ /// \\\

  (* exception AST of string *)
  val AST = Exn

  (* First attempt. Just counting free vars. 
     invariant: the integer is strictly positive
     *)
  type 'obj objf =
    { m : int VM.map,
      f : 'obj front }

  datatype obj = O of obj objf
  and ast =
    A of { b : obj,
           (* Substitution *)
           s : obj VM.map }

  local
    infixr 9 `
    fun a ` b = a b
      
    structure L = Layout
    
    val & = L.str
    val % = L.mayAlign
    val itos = Int.toString
      
    fun mtol f m =
      L.listex "[" "]" "," ` map (fn (x, a) => %[&(var_tostring x), &"->", f a]) ` VM.listItemsi m

    fun ishow i = &(itos i)

    fun oshow (O { m, f }) =
      (* %[&"{", mtol ishow m, fshow f, &"}"] *)
      fshow f

    and fshow f =
      case f of
        $ _ => &"LEAF"
      | V v => &(var_tostring v)
      | a / b => L.paren (%[oshow a, &"/", oshow b])
      | a \ b => L.paren (%[&(var_tostring a), &"\\", oshow b])
      | _ => &"?"

    fun show (A { s, b }) =
      %[&"AST",
        %[&"subst: ", mtol oshow s],
        %[&"obj: ", oshow b]]

  in
    val layout = show
    val oshow = oshow
    val fshow = fshow
  end

  val empty = VM.empty
  val ident = VM.empty

  fun sum l = foldr (VM.unionWith op+) VM.empty l
  fun mult n m = VM.map (fn occ => occ * n) m

  fun getmap (O { m, ... }) = m
  (* remove, even if it is not present *)
  fun remove v m = #1 (VM.remove (m, v)) handle _ => m

  (* on objects, creating objects *)
  fun $$$ l = O { m = empty, f = $ l }
  fun VVV v = O { m = VM.insert(VM.empty, v, 1), f = V v }
  fun SSS ol = O { m = sum (map getmap ol), f = S ol }
  fun o1 /// o2 = O { m = sum [getmap o1, getmap o2], f = o1 / o2 }
  fun v \\\ obj = O { m = remove v (getmap obj), f = v \ obj }
  fun BBB(vl, obj) = O { m = foldr (fn (v, m) => remove v m) (getmap obj) vl,
                         f = B (vl, obj) }

  fun hideee ($ l) = $$$ l
    | hideee (V v) = VVV v
    | hideee (S al) = SSS al
    | hideee (a1 / a2) = a1 /// a2
    | hideee (v \ a) = v \\\ a
    | hideee (B (vl, a)) = BBB(vl, a)

  (* PERF: Kind of weird that we don't keep this around,
     since it is not really free to calculate *)
  fun freevars (A { s, b = O { m, ... }, ... }) =
    (* D and C are the domain and codomain of s;
       then the freevars of the ast are
          union of 
             foreach x | x in m
               if x in D then FV(C)
               else x
          *)
    let
      (* for free vars in m *)
      fun folder (x, count, FV) =
        case VM.find (s, x) of
          NONE => 
            (* not substituted away. *)
            (* sum since replacements might introduce
               more occurrences. *)
            let in
              (* print (Int.toString count ^ " bare occurrences of " ^ var_tostring x ^ "\n"); *)
              sum[FV, VM.insert(empty, x, count)]
            end
        | SOME (O { m = m', ... }) =>
            (* replacement. multiply by
               the number of occurrences of x *)
            let in
              (* print (Int.toString count ^ " replaced occurrences of " ^ var_tostring x ^ "\n"); *)
              sum[FV, mult count m']
            end
    in
      (* print "freevars:\n"; *)
      VM.foldri folder VM.empty m
    end

  fun isfree ast v =
    case VM.find(freevars ast, v) of
      NONE => false
    | SOME x => true

  fun count ast v =
    (case VM.find(freevars ast, v) of
       NONE => 0
     | SOME n => 
         let in 
           (* print (Int.toString n ^ "\n"); *)
           n
         end)

  fun oisfree (O { m, ... }) v =
    case VM.find (m, v) of 
      NONE => false
    | SOME 0 => raise Exn "oops, 0 in map"
    | SOME n => true


  (* this has to be pulled out because we do not have polymorphic
     recursion, so this gets monomorphized if it is part of the bundle below.

     in order to pull it out, we need to pass in orename as an argument.

     (XXX probably not true now that we have looky and substy separate)
     *)
  fun substy orename self (a as A { s, b = O { f, m } }) =
    (* see if substitution applies to this term at all... *)
    (* PERF could be n lg n, not n^2 *)
    let in
(*
      print "SUBSTY ";
      Layout.print (layout a, print);
      print ":\n";
*)

      if VMU.existsi (fn (v, _) =>
                      VMU.existsi (fn (v', _) =>
                                   var_eq (v, v')) s) m
      then
        case f of
          $l => $l

        | a1 / a2 => self(A { s = s, b = a1 }) / self (A { s = s, b = a2 })
        | S al => S (map (fn a => self ` A { s = s, b = a }) al)

        | V v =>
          (case VM.find (s : obj VM.map, v) of
             NONE => V v
           (* subst goes away; it is simultaneous *)
           | SOME (rep : obj) => 
               let in
(*
                 print ("Replacing " ^ var_tostring v ^ " with\n");
                 Layout.print(oshow rep, print);
                 print "\n";
*)
                 substy orename self (A{ s = ident, b = rep })
               end)

        | v \ a => 
           let
             (* if substituting for this same var, we should just remove it from
                the substitution. *)
             val dorename = 
               (case VM.find (s, v) of
                  (* or, if it appears in cod of substitution *)
                  NONE => VMU.existsi (fn (_, obj) => oisfree obj v) s
                | SOME _ => true)
           in
             if dorename
             then 
               let 
                 val v' = var_vary v
                 val a = orename [(v, v')] a
               in
                 (* print "push avoid \\\n"; *)
                 v' \ self(A { s = s, b = a })
               end
             else v \ self(A { s = s, b = a })
           end

        | B (vl, a) => 
           let
             val dorename = 
               List.exists (fn v =>
                            (case VM.find (s, v) of
                               (* or, if it appears in cod of substitution *)
                               NONE => VMU.existsi (fn (_, obj) => oisfree obj v) s
                             | SOME _ => true)) vl
           in
             if dorename
             then
               let 
                 val vl' = ListUtil.mapto var_vary vl
                 val a = orename vl' a
               in
                 (* print "push avoid B\n"; *)
                 B (map #2 vl', self(A { s = s, b = a }))
               end
             else B (vl, self(A { s = s, b = a }))
           end
      else 
        (* push in identity subst. *)
        case f of
          $l => $l
        | V v => V v
        | a1 / a2 => self(A { s = ident, b = a1 }) / self(A { s = ident, b = a2 })
        | S al => S (map (fn a => self(A { s = ident, b = a })) al)
        | v \ a => v \ self(A { s = ident, b = a })
        | B (vl, a) => B (vl, self(A { s = ident, b = a }))
    end

  fun getobj (A { b, ... }) = b

  (* on asts, creating asts *)
  fun $$ l = A { b = $$$ l,
                 s = ident }
  fun VV v = A { b = VVV v,
                 s = ident }

  (* When we have
     [S1] M1 / [S2] M2
     we must produce
     [S] (M1' / M2').
     One way to do this is to make S be the
     identity by carrying out S1 and S2 on M1 and M2.
     But we can also sometimes merge substitutions.
     
     
     *)
  exception NotDisjoint
  fun substs_disjoint al =
    let
      fun merge_two (A { s, b = O { m, ... } },
                     (subst, fvs)) =
        let
          (* where left is the new subst/term, right is the accumulator *)
          val (left, middle, right) = VMU.venn (s, subst)
        in
          (* intersection must agree. *)
          VM.app (fn objs => 
                  (* PERF do we really want to do a full compare here?
                     We can conservatively say 'no'.
                     if we start seeing binders, we should just give up.
                     Note: here would be a good place for hashes.. *)
                  if obj_cmp objs = EQUAL
                  then ()
                  else raise NotDisjoint) middle;
          (* left can't be free in right *)
          VM.appi (fn (v, _) =>
                   case VM.find (fvs, v) of
                     NONE => ()
                   | SOME _ => raise NotDisjoint) left;
          (* right can't be free in left *)
          VM.appi (fn (v, _) =>
                   case VM.find (m, v) of
                     NONE => ()
                   | SOME _ => raise NotDisjoint) right;
          
          (* mergeable. the substitution is just the union; we
             can choose either the left or right because they are agree. *)
          (VM.unionWith #1 (s, subst),
           (* the free variable set is also just the union, because we explicitly
              check for capture. *)
           (* op+ is correct, right? we aren't taking into account the effect of
              the substitution at this stage. *)
           VM.unionWith op+ (fvs, m))
        end

    in
      SOME (foldr merge_two (ident, empty) al)
    end handle NotDisjoint => NONE

  and SS al =
    case substs_disjoint al of
      SOME (subst, fvs) => 
        let in
          A { s = subst,
              b = O { f = S (map getobj al),
                      m = fvs } }
        end
    | NONE =>
        let 
          val ol = map apply_subst al
        in
          A { b = SSS ol,
              s = ident }
        end

  and a1 // a2 =
    case substs_disjoint [a1, a2] of
      SOME (subst, fvs) =>
        A { s = subst,
            b = O { f = getobj a1 / getobj a2,
                    m = fvs } }
    | NONE =>
    let
      val o1 = apply_subst a1
      val o2 = apply_subst a2
    in
      A { b = o1 /// o2,
          s = ident }
    end

  (* PERF! in the following cases we should reconcile the
     substitutions if possible, rather than eagerly carrying
     them out. *)
  and v \\ a =
    let
      val obj = apply_subst a
    in
      A { b = v \\\ obj,
          s = ident }
    end

  and BB (vl, a) =
    let val obj = apply_subst a
    in
      A { b = BBB (vl, obj),
          s = ident }
    end

  and hide ($ l) = $$ l
    | hide (V v) = VV v
    | hide (S al) = SS al
    | hide (a1 / a2) = a1 // a2 
    | hide (v \ a) = v \\ a
    | hide (B (vl, a)) = BB (vl, a)

  and osub thing v (A { s, b }) =
    let 
      (* in case v appears in the domain of the existing substitution *)
      val s = VM.map (fn obj => apply_subst (A { s = VM.insert(VM.empty, v, thing), b = obj })) s
    in
      if oisfree b v
      then
        let val news = 
          (* already being substituted? If so, we should not replace it. *)
          case VM.find (s, v) of
            NONE => VM.insert (s, v, thing)
          | SOME _ => s
        in
          A { s = news, b = b }
        end
      else A { s = s, b = b }
    end

  and sub thing v a = 
    let in
      (* print "(ext) subst\n"; *)
      osub (apply_subst thing) v a 
    end

  (* Assumes that 's' is already simultaneous (just a renaming to new distinct variables) *)
  and rename s ast =
    foldr (fn ((v, v'), ast) =>
           osub (VVV v') v ast) ast s

  and orename s obj =
    let
      val s = foldr (fn ((v, v'), s) =>
                     VM.insert(s, v, VVV v')) VM.empty s
    in
      apply_subst (A { s = s, b = obj })
    end

  and apply_subst (a as A { s, b }) = 
    if VM.isempty s 
    then b
    else
      let 
(*
        val () = print "apply_subst "
        val () = Layout.print(layout a, print)
        val () = print "\n"
*)
        val f = substy orename apply_subst a
(*
        val () = print "result:\n";
        val () = Layout.print(fshow f, print)
        val () = print "\n"
*)
      in hideee f
      end

  and obj_cmp (O{ f = $l1, ... }, O{ f = $l2, ... }) = leaf_cmp (l1, l2)
    | obj_cmp (O{ f = $_, ... }, _) = LESS
    | obj_cmp (_, O{ f = $_, ... }) = GREATER
    | obj_cmp (O{ f = V v1, ... }, O{ f = V v2, ... }) = var_cmp (v1, v2)
    | obj_cmp (O{ f = V _, ... }, _) = LESS
    | obj_cmp (_, O{f = V _, ... }) = GREATER
    | obj_cmp (O{ f = a1 / b1, ... }, O{ f = a2 / b2, ... }) =
    (case obj_cmp (a1, a2) of
       LESS => LESS
     | GREATER => GREATER
     | EQUAL => obj_cmp (b1, b2))
    | obj_cmp (O{ f = _ / _, ... }, _) = LESS
    | obj_cmp (_, O{ f = _ / _, ...}) = GREATER
    | obj_cmp (O{ f = S l1, ...}, O{ f = S l2, ... }) = objl_cmp (l1, l2)
    | obj_cmp (O{ f = S _, ...}, _) = LESS
    | obj_cmp (_, O{ f = S _, ...}) = GREATER
    | obj_cmp (O{ f = v1 \ a1, ...}, O { f = v2 \ a2, ... }) =
       let 
         val v' = var_vary v1
           (*
         val () = print ("cmp " ^ var_tostring v1 ^ "," ^ var_tostring v2 ^ " -> " ^
                         var_tostring v' ^ "\n")
            *)
         val a1 = orename [(v1, v')] a1
         val a2 = orename [(v2, v')] a2
       in
         obj_cmp (a1, a2)
       end
    | obj_cmp (O { f = _ \ _, ...}, _) = LESS
    | obj_cmp (_, O { f = _ \ _, ...}) = GREATER
    | obj_cmp (O { f = B(vl1, a1), ...}, O{ f = B(vl2, a2), ... }) =
       let
         val vl' = map var_vary vl1
         val s1 = ListPair.zip (vl1, vl')
         val s2 = ListPair.zip (vl2, vl')
           (*
         val () = print "B:\n"
         val () = ListUtil.app3 (fn (v1, v2, v') =>
                                 print ("  cmpB " ^ var_tostring v1 ^ "," ^ var_tostring v2 ^ " -> " ^
                                        var_tostring v' ^ "\n")
                                 ) vl1 vl2 vl'
         val () = print "end\n"
            *)
         val a1 = orename s1 a1
         val a2 = orename s2 a2
       in
         obj_cmp (a1, a2)
       end

  and objl_cmp (nil, nil) = EQUAL
    | objl_cmp (nil, _ :: _) = LESS
    | objl_cmp (_ :: _, nil) = GREATER
    | objl_cmp (h1 :: t1, h2 :: t2) =
       (case obj_cmp (h1, h2) of
          LESS => LESS
        | GREATER => GREATER
        | EQUAL => objl_cmp (t1, t2))

  (* PERF shouldn't be so eager to substitute *)
  fun ast_cmp (a1, a2) = obj_cmp (apply_subst a1, apply_subst a2)

  fun looky self ast =
    (* first, push subst. *)
    case substy orename I ast of
      $l => $l
    | V v => V v
    | a1 / a2 => self a1 / self a2
    | S al => S (map self al)
    | v \ a => 
      let 
        val v' = var_vary v
        val a = rename [(v, v')] a
      in
        v' \ self a
      end
    | B (vl, a) => 
      let 
        val vl' = ListUtil.mapto var_vary vl
        val a = rename vl' a
      in
        B (map #2 vl', self a)
      end

  fun look  ast = looky I     ast
  fun look2 ast = looky look  ast
  fun look3 ast = looky look2 ast
  fun look4 ast = looky look3 ast
  fun look5 ast = looky look4 ast


end
