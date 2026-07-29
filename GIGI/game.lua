utils = require "utils"
import "api"
activity.setTitle("卡牌信息查询")
activity.setContentView(loadlayout({
  FrameLayout,
  layout_width = "fill",
  layout_height = "fill",
  {
    ProgressBar,
    layout_gravity = "center",
    id = "progress",
  },
  {
    PageView,
    layout_width = "fill",
    layout_height = "fill",
    id = "page_view",
    pages = {
      {
        LinearLayout,
        layout_width = "fill",
        layout_height = "fill",
        orientation = "vertical",
        {
          LinearLayout,
          layout_width = "fill",
          layout_height = "wrap",
          orientation = "vertical",
          layout_margin = "8dp",
          id = "char_filter_container",
        },
        {
          ListView,
          layout_width = "fill",
          layout_height = "fill",
          fastScrollEnabled = true,
          id = "char_list",
        },
      },
    
      {
        LinearLayout,
        layout_width = "fill",
        layout_height = "fill",
        orientation = "vertical",
        {
          LinearLayout,
          layout_width = "fill",
          layout_height = "wrap",
          orientation = "vertical",
          layout_margin = "8dp",
          id = "event_filter_container",
        },
        {
          ListView,
          layout_width = "fill",
          layout_height = "fill",
          fastScrollEnabled = true,
          id = "event_list",
        },
      },
    }
  },
}))

local item_layout_1 = {
  LinearLayout,
  orientation = "vertical",
  layout_width = "fill",
  layout_height = "56dp",
  gravity = "center|left",
  paddingLeft = "12dp",
  {
    TextView,
    id = "name",
    layout_width = "fill",
    textSize = "18sp",
  },
  {
    TextView,
    id = "info",
    layout_width = "fill",
    textSize = "14sp",
    textColor = Color.GRAY,
  },
}

local item_layout_2 = {
  LinearLayout,
  layout_width = "fill",
  layout_height = "48dp",
  gravity = "center|left",
  paddingLeft = "12dp",
  paddingRight = "12dp",
  {
    TextView,
    id = "name",
    layout_weight = "1",
    textSize = "18sp",
  },
  {
    TextView,
    id = "info",
    textSize = "16sp",
    textColor = Color.GRAY,
  },
}

local tab_titles = {"角色牌", "行动牌"}

local cur_uid_idx = activity.getSharedData("cur_uid_idx")
local uid_info = load(string.format("return %s", activity.getSharedData("uid_info")))()
local cur_info = uid_info[cur_uid_idx]
local cur_uid = cur_info.uid
local cur_cookie = cur_info.cookie

local card_list_url = string.format(
"https://api-takumi-record.mihoyo.com/game_record/app/genshin/api/gcg/cardList?limit=999&offset=0&server=cn_gf01&role_id=%d&need_action=true&need_avatar=true&need_stats=true",
cur_uid
)

local char_cards = {} -- 角色牌
local action_cards = {} -- 行动牌
local displayed_char = {} -- 过滤后的角色牌
local displayed_action = {} -- 过滤后的行动牌

local char_total_use = 0
local action_total_use = 0

local char_search_edit
local event_search_edit
local event_type_spinner

local summary = ""

local function calc_percent(part, total)
  return (total > 0) and (part / total * 100) or 0
end

local function format_percent(value)
  if not value or value ~= value then return "0%" end
  local str = string.format("%.1f", value)
  if string.sub(str, -2) == ".0" then
    str = string.sub(str, 1, -3)
  end
  return str .. "%"
end

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
  end
}))

local char_adapter = LuaAdapter(activity, item_layout_1)
char_list.setAdapter(char_adapter)

local event_adapter = LuaAdapter(activity, item_layout_2)
event_list.setAdapter(event_adapter)

