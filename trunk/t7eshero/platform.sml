
structure Platform =
struct

    datatype platform = datatype SDL.platform
    val platform = SDL.platform

    val shortname =
        case platform of
            WIN32 => "win32"
          | OSX => "osx"
          | LINUX => "linux"

    val dirsep =
        case platform of
            WIN32 => "\\"
          | OSX => "/"
          | LINUX => "/"

end
