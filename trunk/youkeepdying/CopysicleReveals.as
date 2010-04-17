class CopysicleReveals extends MovieClip {

  public function onLoad() {
    this._visible = false;
  }

  public function onEnterFrame() {
    if (_root.you.hasCopysicle()) {
      this._visible = true;
    } else {
      this._visible = false;
    }
  }

}
