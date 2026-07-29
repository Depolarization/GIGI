utils = require "utils"
import "api"
import "com.bumptech.glide.Glide"
import "android.content.res.ColorStateList"

activity.setTitle("积分排行榜")
activity.getActionBar().setSubtitle("点击列表项可查看玩家信息")
activity.setContentView(loadlayout({
  LinearLayout,
  orientation = "vertical",
  layout_width = "fill",
  layout_height = "fill",
  {
    PageView,
    layout_width = "fill",
    layout_height = "fill",
    id = "page_view",
    pages = {
      { -- 第一个页面：巅峰积分
        ListView,
        layout_width = "fill",
        layout_height = "fill",
        fastScrollEnabled = true,
        id = "peak_list",
      },
      { -- 第二个页面：赛事积分
        ListView,
        layout_width = "fill",
        layout_height = "fill",
        fastScrollEnabled = true,
        id = "rank_list",
      },
    },
  },
}))

local tab_titles = {"巅峰积分", "赛事积分"}
local load_peak_data, load_rank_data
local peak_data_loaded, rank_data_loaded = false, false
local action_bar = activity.getActionBar()
action_bar.setNavigationMode(ActionBar.NAVIGATION_MODE_TABS)
for k, v in ipairs(tab_titles) do
  local tab = action_bar.newTab()
  tab.setText(v)
  tab.setTabListener(ActionBar.TabListener({
    onTabSelected = function()
      page_view.setCurrentItem(k - 1)
    end,
  }))
  action_bar.addTab(tab)
end

page_view.setOnPageChangeListener(PageView.OnPageChangeListener({
  onPageSelected = function(idx)
    action_bar.getTabAt(idx).select()
    if idx == 0 and not peak_data_loaded then
      load_peak_data()
      peak_data_loaded = true
      elseif idx == 1 and not rank_data_loaded then
      load_rank_data()
      rank_data_loaded = true
      end
  end
}))

local cur_uid_idx = activity.getSharedData("cur_uid_idx")
local uid_info = load(string.format("return %s", activity.getSharedData("uid_info")))()
local cur_info = uid_info[cur_uid_idx]
local cur_uid = cur_info.uid
local cur_cookie = cur_info.cookie

local peak_api = string.format(
"https://hk4e-api.mihoyo.com/event/geniusinvokationtcg/peak_rank?page_size=999&page_token=&badge_uid=%s&badge_region=cn_gf01&game_biz=hk4e_cn&lang=zh-cn",
cur_uid
)
local rank_api = string.format(
"https://hk4e-api.mihoyo.com/event/geniusinvokationtcg/rank?page_size=999&page_token=&badge_uid=%s&badge_region=cn_gf01&game_biz=hk4e_cn&lang=zh-cn",
cur_uid
)

local function get_data(url, callback)
  Http.get(url, cur_cookie, nil, nil, function(code, content)
    if code == 200 then
      local data = cjson.decode(content)
      if data.retcode == 0 then
        callback(data.data)
       else
        callback(nil)
      end
     else
      callback(nil)
    end
  end)
end

local function copy(text)
  activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(text)
end

local function show_query_dialog(uid)
  local uid = tonumber(uid)
  local code = utils.generate_code(uid, 7)
  Http.get(string.format(other_homepage_url, code, cur_uid), cur_cookie, nil, nil, function(code, content)
    if code == 200 then
      local data = cjson.decode(content)
      if data.retcode == 0 then
        local page_info = data.data.page_info
        local dialog_msg = ""
        if page_info.is_shield then
          dialog_msg = string.format("昵称\t:\t%s\nUID\t:\t%d\n\n无权访问该玩家其他信息", page_info.nickname, uid)
         else
          local entry_experience_str = ""
          local entry_number = #page_info.entry_experience
          if entry_number == 0 then
            entry_experience_str = "无参赛经历"
           else
            entry_experience_str = string.format("共%d条经历", entry_number)
            for k, v in ipairs(page_info.entry_experience) do
              entry_experience_str = string.format("%s\n%d.%s\t-\t%s(%d)",
              entry_experience_str, k, v.competition_name,
              v.competition_result, v.score)
            end
          end
          local tier, stars = utils.get_tier_stars(page_info.ladder_score)
          local roles_info = page_info.roles
          local roles_number = #roles_info
          local roles_info_str = string.format("共%d位角色，括号内为熟练度\n", roles_number)
          if roles_number == 0 then
            roles_info_str = "无展示角色"
           else
            local roles_str_table = {}
            for k, v in ipairs(roles_info) do
              table.insert(roles_str_table, string.format("%s(%d)", v.name, v.proficiency))
            end
            roles_info_str = roles_info_str .. table.concat(roles_str_table, ", ")
          end
          dialog_msg = string.format(
          "昵称\t:\t%s\nUID\t:\t%d\n段位\t:\t%s\n天梯积分\t:\t%d\n巅峰积分\t:\t%d\n展示角色\t:\t%s\n参赛经历\t:\t%s",
          page_info.nickname, uid, string.format("%s%s", tier, string.rep("★", stars)),
          page_info.ladder_score, page_info.peak_score, roles_info_str, entry_experience_str
          )
        end
        local dialog = utils.show_text_dialog(dialog_msg)
        dialog.setTitle("玩家信息")
        dialog.setPositiveButton("复制UID", function()
          copy(uid)
          print("已复制对手UID:" .. uid)
        end)
        dialog.setNegativeButton("取消", nil)
       else
        copy(uid)
        print("已复制对手UID:" .. uid)
      end
     else
      print("请检查网络重试")
    end
  end)
