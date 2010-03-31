class TriggerWaterCure extends Trigger {
  public function activate() {
    if (_root.you.ailment &&
        _root.you.ailment.ailname == 'bees') {
      _root.message.say('Cured!');
      _root.you.ailment.mc.swapDepths(0);
      _root.you.ailment.mc.removeMovieClip();
      _root.you.ailment = undefined;
    }
  }
}
