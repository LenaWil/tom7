class TriggerBeehive extends Trigger {

  var beetime : Number;

  public function onLoad() {
    if (beetime == undefined) beetime = 6 * 25;
    super.onLoad();
  }

  public function activate() {
    // _root.cloud.play();
    _root.you.ail('bees',
                  'bees',
                  beetime,
                  {solid:true, infectious:'once'});
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.anyhit(this);
  }

}
