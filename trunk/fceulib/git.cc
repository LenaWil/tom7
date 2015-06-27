#include "git.h"

inline const char* ESI_Name(ESI esi) {
  switch (esi) {
  case SI_NONE: return "<none>";
  case SI_GAMEPAD: return "Gamepad";
  case SI_ZAPPER: return "Zapper";
  case SI_POWERPADA : return "Power Pad A";
  case SI_POWERPADB : return "Power Pad B";
  case SI_ARKANOID: return "Arkanoid Paddle";
  case SI_MOUSE: return "Mouse";
  default: return "<invalid ESI>";
  }
}

const char *ESIFC_Name(ESIFC esifc) {
  switch (esifc) {
  case SIFC_NONE: return "<none>";
  case SIFC_ARKANOID: return "Arkanoid Paddle";
  case SIFC_SHADOW: return "Hyper Shot gun";
  case SIFC_4PLAYER: return "4-Player Adapter";
  case SIFC_FKB: return "Family Keyboard";
  case SIFC_SUBORKB: return "Subor Keyboard";
  case SIFC_HYPERSHOT: return "HyperShot Pads";
  case SIFC_MAHJONG: return "Mahjong";
  case SIFC_QUIZKING: return "Quiz King Buzzers";
  case SIFC_FTRAINERA: return "Family Trainer A";
  case SIFC_FTRAINERB: return "Family Trainer B";
  case SIFC_OEKAKIDS: return "Oeka Kids Tablet";
  case SIFC_BWORLD: return "Barcode World";
  case SIFC_TOPRIDER: return "Top Rider";
  default: return "<invalid ESIFC>";
  }
}
