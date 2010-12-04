
# for mingw.

# bddtest.exe
default : box2dtest.exe

sdlml.o : ../sdlml/sdlml.c
	gcc -O -I /usr/local/include `/usr/local/bin/sdl-config --cflags` -c ../sdlml/sdlml.c -o sdlml.o

sdlmix.o: ../sdlml/sdlmix.c
	gcc -O `/usr/local/bin/sdl-config --cflags` -c ../sdlml/sdlmix.c -o sdlmix.o

SMLS = prelude.sml images.sml real32.sml

# -const 'Exn.keepHistory true'
bddtest.exe : sdlml.o bddtest.sml ${SMLS} bddtest.cm messagebox_fake.o sdlmix.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml
	mlton @MLton max-heap 200m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -lSDL_mixer -ltiff -lpng -ljpeg -lz -lmad -lvorbisfile -lvorbis -logg" -output $@ -default-ann 'allowFFI true' bddtest.cm sdlml.o sdlmix.o messagebox_fake.o

bddanimate.exe : sdlml.o bddanimate.sml ${SMLS} bddanimate.cm messagebox_fake.o sdlmix.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml
	mlton @MLton max-heap 200m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -lSDL_mixer -ltiff -lpng -ljpeg -lz -lmad -lvorbisfile -lvorbis -logg" -output $@ -default-ann 'allowFFI true' bddanimate.cm sdlml.o sdlmix.o messagebox_fake.o

# -const 'Exn.keepHistory true'
bddtest-polygon-collisions.exe : sdlml.o bddtest-polygon-collisions.sml ${SMLS} bddtest-polygon-collisions.cm messagebox_fake.o sdlmix.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml
	mlton @MLton max-heap 200m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -lSDL_mixer -ltiff -lpng -ljpeg -lz -lmad -lvorbisfile -lvorbis -logg" -output $@ -default-ann 'allowFFI true' bddtest-polygon-collisions.cm sdlml.o sdlmix.o messagebox_fake.o

bdiff.exe : bdiff.sml bdiff.cm makefile ../sml-lib/util/*.sml
	mlton @MLton max-heap 200m --  -cc-opt "-I/usr/local/include" -link-opt "-L/usr/local/lib -lmingw32 -mwindows" -output $@ bdiff.cm


# C++ versions

OFILES = Box2D/Collision/b2BroadPhase.o Box2D/Collision/b2CollideCircle.o Box2D/Collision/b2CollidePolygon.o Box2D/Collision/b2Collision.o Box2D/Collision/b2Distance.o Box2D/Collision/b2DynamicTree.o Box2D/Collision/b2TimeOfImpact.o Box2D/Collision/Shapes/b2CircleShape.o Box2D/Collision/Shapes/b2PolygonShape.o Box2D/Common/b2BlockAllocator.o Box2D/Common/b2Math.o Box2D/Common/b2Settings.o Box2D/Common/b2StackAllocator.o Box2D/Dynamics/b2Body.o Box2D/Dynamics/b2ContactManager.o Box2D/Dynamics/b2Fixture.o Box2D/Dynamics/b2Island.o Box2D/Dynamics/b2World.o Box2D/Dynamics/b2WorldCallbacks.o Box2D/Dynamics/Contacts/b2CircleContact.o Box2D/Dynamics/Contacts/b2Contact.o Box2D/Dynamics/Contacts/b2ContactSolver.o Box2D/Dynamics/Contacts/b2PolygonAndCircleContact.o Box2D/Dynamics/Contacts/b2PolygonContact.o Box2D/Dynamics/Contacts/b2TOISolver.o Box2D/Dynamics/Joints/b2DistanceJoint.o Box2D/Dynamics/Joints/b2FrictionJoint.o Box2D/Dynamics/Joints/b2GearJoint.o Box2D/Dynamics/Joints/b2Joint.o Box2D/Dynamics/Joints/b2LineJoint.o Box2D/Dynamics/Joints/b2MouseJoint.o Box2D/Dynamics/Joints/b2PrismaticJoint.o Box2D/Dynamics/Joints/b2PulleyJoint.o Box2D/Dynamics/Joints/b2RevoluteJoint.o Box2D/Dynamics/Joints/b2WeldJoint.o

CPPFLAGS = -O -I .
CXXFLAGS = -O -I .

box2dtest.exe : box2dtest.cc ${OFILES}
	g++ -O -I . $^ -o $@

hello.exe : hello.cc
	g++ -O -I . hello.cc -o hello.exe


box2d.trace : box2dtest.exe
	./box2dtest > box2d.trace

bdd.trace : bddtest.exe
	./bddtest | tr '~' '-' > bdd.trace

# compare : box2d.trace bdd.trace bdiff.exe
# 	./bdiff

clean :
	rm -f *.o *.exe ${OFILES}
