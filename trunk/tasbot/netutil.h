
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

// Connect to localhost at the given port. Blocks. Returns null on
// failure.
extern TCPsocket ConnectLocal(int port);

// Blocks until the entire proto can be read.
// If this returns false, you probably want to close the socket.
template <class T>
bool ReadProto(TCPsocket sock, T *t);

// If this returns false, you probably want to close the socket.
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

// Manages multiple outstanding requests to servers (e.g.
// SingleServers, running in other processes.).
template <class Request, class Response>
struct GetAnswers {

  // Request vector must outlast the object.
  GetAnswers(const vector<int> &ports,
             const vector<Request> &requests)
  : workdone_(0),
    workqueued_(0) {

    for (int i = 0; i < ports.size(); i++) {
      helpers_.push_back(Helper(ports[i]));
    }

    for (int i = 0; i < requests.size(); i++) {
      work_.push_back(Work(&requests[i]));
      // everything is queued if it's less than workqueued_.
      // queued_.push_back(false);
      done_.push_back(false);
    }
  }

  void Loop() {
    for (;;) {
      static const int MAXCOLS = 77;

      // If we have more tasks than fit on a line,
      // only show the left or right end.
      int low = 0, high = work_.size();
      int overflow = (high - low) - MAXCOLS;
      if (overflow > 0) {
        low = min(overflow, workdone_);
        overflow -= low;
        if (overflow > 0) {
          // Still more...
          high -= overflow;
        }
      }
      CHECK(low < high);

      fprintf(stderr, "%c", (low == 0) ? '[' : '<');
      for (int i = low; i < high; i++) {
        if (done_[i]) {
          fprintf(stderr, "#");
        } else if (i < workqueued_) {
          int helper = -1;
          // PERF...
          for (int h = 0; h < helpers_.size(); h++) {
            if (helpers_[h].workidx == i) {
              CHECK(helper == -1);
              helper = h;
            }
          }
          // Everything queued must be assigned to a helper.
          CHECK(helper != -1);
          const char c = (helper < 36) ?
            "0123456789abcdefghijklmnopqrstuvwxyz"[helper] : '+';
          fprintf(stderr, "%c", c);
        } else {
          fprintf(stderr, ".");
        }
      }
      fprintf(stderr, "%c\n", (high == work_.size()) ? ']' : '>');

      // Are we done?
      if (workdone_ == work_.size()) {
        return;
      }

      // First, see if we can get any more work enqueued.
      while (workqueued_ < work_.size()) {
        // Find an idle helper.
        int idle = GetIdleHelper();
        // All busy.
        if (idle == -1) break;

        // Sets the helper working.
        DoNextWork(idle);
      }

      // Figure out what we're waiting on.
      SDLNet_SocketSet ss = SDLNet_AllocSocketSet(helpers_.size());
      CHECK(ss != NULL);

      // Wait on anything in working state.
      int numworking = 0;
      for (int i = 0; i < helpers_.size(); i++) {
        if (helpers_[i].state == WORKING) {
          numworking++;
          CHECK(-1 != SDLNet_TCP_AddSocket(ss, helpers_[i].sock));
        }
      }
      CHECK(numworking > 0);

      // Block until something is ready.
      for (;;) {
        int numready = SDLNet_CheckSockets(ss, 10000);
        if (numready == -1) {
          fprintf(stderr, "SDLNet_CheckSockets: %s\n", SDLNet_GetError());
          perror("SDLNet_CheckSockets");
          abort();
        }

        if (numready > 0) break;
      }

      for (int i = 0; i < helpers_.size(); i++) {
        Helper *helper = &helpers_[i];

        // If working, then it's in the socket set and
        // safe to call SocketReady on.
        if (helper->state == WORKING &&
            SDLNet_SocketReady(helper->sock)) {
          // PERF: Does ready definitely mean that we
          // can read bytes?
          // This often fails right at the beginning. I think
          // maybe it's reporting SocketReady because of
          // the connection / write finishing, rather than
          // because there's data to read. Maybe should stream
          // data into the helper; it's not too hard.
          int workidx = helper->workidx;
          if (ReadProto(helper->sock,
                        &work_[workidx].res)) {
            CHECK(done_[workidx] == false);
            // fprintf(stderr, "Got result from port %d for work #%d\n",
            // helper->port,
            // workidx);
            done_[workidx] = true;
            SDLNet_TCP_Close(helper->sock);
            helper->sock = NULL;
            helper->state = DISCONNECTED;
            helper->workidx = -1;
          } else {
            // If we failed to read, reenqueue it in the same
            // helper, which preserves any invariants.
            SDLNet_TCP_Close(helper->sock);
            helper->sock = NULL;
            helper->state = DISCONNECTED;
            fprintf(stderr, "Error reading result from port %d "
                    "for work #%d!\n",
                    helper->port,
                    workidx);
            FetchWork(helper, workidx);
          }
        }
      }

      // Advance workdone if we can.
      while (workdone_ < work_.size() && done_[workdone_]) {
        workdone_++;
      }

      SDLNet_FreeSocketSet(ss);
    }
  }

