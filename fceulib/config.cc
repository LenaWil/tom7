/// \file
/// \brief Contains methods related to the build configuration

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "types.h"
#include "version.h"
#include "fceu.h"
#include "driver.h"
#include "utils/memory.h"

static char *aboutString = 0;

///returns a string suitable for use in an aboutbox
// TODO(tom7): Return c++ string
char *FCEUI_GetAboutString() {
  const char *aboutTemplate =
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

  if(aboutString) return aboutString;

  const char *compilerString = FCEUD_GetCompilerString();

  //allocate the string and concatenate the template with the compiler string
  if (!(aboutString = (char*)malloc(strlen(aboutTemplate) + strlen(compilerString) + 1)))
    return nullptr;

  sprintf(aboutString,"%s%s",aboutTemplate,compilerString);
  return aboutString;
}
