
#ifndef __TASBOT_NETUTIL_H
#define __TASBOT_NETUTIL_H

#include <vector>
#include <string>

#include "tasbot.h"

#include "SDL_net.h"
#include "marionet.pb.h"
#include "util.h"

// You can change this, but it must be less than 2^32 since
// we only send 4 bytes.
#define MAX_MESSAGE (1<<30)

#if !MARIONET
#error You should only include net utils when MARIONET is defined.
#endif

using namespace std;

extern string IPString(const IPaddress &ip);

// Block indefinitely on a socket until activity. This
// just creates a singleton socketset; if you want to do
// anything fancier or more efficient, use socketsets directly.
extern void BlockOnSocket(TCPsocket sock);

// Blocks until the entire proto can be read.
template <class T>
bool ReadProto(TCPsocket sock, T *t);

template <class T>
bool WriteProto(TCPsocket sock, const T &t);

// Listens on a single port for a single connection at a time,
// blocking.
struct SingleServer {
  // Aborts if listening fails.
  explicit SingleServer(int port);

  // Server starts in LISTENING state.
  enum State {
    LISTENING,
    ACTIVE,
  };

  // Must be in LISTENING state. Blocks until ACTIVE.
  void Listen();

  // Must be in ACTIVE state.
  // On error, returns false and transitions to LISTENING state.
  template <class T>
  bool ReadProto(T *t);

  // Must be in ACTIVE state.
  // On error, returns false and transitions to LISTENING state.
  template <class T>
  bool WriteProto(const T &t);

  // Must be in ACTIVE state; transitions to LISTENING.
  void Hangup();

  // Must be in ACTIVE state.
  string PeerString();

 private:
  const int port_;
  IPaddress localhost_;
  TCPsocket server_;
  State state_;
  TCPsocket peer_;
  IPaddress peer_ip_;
};

// Template implementations follow.

template <class T>
bool ReadProto(TCPsocket sock, T *t) {
  // PERF probably possible without copy.
  CHECK(sock != NULL);
  CHECK(t != NULL);

  char header[4];
  if (4 != SDLNet_TCP_Recv(sock, (void *)&header, 4)) {
    return false;
  }

  Uint32 len = SDLNet_Read32((void *)&header);
  if (len > MAX_MESSAGE) {
    fprintf(stderr, "Peer sent header with len too big.");
    return false;
  }
  char *buffer = (char *)malloc(len);
  CHECK(buffer != NULL);

  if (len != SDLNet_TCP_Recv(sock, (void *)buffer, len)) {
    free(buffer);
    return false;
  }

  if (t->ParseFromArray((const void *)buffer, len)) {
    free(buffer);
    return true;
  } else {
    free(buffer);
    return false;
  }
}

template <class T>
bool WriteProto(TCPsocket sock, const T &t) {
  CHECK(sock != NULL);
  // PERF probably possible without copy.
  string s = t.SerializeAsString();
  if (s.size() > MAX_MESSAGE) {
    fprintf(stderr, "Tried to send message too long.");
    abort();
  }
  Uint32 len = s.size();

  char header[4];
  SDLNet_Write32(len, &header);
  if (4 != SDLNet_TCP_Send(sock, (const void *)&header, 4)) {
    return false;
  }

  if (len != SDLNet_TCP_Send(sock, (const void *)s.c_str(), len)) {
    return false;
  }

  return true;
}

template <class T>
bool SingleServer::WriteProto(const T &t) {
  CHECK(state_ == ACTIVE);
  bool r = ::WriteProto(peer_, t);
  if (!r) {
    Hangup();
    state_ == LISTENING;
  }
  return r;
}

template <class T>
bool SingleServer::ReadProto(T *t) {
  CHECK(state_ == ACTIVE);
  bool r = ::ReadProto(peer_, t);
  if (!r) {
    Hangup();
    state_ == LISTENING;
  }
  return r;
}

#endif