  struct Work {
    // Points at one of the inputs.
    const Request *req;
    Response res;
    explicit Work(const Request *req) : req(req) {}
  };

  const vector<Work> &GetWork() const { return work_; }

 private:
  enum State {
    DISCONNECTED,
    WORKING,
  };

  struct Helper {
    explicit Helper(int port)
    : port(port),
      state(DISCONNECTED),
      workidx(-1) {}
    // Host assumed to be localhost.
    int port;
    State state;

    // Index of the work we're doing, if in state WORKING.
    int workidx;
    // Current connection, if in state WORKING.
    TCPsocket sock;
  };

  // Work must already be assigned (marked as queued).
  void FetchWork(Helper *helper, int workidx) {
    CHECK(workidx < workqueued_);
    CHECK(helper->state == DISCONNECTED);
    helper->state = WORKING;
    helper->workidx = workidx;
    helper->sock = ConnectLocal(helper->port);
    CHECK(helper->sock);
    // PERF -- could parallelize this with other writes,
    // by waiting until the socket is actually ready.
    WriteProto(helper->sock, *work_[workidx].req);
    // fprintf(stderr, "Doing work #%d on port %d.\n",
    // workidx,
    // helper->port);
  }

  void DoNextWork(int helperidx) {
    CHECK(workqueued_ < work_.size());
    int workidx = workqueued_;
    workqueued_++;
    FetchWork(&helpers_[helperidx], workidx);
  }

  // Get the index of an idle helper, or -1 if none.
  int GetIdleHelper() {
    for (int i = 0; i < helpers_.size(); i++) {
      if (helpers_[i].state == DISCONNECTED) {
        return i;
      }
    }
    return -1;
  }

  vector<Helper> helpers_;
  vector<Work> work_;
  vector<bool> done_;
  // All entries with index strictly less than workdone_
  // are done and have results. All entries with index
  // strictly less than workqueued_ have been enqueued.
  int workdone_, workqueued_;

  // IPaddress localhost_;
};

// Template implementations follow.

template <class T>
bool ReadProto(TCPsocket sock, T *t) {
  // PERF probably possible without copy.
  CHECK(sock != NULL);
  CHECK(t != NULL);

  char header[4];
  if (4 != SDLNet_TCP_Recv(sock, (void *)&header, 4)) {
    fprintf(stderr, "ReadProto: Failed to read length.\n");
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
    fprintf(stderr, "ReadProto: Failed to read %d bytes.\n", len);
    free(buffer);
    return false;
  }

  if (t->ParseFromArray((const void *)buffer, len)) {
    free(buffer);
    return true;
  } else {
    fprintf(stderr, "ReadProto: Failed parse proto.\n");
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
  SDLNet_Write32(len, (void*)header);
  if (4 != SDLNet_TCP_Send(sock, (const void *)header, 4)) {
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
    fprintf(stderr, "SingleServer failed writeproto.\n");
    Hangup();
  }
  return r;
}

template <class T>
bool SingleServer::ReadProto(T *t) {
  CHECK(state_ == ACTIVE);
  bool r = ::ReadProto(peer_, t);
  if (!r) {
    fprintf(stderr, "SingleServer failed readproto.\n");
    Hangup();
  }
  return r;
}

#endif
