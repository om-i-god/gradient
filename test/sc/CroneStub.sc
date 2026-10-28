// test-only stand-in for norns' CroneEngine: just enough surface for
// Engine_Gradient to alloc, register commands/polls, and be driven from sclang
CroneEngine {
  var <context, <commands, <polls;
  *new { arg context, doneCallback;
    ^super.new.initCrone(context, doneCallback);
  }
  initCrone { arg ctx, cb;
    context = ctx; commands = IdentityDictionary.new; polls = IdentityDictionary.new;
    fork { this.alloc; cb.value(this) };
  }
  addCommand { arg name, fmt, fn; commands[name] = fn; }
  addPoll { arg name, fn; polls[name] = fn; }
  cmd { arg name ... args; commands[name].value([name] ++ args); }
}
