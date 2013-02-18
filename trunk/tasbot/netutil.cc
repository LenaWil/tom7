
#include <string>

#include "netutil.h"
#include "SDL.h"
#include "SDL_net.h"

using namespace std;

string IPString(const IPaddress &ip) {
  return StringPrintf("%d.%d.%d.%d:%d",
                      255 & ip.host,
                      255 & (ip.host >> 8),
                      255 & (ip.host >> 16),
                      255 & (ip.host >> 24),
                      ip.port);
}

void BlockOnSocket(TCPsocket sock) {
  SDLNet_SocketSet sockset = SDLNet_AllocSocketSet(1);
  if (!sockset) {
    fprintf(stderr, "SDLNet_AllocSocketSet: %s\n", SDLNet_GetError());
    abort();
  }

  CHECK(-1 != SDLNet_TCP_AddSocket(sockset, sock));

  for (;;) {
    int numready = SDLNet_CheckSockets(sockset, -1);
    if (numready == -1) {
      fprintf(stderr, "SDLNet_CheckSockets: %s\n", SDLNet_GetError());
      perror("SDLNet_CheckSockets");
      abort();
    }

    if (numready > 0) {
      break;
    }
  }

  // Just one socket in the set, so it should be ready.
  CHECK(SDLNet_SocketReady(sock));

  SDLNet_FreeSocketSet(sockset);
}

SingleServer::SingleServer(int port) : port_(port), state_(LISTENING) {
  peer_ = NULL;
  if (SDLNet_ResolveHost(&localhost_, NULL, port_) == -1) {
    fprintf(stderr, "SDLNet_ResolveHost: %s\n", SDLNet_GetError());
    abort();
  }

  server_ = SDLNet_TCP_Open(&localhost_);
  if (!server_) {
    fprintf(stderr, "SDLNet_TCP_Open: %s\n", SDLNet_GetError());
    abort();
  }
}

void SingleServer::Listen() {
  CHECK(state_ == LISTENING);

  for (;;) {
    fprintf(stderr, "Listen...\n");
    BlockOnSocket(server_);
    if ((peer_ = SDLNet_TCP_Accept(server_))) {
      IPaddress *peer_ip_ptr = SDLNet_TCP_GetPeerAddress(peer_);
      if (peer_ip_ptr == NULL) {
        printf("SDLNet_TCP_GetPeerAddress: %s\n", SDLNet_GetError());
        abort();
      }

      peer_ip_ = *peer_ip_ptr;

      state_ = ACTIVE;
      return;
    }

    fprintf(stderr, "Socket was ready but couldn't accept?\n");
    SDL_Delay(1000);
  }
}

string SingleServer::PeerString() {
  CHECK(state_ == ACTIVE);
  return IPString(peer_ip_);
}

void SingleServer::Hangup() {
  CHECK(state_ == ACTIVE);
  
  SDLNet_TCP_Close(peer_);
  peer_ = NULL;

  state_ = LISTENING;
}