local function update_list(adapter, data_list, total_use)
  adapter.clear()
  for _, card in ipairs(data_list) do
    local is_char = (card.card_type == "CardTypeCharacter")
    local name = card.name or "未知"
    local use_count = card.use_count or 0
    local info_text

    if is_char then
      local proficiency = card.proficiency or 0
      local use_rate = calc_percent(use_count, total_use) -- (total_use > 0) and (use_count / total_use * 100) or 0
      local win_rate = calc_percent(proficiency, use_count) -- (use_count > 0) and (proficiency / use_count * 100) or 0
      info_text = string.format("出场:%d  出场率:%s  胜率:%s  胜场:%d",
      use_count,
      format_percent(use_rate),
      format_percent(win_rate),
      proficiency
      )
     else
      info_text = string.format("出场:%d", use_count)
    end

    adapter.add({
      name = name,
      info = info_text,
    })
  end
  adapter.notifyDataSetChanged()
end

-- 过滤角色牌
local function filter_char(keyword)
  displayed_char = {}
  for _, card in ipairs(char_cards) do
    local name = card.name or ""
    if keyword == "" or name:lower():find(keyword:lower(), 1, true) then
      table.insert(displayed_char, card)
    end
  end
  update_list(char_adapter, displayed_char, char_total_use)
end

-- 过滤行动牌
local function filter_action(keyword, type_filter)
  displayed_action = {}
  for _, card in ipairs(action_cards) do
    local name = card.name or ""
    local match_name = (keyword == "" or name:lower():find(keyword:lower(), 1, true))
    local match_type = (type_filter == "全部" or card.card_type == type_filter)
    if match_name and match_type then
      table.insert(displayed_action, card)
    end
  end
  update_list(event_adapter, displayed_action, action_total_use)
end

local function build_filter_controls()
  -- 角色牌过滤
  char_filter_container.removeAllViews()
  char_search_edit = EditText(activity)
  char_search_edit.setHint("搜索角色牌名称")
  char_search_edit.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
  char_filter_container.addView(char_search_edit)

  -- 行动牌过滤
  event_filter_container.removeAllViews()
  local row_layout = LinearLayout(activity)
  row_layout.setOrientation(LinearLayout.HORIZONTAL)
  row_layout.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
  row_layout.setGravity(Gravity.CENTER_VERTICAL)

  local event_edit = EditText(activity)
  event_edit.setHint("搜索行动牌名称")
  event_edit.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  row_layout.addView(event_edit)

  local type_items = {"全部", "CardTypeModify", "CardTypeAssist", "CardTypeEvent"}
  local display_items = {"全部", "装备牌", "支援牌", "事件牌"}
  local spinner = Spinner(activity)
  spinner.setAdapter(ArrayAdapter(activity, android.R.layout.simple_spinner_item, display_items))
  local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
  params.leftMargin = 8
  spinner.setLayoutParams(params)
  row_layout.addView(spinner)
  event_filter_container.addView(row_layout)

  event_search_edit = event_edit
  event_type_spinner = spinner

  char_search_edit.addTextChangedListener({
    afterTextChanged = function()
      filter_char(char_search_edit.getText().toString())
    end
  })

  event_edit.addTextChangedListener({
    afterTextChanged = function()
      local type = display_items[spinner.getSelectedItemPosition() + 1]
      local filter_type = (type == "全部") and "全部" or type_items[spinner.getSelectedItemPosition() + 1]
      filter_action(event_edit.getText().toString(), filter_type)
    end
  })

  spinner.setOnItemSelectedListener(AdapterView.OnItemSelectedListener({
    onItemSelected = function()
      local type = display_items[spinner.getSelectedItemPosition() + 1]
      local filter_type = (type == "全部") and "全部" or type_items[spinner.getSelectedItemPosition() + 1]
      filter_action(event_edit.getText().toString(), filter_type)
    end
  }))
end

