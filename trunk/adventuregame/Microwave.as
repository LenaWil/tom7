class Microwave extends Openable {

  public function onLoad() {
    globalname = "microwave";
    showname = "microwave";
    description = "It's a KitchenStar 600w Microwave Oven with Omnifocus beam.";
    
    opentext = "There's a treasure map inside.";
    reacharea = "reach_microwave";

    this.setdepth(this._y);

    super.onLoad();
  }

  public function open () {
    _root["treasure_map"].spawn ();
  }

  public function close () {
    _root["treasure_map"].hide ();
  }

}
