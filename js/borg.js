// Generated by CoffeeScript 1.4.0
var Borg, Logger, Ssh, async, cmd, pkg;

Logger = null;

Ssh = null;

async = null;

Borg = (function() {

  Borg.nodes = [];

  Borg.args = [];

  Borg.options = {};

  Borg.cmd = {};

  function Borg(cmd) {
    var arg, last_option, match, _i, _len, _ref;
    last_option = null;
    _ref = process.argv.slice(3);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      arg = _ref[_i];
      if (match = arg.match(/^(.+?)(:(.+))?@(.+)$/)) {
        Borg.nodes.push({
          user: match[1],
          pass: match[3],
          host: match[4]
        });
      } else {
        if (arg[0] === '-') {
          Borg.options[last_option = arg.split(/^--?/)[1]] = true;
        } else if (last_option !== null) {
          Borg.options[last_option] = arg;
          last_option = null;
        } else {
          Borg.args.push(arg);
        }
      }
    }
    Borg[Borg.cmd = cmd]();
    console.log({
      cmd: Borg.cmd,
      nodes: Borg.nodes,
      args: Borg.args,
      options: Borg.options
    });
  }

  Borg.rekey = function() {};

  Borg.assimilate = function() {};

  Borg.command = function() {};

  return Borg;

})();

switch (cmd = process.argv[2]) {
  case '-V':
  case '--version':
  case 'version':
    pkg = require('../package.json');
    console.log("borg v" + pkg.version + " - by Mike Smullin <mike@smullindesign.com>\n");
    break;
  case '-h':
  case '--help':
  case 'help':
    switch (process.argv[3]) {
      case 'rekey':
        console.log("Usage: borg rekey [options] <user:password@host ...>\n\nOptions:\n\n  -i  identity file path\n");
        break;
      case 'assimilate':
        console.log("Usage: borg assimilate [options] <user:password@host ...>\n\nOptions:\n\n  -r, --role  assign each node the following role\n");
        break;
      case 'command':
        console.log("Usage: borg command [options] <user:password@host ...>\n\nOptions:\n\n  --sudo              use `sudo -i`\n  -u=<user>           use `sudo -iu`\n  -c=<shell_command>  command to execute\n");
        break;
      default:
        console.log("Usage: borg <command> [options] <host ...>\n\nCommands:\n\n  rekey       copy ssh public key to authorized_hosts on remote host(s)\n  assimilate  bootstrap and cook remote host(s)\n  command     bulk execute command on remote host(s)\n\nOptions:\n\n  -h, --help     output usage information\n  -V, --version  output version number\n");
    }
    break;
  case 'rekey':
  case 'assimilate':
  case 'command':
    Logger = require('./logger');
    Ssh = require('./ssh');
    async = require('async2');
    Borg(cmd);
}
