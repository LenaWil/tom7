class UmbrellaCrossing extends MovieClip {

  public function onLoad() {
    if (_root.you.hasCopysicle()) {
      this.gotoAndStop('copysicle');
    } else {
      this.gotoAndStop('umbrella');
    }
  }

}
