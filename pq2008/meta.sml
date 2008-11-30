structure Meta =
struct

    val matrix =
        Vector.fromList
        (map (fn s => Vector.fromList (explode s))
        ["kmhemunhhdxmiyvwtbpfvecvoi",
         "euvnlenubkbzrzijfhtwooaeae",
         "ordddpqbmjbrrfhenhzyipqkwq",
         "redjijgujqulbjvynvaxyptunn",
         "cmzutgwqesfvwmrnylygvmncmi",
         "icetekrncyzyvatvgetolhtrak",
         "vnbpqctyrlsdaapknwbfesioss",
         "huzyzpdpgdaawctmjlcjbtfpat",
         "wwixawpoyhlwzxcgubcakoezkk",
         "mirqnvvtxrqdnrhrinkgrvvkbk",
         "mnfvmxhjcixdvorzsnqxcyqgzg",
         "abrgdkwuifylmuamdmuagomfwy",
         "vbzubzrdfaoyozdlettluuebuw",
         "fyqsvvwjepzjnevhabdhrkwhzd",
         "nnjokreajlboelqxigzzrnysab",
         "uawmskwwlqxvdolvbeudzwiimy",
         "rbicvaxssvtszbpcypmplhchog",
         "nykgewiwjnjpbsranpmcaohyrw",
         "lroxzusspusojctartsrkrgaia",
         "grihufjgpkvzjpjaspazfnhmpc",
         "gbaofxsipouajyuzdeyzuhdatc",
         "hawwkjcugbzpqxgpliolfvhsru",
         "ihnrsbbnnbcsripgctzkdvzsuc",
         "cgkpckjkhldgojtrlmexggwfdx",
         "opninvlozkryvphxxivegmsbki",
         "ozbrxzgmirsyedkyeoltvywxrn"])

    fun matrixat (x, y) = Vector.sub(Vector.sub(matrix, y), x)

   (* OK, to back-solve, we have a letter X that is
      the output of the hash function.

      We first find all the positions in the grid
      that could end the path (i.e., contain X).
      From each one, we compute the vector for
      each word in the target set, but backwards.
      Every word has a specific vector so we can
      just compute it ahead of time. 
      
      We have a valid candidate word if the computed
      start spot meets the seek criteria: Its first
      letter is its column and its final letter is
      the row. *)
    
    exception Bad
    (* make the vector for a word (forward dir) *)
    fun makevec w =
        let
            fun mv nil = (0, 0)
              | mv (h::t) =
                let val (dx, dy) =
                    if ord h >= ord #"a" andalso ord h <= ord #"g"
                    then (~1, 0)
                    else if ord h >= ord #"h" andalso ord h <= ord #"m"
                         then (0, ~1)
                         else if ord h >= ord #"n" andalso ord h <= ord #"s"
                              then (1, 0)
                              else if ord h >= ord #"t" andalso ord h <= ord #"z"
                                   then (0, 1)
                                   else raise Bad
                    val (ddx, ddy) = mv t
                in
                    (dx + ddx, dy + ddy)
                end
        in
            mv (explode w)
        end

    val words =
        let val f = StringUtil.readfile "wordlist.asc"
            val lines = String.tokens (fn #" " => true | #"\n" => true | #"\r" => true | _ => false) f
        in
            ListUtil.mapto makevec lines
        end

    (* backsolve for the character c *)
    fun backsolve c =
        let
            val locs =
                let
                    val r = ref nil
                in
                    Util.for 0 25
                    (fn y =>
                     Util.for 0 25
                     (fn x =>
                      if matrixat (x, y) = c
                      then r := (x,y) :: !r
                      else ()));
                    !r
                end

            fun bound s = if s < 0 then s + 26
                          else if s > 25
                               then s - 26
                               else s
            fun wordsfor (x, y) =
                List.filter (fn (w, (dx, dy)) =>
                             let
                                 val (startx, starty) = (bound (x - dx), bound (y - dy))
                             in
                                 ord (CharVector.sub(w, 0)) - ord #"a" = startx
                                 andalso
                                 ord (CharVector.sub(w, size w - 1)) - ord #"a" = starty
                             end) words
        in
            (* some filter on the valid solution words *)
            List.filter (fn (w, _) => List.all (fn c => (ord c - ord #"a") < 16) (explode w)
                         andalso size w <= 6)
            (* this list contains all possible answers *)
            (List.concat (map wordsfor locs))
        end

end
