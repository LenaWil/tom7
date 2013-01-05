
# -ltiff -lpng -ljpeg -lz -lSDL_net

# "c:\Program Files (x86)\MLton\bin\mlton" @MLton max-heap 512m -- -verbose 1 -keep g -target x86_64-w64-mingw32 -codegen amd64 -cc-opt "-g -Dmain=SDL_main" -link-opt "--enable-stdcall-fixup" -link-opt "--enable-stdcall-fixup" -link-opt "-LSDL\lib\x64 -LSDL_image\lib\x64 -advapi32 -lshell32 -luser32 -lkernel32 -lmingw32 -lgcc -lmoldname -lmingwex -lmsvcrt -lSDL -lSDLmain  -m64 -lSDL_image" -output smlversion.exe -default-ann "allowFFI true" smlversion.cm smlversion.o

rm *.o smlversion.exe

"c:\Program Files (x86)\MLton\bin\x86_64-w64-mingw32-gcc.exe" -std=gnu99 -c -I "c:\program files (x86)\mlton\lib\mlton\targets\x86_64-w64-mingw32\include" -c -I SDL\include -I SDL_image\include -O1 -fno-strict-aliasing -fomit-frame-pointer -w -fno-strength-reduce -fschedule-insns -fschedule-insns2 -malign-functions=5 -malign-jumps=2 -malign-loops=2 -I/usr/local/include -g -Dmain=SDL_main -o sdl_win32_main.o sdl_win32_main.c

"c:\Program Files (x86)\MLton\bin\x86_64-w64-mingw32-gcc.exe" -std=gnu99 -c -I "c:\program files (x86)\mlton\lib\mlton\targets\x86_64-w64-mingw32\include" -c -I SDL\include -I SDL_image\include -O1 -fno-strict-aliasing -fomit-frame-pointer -w -fno-strength-reduce -fschedule-insns -fschedule-insns2 -malign-functions=5 -malign-jumps=2 -malign-loops=2 -I/usr/local/include -g -Dmain=SDL_main -o smlversion.o smlversion.c

"c:\Program Files (x86)\MLton\bin\mlton" @MLton max-heap 512m -- -verbose 1 -target x86_64-w64-mingw32 -codegen amd64 -cc-opt "-I/usr/local/include" -cc-opt "-g -Dmain=SDL_main" -link-opt "--enable-stdcall-fixup" -link-opt "--enable-stdcall-fixup" -link-opt "-L/usr/local/lib -LSDL\lib\x64 -LSDL_image\lib\x64 -lmingw32 -lSDL -mwindows -lSDL_image -lkernel32" -output smlversion.exe -default-ann "allowFFI true" smlversion.cm smlversion.o sdl_win32_main.o
