--卡面下载
require "utils"
import "api"
activity.setTitle("卡面下载")
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
          id = "monster_filter_container",
        },
        {
          ListView,
          layout_width = "fill",
          layout_height = "fill",
          fastScrollEnabled = true,
          id = "monster_list",
        },
      },
    }
  },
}))

local tab_info = {
  {title = "角色牌", id = 233},
  {title = "行动牌", id = 234},
  {title = "魔物牌", id = 235},
}
local action_bar = activity.getActionBar()
action_bar.setNavigationMode(ActionBar.NAVIGATION_MODE_TABS)
for k, v in ipairs(tab_info) do
  local tab = action_bar.newTab()
  tab.setText(v.title)
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

-- ch_ext 中的 filter 字段
local function parse_filter_from_ch_ext(ch_ext)
  if not ch_ext or ch_ext == "" then return {} end
  local ext = cjson.decode(ch_ext)
  for _, item in ipairs(ext) do
    if item.attribute_key == "filter" and item.value and item.value ~= "" then
      return cjson.decode(item.value)
    end
  end
  return {}
end

local function buildSpinnerFilter(listView, filterDef, cards, extKey, filterContainer)
  for _, card in ipairs(cards) do
    card.filter_array = {}
    if card.ext and card.ext ~= "" then
      local ext = cjson.decode(card.ext)
      local c = ext[extKey]
      if c and c.filter and c.filter.text then
        card.filter_array = cjson.decode(c.filter.text)
      end
    end
  end

  filterContainer.removeAllViews()
  filterContainer.setOrientation(LinearLayout.VERTICAL)

  local editText = EditText(activity)
  editText.setHint("搜索卡牌名称")
  editText.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
  filterContainer.addView(editText)

  local spinners = {}

  if #filterDef > 0 then
    local spinnerViews = {}
    for _, category in ipairs(filterDef) do
      local itemLayout = LinearLayout(activity)
      itemLayout.setOrientation(LinearLayout.HORIZONTAL)
      itemLayout.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1))
      itemLayout.setGravity(Gravity.CENTER_VERTICAL)

      local label = TextView(activity)
      label.setText(category.label)
      label.setTextSize(14)
      itemLayout.addView(label)

      local items = {"全部"}
      for _, child in ipairs(category.children or {}) do
        table.insert(items, child.label)
      end
      local spinner = Spinner(activity)
      spinner.setAdapter(ArrayAdapter(activity, android.R.layout.simple_spinner_item, items))

      local spinnerParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
      spinner.setLayoutParams(spinnerParams)
      itemLayout.addView(spinner)

      table.insert(spinnerViews, itemLayout)
      table.insert(spinners, {spinner = spinner, category = category.label, items = items})
    end

    for i = 1, #spinnerViews, 2 do
      local rowLayout = LinearLayout(activity)
      rowLayout.setOrientation(LinearLayout.HORIZONTAL)
      rowLayout.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
      rowLayout.setGravity(Gravity.CENTER_VERTICAL)

      rowLayout.addView(spinnerViews[i])
      if i + 1 <= #spinnerViews then
        rowLayout.addView(spinnerViews[i + 1])
       else
        local dummy = View(activity)
        dummy.setLayoutParams(LinearLayout.LayoutParams(0, 1, 1))
        rowLayout.addView(dummy)
      end
      filterContainer.addView(rowLayout)
    end
  end

  local adapter = ArrayAdapter(activity, android.R.layout.simple_list_item_1, {})
  listView.setAdapter(adapter)

  local displayedCards = {}

  local last = 0
  listView.setOnItemClickListener(AdapterView.OnItemClickListener({
    onItemClick = function(parent, view, position, id)
      local cur = os.time()
      if cur - last < 1 then
        return
      end
      last = cur
      
      local card = displayedCards[position + 1]
      if card and card.content_id then
        activity.newActivity("cover", {card.content_id})
      else
        print("卡牌数据异常")
      end
    end
  }))

  local function filterCards()
    local selected = {}
    for _, s in ipairs(spinners) do
      local pos = s.spinner.getSelectedItemPosition()
      if pos > 0 then
        local childLabel = s.items[pos + 1]
        local fullKey = s.category .. "/" .. childLabel
        table.insert(selected, fullKey)
      end
    end
    local keyword = editText.getText().toString():lower()
       
    displayedCards = {}
    for _, card in ipairs(cards) do
      local matchSpinner = true
      for _, key in ipairs(selected) do
        if not table.find(card.filter_array, key) then
          matchSpinner = false
          break
        end
      end
      local matchKeyword = (keyword == "" or card.title:lower():find(keyword, 1, true) ~= nil)
      if matchSpinner and matchKeyword then
        table.insert(displayedCards, card)
      end
    end
  
    adapter.clear()
    for _, card in ipairs(displayedCards) do
      adapter.add(card.title)
    end
    adapter.notifyDataSetChanged()
  end

  for _, s in ipairs(spinners) do
    s.spinner.setOnItemSelectedListener(AdapterView.OnItemSelectedListener({
      onItemSelected = function()
        filterCards()
      end
    }))
  end

  editText.addTextChangedListener({
    afterTextChanged = function()
      filterCards()
    end
  })

  filterCards()
end

Http.get(card_info_url, function(code, content)
  if code == 200 then
    local data = cjson.decode(content)
    if data.retcode == 0 then
      local list = data.data.list
      if list and #list > 0 then
        local root = list[1]
        local children = root.children or {}

        local function find_child(id)
          for _, child in ipairs(children) do
            if child.id == id then return child end
          end
          return nil
        end

        local char_child = find_child(233)
        local event_child = find_child(234)
        local monster_child = find_child(235)

        local char_filter = parse_filter_from_ch_ext(char_child and char_child.ch_ext)
        local event_filter = parse_filter_from_ch_ext(event_child and event_child.ch_ext)
        local monster_filter = parse_filter_from_ch_ext(monster_child and monster_child.ch_ext)

        local char_cards = char_child and char_child.list or {}
        local event_cards = event_child and event_child.list or {}
        local monster_cards = monster_child and monster_child.list or {}

        buildSpinnerFilter(char_list, char_filter, char_cards, "c_233", char_filter_container)
        buildSpinnerFilter(event_list, event_filter, event_cards, "c_234", event_filter_container)
        buildSpinnerFilter(monster_list, monster_filter, monster_cards, "c_235", monster_filter_container)

        progress.setVisibility(View.GONE)
       else
        print("返回数据格式异常")
      end
     else
      print("卡牌信息获取失败: " .. data.message)
    end
   else
    print("请检查网络重试")
  end
end)