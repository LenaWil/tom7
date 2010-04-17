// Kills the player, dead players, and items
// that enter it. This is expected to happen
// off-screen, so there are no animations.
class FinderIncinerate extends Finder {
  // Since buttons open (and in that sense
  // disable) gates, the sense of "activate"
  // may seem backwards.
  public function activate(p) {
    trace('incinerated ' + p);
    p.incinerate();
  }

  // Usually larger than physics objects: if the center enters, then
  // trigger.
  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.centerhit(this);
  }

  public function deactivate() {
  }

}
