structure Algorithms =
struct

    fun getalgorithm "facebook" = SOME Facebook.algorithm
      | getalgorithm _ = NONE

end