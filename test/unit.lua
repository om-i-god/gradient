-- tiny test runner: lua test/unit.lua test/unit_*.lua   (run from repo root)
function include(p) return dofile(p .. ".lua") end

local tests = {}
function test(name, fn) tests[#tests + 1] = {name = name, fn = fn} end

for _, f in ipairs(arg) do dofile(f) end

local failed = 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then print("ok " .. t.name)
  else failed = failed + 1; print("FAIL " .. t.name .. ": " .. tostring(err)) end
end
print(string.format("%d tests, %d failed", #tests, failed))
os.exit(failed == 0 and 0 or 1)
