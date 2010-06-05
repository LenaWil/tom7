structure Algorithms =
struct

    fun getalgorithm "facebook" = SOME Facebook.algorithm
      | getalgorithm "pactom" = SOME PacTom.algorithm
      | getalgorithm _ = NONE

end