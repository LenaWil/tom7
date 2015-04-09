#include <string>

#include "types.h"
#include "version.h"
#include "fceu.h"

using namespace std;

// returns a string suitable for use in an about box
string FCEUI_GetAboutString() {
  const string about =
    "FCEULib, by Tom 7 and based on\n"
    FCEU_NAME_AND_VERSION
    R"!(

Administrators:zeromus, adelikat, AnS
Current Contributors:
punkrockguy318 (Lukas Sabota)
Plombo (Bryan Cain)
qeed, QFox, Shinydoofy, ugetab
CaH4e3, gocha, Acmlm, DWEdit

FCEUX 2.0:
mz, nitsujrehtona, Lukas Sabota,
SP, Ugly Joe

Previous versions:
FCE - Bero
FCEU - Xodnizel
FCEU XD - Bbitmaster & Parasyte
FCEU XD SP - Sebastian Porst
FCEU MM - CaH4e3
FCEU TAS - blip & nitsuja
FCEU TAS+ - Luke Gustafson

FCEUX is dedicated to the fallen heroes
of NES emulation. In Memoriam --
ugetab

" __TIME__ " " __DATE__ "\n)!";

  const string compiler =
    "g++ " __VERSION__;

  return about + compiler;
}
