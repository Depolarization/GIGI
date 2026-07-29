--多用户管理
local utils = require "utils"
import "api"

activity.setTitle("用户管理")
activity.setContentView(loadlayout({
  LinearLayout,
  orientation = "vertical",
  layout_width = "fill",
  layout_height = "fill",
  {
    Button,
    text = "添加账号",
    layout_width = "fill",
    id = "btn",
  },
  {
    ListView,
    layout_width = "fill",
    layout_height = "fill",
    visibility = View.GONE,
    id = "list",
  },
}))

local item  =  {
  LinearLayout,
  layout_width = "fill",
  layout_height = "64dp",
  gravity = "center|left",
  {
    ImageView,
    id = "image",
    layout_height = "56dp",
    layout_width = "56dp",
    layout_margin = "8dp",
  },
  {
    LinearLayout,
    orientation = "vertical",
    layout_width = "fill",
    layout_height = "fill",
    layout_weight = 1,
    gravity = "center|left",
    {
      TextView,
      textSize = "16sp",
      id = "title",
    },
    {
      TextView,
      textSize = "12sp",
      textColor = Color.GRAY,
      id = "content",
    },
  },
  {
    RadioButton,
    layout_margin = "8dp",
    focusable = false,
    clickable = false,
    id = "status",
  },
}

local adapter = LuaAdapter(activity, item)
local cur_uid_idx = activity.getSharedData("cur_uid_idx") or 1
local uid_info = load(string.format("return %s", activity.getSharedData("uid_info")))() or {}

local item_data_list = {}

for k, v in ipairs(uid_info) do
  local placeholder = {
    image = { src = default_avatar_url },
    title = "加载中",
    content = string.format("UID\t:\t%s", v.uid),
    status = { checked = (k == cur_uid_idx) },
  }
  item_data_list[k] = placeholder
  adapter.add(placeholder)
end

list.setAdapter(adapter)

for k, v in ipairs(uid_info) do
  --print(v.cookie)
  Http.get(homepage_url, v.cookie, nil, nil, function(code, content)
    if code == 200 then
      local data = cjson.decode(content)
      if data.retcode == 0 then
        local page_info = data.data.page_info
        local item = item_data_list[k]
        item.title = page_info.nickname
        item.image.src = page_info.avatar_url
        local tier, stars = utils.get_tier_stars(page_info.ladder_score)
        item.content = string.format("UID\t:\t%s\t\t段位:%s%s", v.uid, tier, string.rep("★", stars))
      end
    end
    if k == #uid_info then
      adapter.notifyDataSetChanged()
      list.setVisibility(View.VISIBLE)
    end
  end)
end

btn.onClick = function()
  activity.newActivity("login")
end

list.onItemClick = function(parent, v, pos, id)
  local idx = pos + 1
  if cur_uid_idx ~= idx then
    cur_uid_idx = idx
    activity.setSharedData("cur_uid_idx", cur_uid_idx)
    local count = adapter.getCount()
    for i = 0, count - 1 do
      local item = adapter.getItem(i)
      item.status.checked = (i + 1 == cur_uid_idx)
    end
    adapter.notifyDataSetChanged()
  end
  return true
end

list.onItemLongClick = function(parent, v, pos, id)
  local idx = pos + 1
  local count = adapter.getCount()

  if count <= 1 then
    print("至少保留一个账户，不能删除")
    return true
  end
  if idx == cur_uid_idx then
    print("不能删除当前选中的账户")
    return true
  end

  AlertDialog.Builder(activity)
  .setTitle("确认删除")
  .setMessage("确定要删除该账号吗？")
  .setPositiveButton("确定", function()
    adapter.remove(pos)

    table.remove(item_data_list, idx)
    table.remove(uid_info, idx)

    if idx < cur_uid_idx then
      cur_uid_idx = cur_uid_idx - 1
    end

    activity.setSharedData("cur_uid_idx", cur_uid_idx)
    activity.setSharedData("uid_info", dump(uid_info))
    
    adapter.notifyDataSetChanged()
    local count_new = adapter.getCount()
    for i = 0, count_new - 1 do
      local item = adapter.getItem(i)
      item.status.checked = (i + 1 == cur_uid_idx)
    end
    adapter.notifyDataSetChanged()
  end)
  .setNegativeButton("取消", nil)
  .show()
  return true
end

function onCreateOptionsMenu(menu)
  menu.add("说明")
end

function onOptionsItemSelected(item)
  local title = item.title
  if title == "说明" then
    utils.show_text_dialog([[删除用户即退出登录。不可删除当前处于登录状态的用户，需要切换至其他用户后再删除，且必须保留至少一个用户。

为避免反复要求登录，强烈建议只保留一个账号！存在太多账号时，不确定全部功能都可正常可用。

软件运行出现异常时，请删除多余的账号，或手动清除软件数据，并只登录最常用的账号，并及时反馈。]])
  end
end