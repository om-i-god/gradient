-- window: placeholder until the theme is built
return function(K)
  local M = {}
  function M.draw(S)
    K.put(2 + K.duck * 4, 0, 32, 128, 1)
    K.haze(0, 0, 128, 64, 0.2, 1, K.T * 3)
  end
  return M
end
