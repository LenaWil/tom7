/* Hooks and glue for SDL_net. Incomplete. */
#include <SDL.h>
#include <SDL_net.h>

int ml_resolveip(Uint32 addr, char *dest, int maxlen) {
  IPaddress ip;
  ip.host = addr;
  const char *s = SDLNet_ResolveIP(&ip);
  int len = strlen(s);
  if (!s || len > maxlen) return -1;
  {
    int i;
    for (i = 0; i < len; i++) dest[i] = s[i];
  }
  return len;
}

/* return 0 on success */
int ml_resolvehost(char *name, Uint32 *addr) {
  IPaddress ip;
  if (0 == SDLNet_ResolveHost(&ip, name, 0)) {
    *addr = ip.host;
    return 0;
  } else {
    return -1;
  }
}
