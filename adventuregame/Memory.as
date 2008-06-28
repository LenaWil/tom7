/* the memory holds the global state for the game. 
   (this doesn't include stuff like inventory, which is
   stored with the player...)

   Ultimately, we should support some way for the
   memory to be safed and restored.
*/

class Memory {
  
  /* ctor */
  public function Memory() {

  }

  /* all flags default to false if not set yet */
  public function getFlag(s : String) {
    var f = this["flag_" + s];
    
    if (f == undefined) return false;
    else return f;
  }

  public function setFlag(s : String) {
    this["flag_" + s] = true;
  }

  public function clearFlag(s : String) {
    this["flag_" + s] = false;
  }

}
