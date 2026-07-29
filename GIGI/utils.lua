require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.webkit.*"
import "android.graphics.*"
import "android.content.*"
import "android.net.*"

cjson = require "cjson"

local function get_tier_stars(score)
  if score < 1 then
    return "空", 0
   elseif score < 1200 then
    return "黄铜", 1
   elseif score < 1400 then
    return "黄铜", 2
   elseif score < 1600 then
    return "黄铜", 3
   elseif score < 1800 then
    return "黄铜", 4
   elseif score < 2000 then
    return "黄铜", 5
   elseif score < 2100 then
    return "星银", 1
   elseif score < 2200 then
    return "星银", 2
   elseif score < 2300 then
    return "星银", 3
   elseif score < 2400 then
    return "星银", 4
   elseif score < 2500 then
    return "星银", 5
   elseif score < 2600 then
    return "赤金", 1
   elseif score < 2700 then
    return "赤金", 2
   elseif score < 2800 then
    return "赤金", 3
   elseif score < 2900 then
    return "赤金", 4
   elseif score < 3000 then
    return "赤金", 5
   else
    return "影幻", 0
  end
end
--[[
local tier, stars = get_tier_stars(1550)
print(tier, stars)  -- 黄铜 3
]]


local CHARSET = "528XM1TVN6UHQ9DLG4R3CZSYB7W0FPIEOAJK"

local function id2code(x)
  local result = ""
  while x > 0 do
    local remainder = x % 36
    result = result .. string.sub(CHARSET, remainder + 1, remainder + 1)
    x = math.floor(x / 36)
  end
  return "CA0" .. result .. "N"
end

local function base64_encode(data)
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local bytes = { string.byte(data, 1, #data) }
  local result = {}
  for i = 1, #bytes, 3 do
    local a, b, c = bytes[i], bytes[i+1], bytes[i+2]
    local n = (a or 0) * 0x10000 + (b or 0) * 0x100 + (c or 0)
    local chars = {
      b64chars:sub(math.floor(n / 0x40000) % 64 + 1, math.floor(n / 0x40000) % 64 + 1),
      b64chars:sub(math.floor(n / 0x1000) % 64 + 1, math.floor(n / 0x1000) % 64 + 1),
      b64chars:sub(math.floor(n / 0x40) % 64 + 1, math.floor(n / 0x40) % 64 + 1),
      b64chars:sub(n % 64 + 1, n % 64 + 1)
    }
    if not c then chars[4] = '=' end
    if not b then chars[3] = '=' end
    table.insert(result, table.concat(chars))
  end
  return table.concat(result)
end

local function generate_code(uid, season)
  season = season or 7
  local code_obj = {
    Code = id2code(uid),
    Season = season
  }
  local json_str = string.format('{"Code":"%s","Season":%d}', code_obj.Code, code_obj.Season)
  return base64_encode(json_str)
end

--[[
local uid = 185671151 -- 比利君
local season = 7
local code = generate_code(uid, season)
print(code)
]]

local function show_text_dialog(msg)
  local dialog = AlertDialog.Builder(this)
  dialog.setTitle("说明")
  dialog.setView(loadlayout({
    ScrollView,
    layout_width = "fill",
    layout_height = "fill",
    {
      TextView,
      paddingLeft = "24dp",
      paddingRight = "24dp",
      padding = "12dp",
      text = msg,
      textIsSelectable = true
    },
  }))
  dialog.setPositiveButton("确定", nil)
  task(20,function()
    dialog.show()
  end)
  return dialog
end

return {
  get_tier_stars = get_tier_stars,
  generate_code = generate_code,
  show_text_dialog = show_text_dialog
}