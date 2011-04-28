var imap = require('imap'), // v0.2.3
    util = require('util'),
    request = require('request');
    
var ImapConnection = imap.ImapConnection,
  imap = new ImapConnection({
    username: process.env.EMAIL_USER,
    password: process.env.EMAIL_PASS,
    host: process.env.EMAIL_HOST,
    port: 993,
    secure: true
  });
  
  console.log(process.env.EMAIL_USER)

function die(err) {
  console.log('Uh oh: ' + err);
  process.exit(1);
}

var box, cmds, next = 0, cb = function(err) {
  if (err)
    die(err);
  else if (next < cmds.length)
    cmds[next++].apply(this, Array.prototype.slice.call(arguments).slice(1));
};
cmds = [
  function() { imap.connect(cb); },
  function() { imap.openBox('INBOX', false, cb); },
  function(result) { box = result; imap.search([ 'UNSEEN', ['SINCE', 'May 20, 2010'] ], cb); },
  function(results) {
    var fetch = imap.fetch(results, { request: { headers: ['from', 'to', 'subject', 'date'] } });
    fetch.on('message', function(msg) {
      console.log('Got message: ' + util.inspect(msg, false, 5));
      msg.on('data', function(chunk) {
        console.log('Got message chunk of size ' + chunk.length);
      });
      msg.on('end', function() {
        console.log('Finished message: ' + util.inspect(msg, false, 5));
      });
    });
    fetch.on('end', function() {
      console.log('Done fetching all messages!');
      imap.logout(cb);
    });
  }
];
cb();