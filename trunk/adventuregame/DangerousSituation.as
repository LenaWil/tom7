class DangerousSituation extends Lookable {

  public function onLoad() {

    this.setdepth(this._y);

    /* triggered by sink */
    if (_root["memory"].getFlag("kitchen_sink")) {
      gotoAndStop(2);
      this.showname = "safely depressurized pipes";
      this.description = "It looks okay now.";
    } else {
      gotoAndStop(1);
      this.handleverb = "repair";
      this.showname = "dangerous situation";
      this.description = "Leaky pipes and faulty wiring make for a dangerous situation.";
      this.canthandle = "No way! It's dangerous!";
    }

    super.onLoad ();    
  }

};
