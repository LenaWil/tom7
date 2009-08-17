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

TCPsocket ml_tcp_open(int addr, int port) {
  IPaddress ip;
  ip.host = addr;
  ip.port = port;
  return SDLNet_TCP_Open(&ip);
}

void ml_getpeeraddress(TCPSocket sock, int *addr, int *port) {
  IPaddress *ip = SDLNet_TCP_GetPeerAddress(sock);
  if (!ip) {
    *addr = 0;
    *port =0;
  } else {
    *addr = ip->host;
    *port = ip->port;
  }
}

int ml_send_offset(TCPSock sock, char *bytes, int offset, int len) {
  return SDLNet_TCP_Send(sock, bytes + offset, len);
}

