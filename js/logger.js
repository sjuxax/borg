// Generated by CoffeeScript 1.4.0
var Logger;

module.exports = Logger = (function() {

  function Logger() {}

  Logger.started = new Date;

  Logger.out = function(s) {
    var current;
    if (typeof console !== "undefined" && console !== null) {
      current = new Date;
      return console.log("" + (current - this.started) + " | " + s);
    }
  };

  return Logger;

})();
