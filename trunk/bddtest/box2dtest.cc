
#include "Box2D/Box2D.h"


const int WIDTH = 800;
const int HEIGHT = 600;

const double METERS_PER_PIXEL = 0.01;

float tometers (int d) {
  return (float)d * METERS_PER_PIXEL;
}

void toworld (int xp, int yp, float &xw, float &yw) {
  xp = xp - 400;
  yp = yp - 300;
  xw = tometers(xp);
  yw = tometers(yp);
}

/* Put the origin of the world at WIDTH / 2, HEIGHT / 2.
   make the viewport show 8 meters by 6. */
const int PIXELS_PER_METER = 100;
int topixels (float d) {
  return (int)(d * (float)PIXELS_PER_METER);
}

void toscreen (float xm, float ym, int &xs, int &ys) {
  int xp = topixels(xm);
  int yp = topixels(ym);
  
  xs = (int)xp + 400;
  ys = (int)yp + 300;
}

/*
  fun vectoscreen v = toscreen (vec2xy v)
  fun screentovec (x, y) = vec2 (toworld (x, y))
*/

b2Vec2 screentovec(int x, int y) {
  float xx, yy;
  toworld(x, y, xx, yy);
  return b2Vec2(xx, yy);
}

/*
fun printpolygon (xf, polygon) =
    let
        val num = Array.length (#vertices polygon)

        val { center, ... } = BDDPolygon.compute_mass (polygon, 1.0)
        val (cx, cy) = vectoscreen (xf @*: center)
    in
        print "poly: ";
        Util.for 0 (num - 1)
        (fn i =>
         let val i2 = if i = num - 1
                      then 0
                      else i + 1
             val (x, y) = vectoscreen (xf @*: Array.sub(#vertices polygon, i))
             val (xx, yy) = vectoscreen (xf @*: Array.sub(#vertices polygon, i2))
         in
             print (Int.toString x ^ "," ^ Int.toString y ^ " -> ")
         end);
        print "\n"
    end

fun printcircle (xf, { radius, p }) =
    let
        val p = xf @*: p
        val (x, y) = toscreen (vec2xy p)
        val r = Real.round (topixels radius)
    in
        print ("circle at " ^ Int.toString x ^ "/" ^ Int.toString y ^ 
               " @" ^ Int.toString r ^ "\n")
    end


fun printshape (xf, BDDShape.Circle c) = printcircle (xf, c)
  | printshape (xf, BDDShape.Polygon p) = printpolygon (xf, p)
*/

void printfixture (const b2Transform &xf, b2Fixture *f) {
  
}

const char *GetFixtureName(b2Fixture *f) {
  if (!f) return "NULL_FIXTURE";
  const b2Body *b = f->GetBody();
  if (!b) return "NULL_BODY";
  if (!b->GetUserData()) return "NULL_DATA";
  else return (const char *)b->GetUserData();
}

void printworld (b2World *world) {
  for (b2Body *b = world->GetBodyList(); b != NULL; b = b->GetNext()) {
    // Only print drop's activity
    if (0 == strcmp((const char*) b->GetUserData(), "drop")) {
      printf("Body: \n");
      b2Transform xf = b->GetTransform();
      printf("  xf: %.2f %.2f  @%.2f\n", xf.position.x, xf.position.y,
	     xf.GetAngle());
      /*
      for (b2Fixture *f = b->GetFixtureList(); f != NULL; f = f->GetNext()) {
	printf("  Fixture.\n");
	printfixture(xf, f);
      }
      */
    }
  }

  for (b2Contact *c = world->GetContactList(); c != NULL; c = c->GetNext()) {
    const char *name1 = GetFixtureName(c->GetFixtureA());
    const char *name2 = GetFixtureName(c->GetFixtureB());
    printf("%s-%s Contact! ", name1, name2);
    if (c->IsTouching()) {
      printf("touching ");
    }
    const b2Manifold *manifold = c->GetManifold();
    b2WorldManifold world_manifold;
    c->GetWorldManifold(&world_manifold);
    printf("%d points: ", manifold->pointCount);
    for (int i = 0; i < manifold->pointCount; i++) {
      printf("%.2f %.2f, ", world_manifold.points[i].x,
	     world_manifold.points[i].y);
    }
  }
  /*
      fun onebody b =
        let
            val xf = Body.get_transform b
            val fixtures = Body.get_fixtures b
            fun onefixture f =
                let
                    val shape = Fixture.shape f
                in
                    print "Fixture.\n";
                    printshape (xf, shape)
                end
        in
            print "Body.\n";
            oapp Fixture.get_next onefixture fixtures
        end

      fun onecontact c =
        let
            val world_manifold = { normal = vec2 (~999.0, ~999.0),
                                   points = Array.fromList
                                   [ vec2 (~111.0, ~111.0),
                                     vec2 (~222.0, ~222.0) ] }
            val { point_count, ... } = Contact.get_manifold c
            val () = Contact.get_world_manifold (world_manifold, c)
        in
            print "Contact! ";
            if Contact.is_touching c
            then print "touching "
            else ();
            print (Int.toString point_count ^ " points: ");
            for 0 (point_count - 1) 
            (fn i =>
             let val pt = Array.sub(#points world_manifold, i)
                 val (x, y) = vectoscreen pt
             in
                 print (Int.toString x ^ "," ^ Int.toString y ^ " ")
             end);

            print "\n"
        end
    in
      oapp Body.get_next onebody (World.get_body_list world);
      oapp Contact.get_next onecontact (World.get_contact_list world)
    end
  */
}

