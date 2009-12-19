
#include "client.h"
#include "escapex.h"
#include "sdlutil.h"
#include "draw.h"

bool client::quick_rpc(player * plr, string path, string query, string & ret) {
  quick_txdraw td;
  
  http * hh = client::connect(plr, td.tx, &td);
  
  td.say("Connecting..");
  td.draw();

  if (!hh) { 
    message::no(&td, "Couldn't connect!");
    ret = "Couldn't connect.";
    return false;
  }
  
  extent<http> eh(hh);

  td.say("Sending command..");
  td.draw();
  
  return rpc(hh, path, query, ret);
}
