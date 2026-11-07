-- static checks on the SuperCollider engine for things a Mac test run
-- can't catch because they only go wrong on the norns' ARM build

local function source()
  local f = assert(io.open("lib/Engine_Gradient.sc"))
  local s = f:read("a"); f:close()
  return s
end

-- norns' sqrt returns NaN for 0 and denormals; one NaN freezes the master's
-- Amplitude followers for good. every sqrt must clamp its input first
test("engine: every sqrt is clamped away from zero", function()
  local n = 0
  for line in source():gmatch("[^\n]+") do
    if not line:match("^%s*//") and line:find("%.sqrt") then
      n = n + 1
      assert(line:find("%.max%([%d%.e%-]+%)%.sqrt"), "unguarded sqrt: " .. line)
    end
  end
  assert(n > 0, "expected the crush sqrt")
end)

test("engine: master sanitizes both inputs", function()
  local m = source():match("SynthDef%(\\grad_master.-%}%)%.add")
  assert(m, "grad_master not found")
  local _, c = m:gsub("Sanitize%.ar%(In%.ar", "")
  assert(c == 2, "expected Sanitize on dry and pump inputs, found " .. c)
end)