end

local item_layout = {
  LinearLayout,
  layout_width = "fill",
  layout_height = "64dp",
  gravity = "center|left",
  {
    ImageView,
    id = "avatar",
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
    TextView,
    textSize = "24sp",
    id = "ranking",
    layout_marginRight = "16dp",
  },
}

local resources = activity.getResources()
local rippleStateList = ColorStateList.valueOf(0x10000000)
local squareDrawable = activity.obtainStyledAttributes({import "android.R$attr".selectableItemBackground}).getResourceId(0, 0)
local function get_ripple_drawable()
  return resources.getDrawable(squareDrawable).setColor(rippleStateList)
end

local peak_players = {}
local rank_players = {}

local last_click = 0

local peak_adapter = luajava.override(BaseAdapter, {
  getCount = function()
    return int(#peak_players)
  end,
  getItem = function(proxy, position)
    return peak_players[position + 1]
  end,
  getItemId = function(proxy, position)
    return position
  end,
  getView = function(proxy, position, convertView, parent)
    local holder = {}
    if not convertView then
      convertView = loadlayout(item_layout, holder)
      convertView.setTag(holder)
     else
      holder = convertView.getTag()
    end
    local data = peak_players[position + 1]
    holder.title.setText(data.nickname)
    holder.content.setText(string.format("巅峰积分:%d\t\tUID:%d", data.score, data.uid))
    holder.ranking.setText(tostring(data.rank))

    Glide.with(activity)
    .load(data.avatar_url)
    .into(holder.avatar)

    convertView.setBackgroundDrawable(get_ripple_drawable())
    convertView.onClick = function()
      local cur = os.time()
      if cur - last_click < 1 then
        return
      end
      last_click = cur
      show_query_dialog(data.uid)
    end
    return convertView
  end
})
peak_list.setAdapter(peak_adapter)

local rank_adapter = luajava.override(BaseAdapter, {
  getCount = function()
    return int(#rank_players)
  end,
  getItem = function(proxy, position)
    return rank_players[position + 1]
  end,
  getItemId = function(proxy, position)
    return position
  end,
  getView = function(proxy, position, convertView, parent)
    local holder = {}
    if not convertView then
      convertView = loadlayout(item_layout, holder)
      convertView.setTag(holder)
     else
      holder = convertView.getTag()
    end
    local data = rank_players[position + 1]
    holder.title.setText(data.nickname)
    holder.content.setText(string.format("赛事积分:%d\t\tUID:%d", data.score, data.uid))
    holder.ranking.setText(tostring(data.rank))

    Glide.with(activity)
    .load(data.avatar_url)
    .into(holder.avatar)

    convertView.setBackgroundDrawable(get_ripple_drawable())
    convertView.onClick = function()
      local cur = os.time()
      if cur - last_click < 1 then
        return
      end
      last_click = cur
      show_query_dialog(data.uid)
    end
    return convertView
  end
})
rank_list.setAdapter(rank_adapter)

function load_peak_data()
  get_data(peak_api, function(data)
    if data and data.rank_infos and #data.rank_infos > 0 then
      peak_players = {} -- 清空
      for i, player in ipairs(data.rank_infos) do
        table.insert(peak_players, {
          rank = i,
          nickname = player.nickname or "",
          uid = tostring(player.uid),
          score = tonumber(player.peak_score) or 0, -- 字段名仍为 peak_score
          avatar_url = player.avatar_url or "",
        })
      end
      peak_adapter.notifyDataSetChanged()
      --print(string.format("巅峰积分加载完成，共 %d 名玩家", #peak_players))
     else
      print("巅峰积分数据加载失败")
    end
  end)
end

function load_rank_data()
  get_data(rank_api, function(data)
    if data and data.rank_infos and #data.rank_infos > 0 then
      rank_players = {}
      for i, player in ipairs(data.rank_infos) do
        table.insert(rank_players, {
          rank = i,
          nickname = player.nickname or "",
          uid = tostring(player.uid),
          score = tonumber(player.score) or 0, -- 数据格式相同，字段一致
          avatar_url = player.avatar_url or "",
        })
      end
      rank_adapter.notifyDataSetChanged()
      --print(string.format("赛事积分加载完成，共 %d 名玩家", #rank_players))
     else
      print("赛事积分数据加载失败")
    end
  end)
end
