var path = require('path');
var bindings = require('./lib/bindings');
var router = require('./lib/router');

var Init = bindings.init;

bindings.init = function() {

  var app = Init.apply(null,arguments);

  app.extend = function(mod) {
    mod.call(this);
  }

  app.extend(router);

  app.on("window_close",function(){
    process.nextTick(function(){
      process.exit();
    });
  });

  var createWindow = app.createWindow;

  app.createWindow = function(url,settings){

    if( settings.icons ) {
      settings.icons['smaller'] = path.resolve(settings.icons['smaller']);
      settings.icons['small'] = path.resolve(settings.icons['small']);
      settings.icons['big'] = path.resolve(settings.icons['big']);
      settings.icons['bigger'] = path.resolve(settings.icons['bigger']);
    }

    return createWindow.call(app,url,settings);
  }

  return app;
}

module.exports = bindings;