Http.get(card_list_url, cur_cookie, nil, nil, function(code, content)
  if code == 200 then
    local data = cjson.decode(content)
    if data.retcode == 0 then
      local basic_info = data.data.stats
      local list = data.data.card_list
      if list and #list > 0 then        
        char_cards = {}
        action_cards = {}
        char_total_use = 0
        action_total_use = 0
        local char_total_proficiency = 0
        local action_modify_use = 0
        local action_assist_use = 0
        local action_event_use = 0

        for _, card in ipairs(list) do
          if card.card_type == "CardTypeCharacter" then
            table.insert(char_cards, card)
            char_total_use = char_total_use + (card.use_count or 0)
            char_total_proficiency = char_total_proficiency + (card.proficiency or 0)
           else
            table.insert(action_cards, card)
            local use_count = card.use_count or 0
            action_total_use = action_total_use + use_count
            if card.card_type == "CardTypeModify" then
              action_modify_use = action_modify_use + use_count
             elseif card.card_type == "CardTypeAssist" then
              action_assist_use = action_assist_use + use_count
             elseif card.card_type == "CardTypeEvent" then
              action_event_use = action_event_use + use_count
            end
          end
        end
        
        local function sort_by_use(a, b)
          return (a.use_count or 0) > (b.use_count or 0)
        end
        table.sort(char_cards, sort_by_use)
        table.sort(action_cards, sort_by_use)
        
        build_filter_controls()

        filter_char("")
        filter_action("", "全部")

        local total_games = math.floor(char_total_use / 3)
        local win_games = math.floor(char_total_proficiency / 3)
        local win_rate = (total_games > 0) and (win_games / total_games * 100) or 0

        local modify_percent = calc_percent(action_modify_use, action_total_use)
        local assist_percent = calc_percent(action_assist_use, action_total_use)
        local event_percent = calc_percent(action_event_use, action_total_use)

        summary = string.format(
        "玩家\t:\t%s\n牌手等级\t:\t%d\n角色牌数\t:\t%d\n行动牌数\t:\t%d\n\n总对局数\t:\t%d\n获胜对局数\t:\t%d\n胜率\t:\t%s\n\n打出行动牌数\t:\t%d，其中包含:\n%d\t张装备牌，占比\t%s\n%d\t张支援牌，占比\t%s\n%d\t张事件牌，占比\t%s",
        basic_info.nickname or "未知",
        basic_info.level or 0,
        basic_info.avatar_card_num_gained or 0,
        basic_info.action_card_num_gained or 0,
        total_games,
        win_games,
        format_percent(win_rate),
        action_total_use,
        action_modify_use,
        format_percent(modify_percent),
        action_assist_use,
        format_percent(assist_percent),
        action_event_use,
        format_percent(event_percent)
        )
        --print(summary)

        progress.setVisibility(View.GONE)
       else
        print("返回数据为空")
      end
     else
      print("卡牌信息获取失败: " .. data.message)
    end
   else
    print("请检查网络重试")
  end
end)

function onCreateOptionsMenu(menu)
  menu.add("玩家信息")
  menu.add("说明")
end

function onOptionsItemSelected(item)
  local title = item.title
  if title == "说明" then
    utils.show_text_dialog([[名词解释及数据计算方式

角色牌熟练度：使用该角色获胜的场次
角色牌使用次数：无论胜负的出场次数
角色牌胜率：熟练度除以使用次数

获胜场次：全部角色牌熟练度求和除以3
游玩场次：全部角色牌使用次数求和除以3
胜率：获胜场次除以游玩场次
角色牌出场率：角色牌使用次数除以游玩场次

部分模式胜利后不会增加熟练度，只增加使用次数。角色牌仅有一种，行动牌包括三种（装备牌、支援牌、事件牌）。]])
   elseif title == "玩家信息" then
    if summary ~= "" then utils.show_text_dialog(summary).setTitle("玩家信息") end
  end
end

--[[local last = 0
function onKeyDown(code,event)
  if code == KeyEvent.KEYCODE_BACK then
    if last + 2 > os.time() then
      activity.finish()
     else
      print("再按一次返回键退出")
      last = os.time()
    end
    return true
  end
end]]

--[[

角色牌熟练度(使用该角色获胜的场次):proficiency
角色牌使用次数(无论胜负):use_count
熟练度除以使用次数得到角色牌胜率:win_rate
全角色proficiency求和再除以3得到总的获胜场次:proficiency_total
全角色use_count求和再除以3得到总的游玩场次:use_count_total
获胜场次除以游玩场次得到胜率:win_rate_total
角色牌使用次数除以总的游玩场次得到出场率:use_rate

角色牌仅有一种: CardTypeCharacter
行动牌包括三种:
 CardTypeModify: 装备牌
 CardTypeAssist: 支援牌
 CardTypeEvent: 事件牌

]]
