// glitch insert: a single kick, then per-16th peaks with and without each
// mode. stutter should repeat the first 16th (flat peaks), reverse should
// bring energy back where the dry kick has died, chop should gate it
var e = ~eng, t = 60 / 128 / 4;
var probe = { |name, mode|
  e.cmd(\kick, 0.9, 33, 0.9, 0.3);
  // reverse reads what came before the trigger: give it a kick to read
  if(mode == 3, { (t * 2).wait });
  if(mode > 0, { e.cmd(\glitch, mode, t, t * 6, 1) });
  ~seg.("x");
  6.do { |i| (t).wait; ~seg.(name ++ " 16th " ++ (i + 1)) };
  1.5.wait; ~seg.("rest");
};
probe.("dry", 0);
probe.("stutter", 1);
probe.("tapestop", 2);
probe.("reverse", 3);
probe.("chop", 4);
probe.("crush", 5);