int main () {
  b2Vec2 gravity(0.0, 9.8);
  b2World world(gravity, false);

  // Create drop.
  b2BodyDef dropDef;
  dropDef.type = b2_dynamicBody;
  dropDef.position.Set(0.0, 0.12);
  dropDef.linearVelocity.Set(0.1, 0.2);
  dropDef.allowSleep = false;
  dropDef.awake = true;
  dropDef.bullet = false;
  dropDef.active = true;
  dropDef.inertiaScale = 1.0;
  dropDef.userData = (void*)"drop";

  b2Vec2 familiar_points[4];
  familiar_points[0] = screentovec(428, 305);
  familiar_points[1] = screentovec(418, 329);
  familiar_points[2] = screentovec(386, 321);
  familiar_points[3] = screentovec(377, 268);

  b2Body *dropBody = world.CreateBody(&dropDef);
  b2PolygonShape familiarShape;
  familiarShape.Set(familiar_points, 4);
  b2CircleShape dropCircle;
  dropCircle.m_p.Set(0.0, 0.0);
  dropCircle.m_radius = 0.3;

  // b2Fixture *drop_fixture = dropBody->CreateFixture(&dropShape, 1.0);
  b2Fixture *drop_fixture = dropBody->CreateFixture(&dropCircle, 1.0);

  // Create ground.
  b2BodyDef groundDef;
  groundDef.type = b2_staticBody;
  groundDef.position.Set(0.0, 0.75);
  groundDef.angle = 0.0;
  groundDef.linearVelocity.SetZero();
  groundDef.angularVelocity = 0.0;
  groundDef.angularDamping = 0.0;
  groundDef.awake = true;
  groundDef.allowSleep = false;
  groundDef.bullet = false;
  groundDef.active = true;
  groundDef.inertiaScale = 1.0;
  groundDef.userData = (void*)"ground";
  
  b2Body *groundBody = world.CreateBody(&groundDef);
  b2PolygonShape groundShape;
  groundShape.SetAsBox(6.0, 0.2);
  b2Fixture *ground_fixture = groundBody->CreateFixture(&groundShape, 1.0);
  

  printf("\n*** Startup ***\n");
  printworld(&world);  

  for (int i = 0; i < 1; i++) {
    printf("\n=== Step %d ===\n", i);
    world.Step (0.01, 10, 10);
    printworld(&world);
  }

  printf("\n\nDone.\n");
  return 0;
  /*

  fun printworld world =
    let
      fun onebody b =
        let
            val xf = Body.get_transform b
            val fixtures = Body.get_fixtures b
            fun onefixture f =
                let
                    val shape = Fixture.shape f
                in
                    print "Fixture.\n";
                    printshape (xf, shape)
                end
        in
            print "Body.\n";
            oapp Fixture.get_next onefixture fixtures
        end

      fun onecontact c =
        let
            val world_manifold = { normal = vec2 (~999.0, ~999.0),
                                   points = Array.fromList
                                   [ vec2 (~111.0, ~111.0),
                                     vec2 (~222.0, ~222.0) ] }
            val { point_count, ... } = Contact.get_manifold c
            val () = Contact.get_world_manifold (world_manifold, c)
        in
            print "Contact! ";
            if Contact.is_touching c
            then print "touching "
            else ();
            print (Int.toString point_count ^ " points: ");
            for 0 (point_count - 1) 
            (fn i =>
             let val pt = Array.sub(#points world_manifold, i)
                 val (x, y) = vectoscreen pt
             in
                 print (Int.toString x ^ "," ^ Int.toString y ^ " ")
             end);

            print "\n"
        end
    in
      oapp Body.get_next onebody (World.get_body_list world);
      oapp Contact.get_next onecontact (World.get_contact_list world)
    end

  fun key () =
      case pollevent () of
          NONE => ()
        | SOME evt =>
           case evt of
               E_KeyDown { sym = SDLK_ESCAPE } => raise Done
             | E_KeyDown { sym = SDLK_SPACE } => 
                   let in
                       (* 100ms time step *)
                       World.step (world, 0.01, 10, 10);
                       printworld world
                   end
             | _ => ()
  fun drawinstructions () =
      let
      in
          Font.draw 
          (screen, 1, 1, 
           "^3BoxDiaDia dynamics test^<. You just watch")
      end

  fun loop () =
      let in

          clearsurface (screen, color (0w255, 0w0, 0w0, 0w0));

          drawworld world;
          drawinstructions ();

          flip screen;

          key ();
          delay 1;
          (* World.step (world, 0.001, 10, 10); *)

          loop ()
      end


  val () = loop ()
  handle e =>
      let in
          print ("unhandled exception " ^
                 exnName e ^ ": " ^
                 exnMessage e ^ ": ");
          (case e of
               BDDDynamics.BDDDynamics s => print s
             | _ => print "unknown");
          print "\nhistory:\n";
          app (fn l => print ("  " ^ l ^ "\n")) (Port.exnhistory e);
          print "\n"
      end
                         
end
  */
}

