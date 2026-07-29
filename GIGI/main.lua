local utils = require "utils"
import "api"

--[[]
activity.newActivity("rank")
activity.finish()
if true then return true end
--]]
--print(utils.generate_code(299989984))

activity.setContentView(loadlayout({
  LinearLayout,
  orientation = "vertical",
  layout_width = "fill",
  layout_height = "fill",
  {
    LinearLayout,
    layout_width = "fill",
    gravity = "center",
    id = "info_root",
    {
      ImageView,
      id = "avatar",
      layout_height = "64dp",
      layout_width = "64dp",
      layout_margin = "16dp",
    },
    {
      LinearLayout,
      orientation = "vertical",
      layout_width = "fill",
      layout_weight = 1,
      gravity = "center|left",
      {
        TextView,
        textSize = "22sp",
        id = "username",
      },
      {
        TextView,
        textSize = "14sp",
        textColor = Color.GRAY,
        id = "info",
      },
    },
  },
  {
    ListView,
    layout_width = "fill",
    layout_height = "fill",
    id = "list_view",
  },
}))

local item = {
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
      layout_width = "fill",
      textSize = "16sp",
      id = "username",
    },
    {
      TextView,
      layout_width = "fill",
      textSize = "12sp",
      textColor = Color.GRAY,
      id = "info",
    },
  },
  {
    LinearLayout,
    orientation = "vertical",
    layout_width = "fill",
    layout_height = "fill",
    layout_weight = 1,
    layout_margin = "8dp",
    gravity = "center|right",
    {
      TextView,
      textSize = "12sp",
      id = "ladder",
    },
    {
      TextView,
      textSize = "12sp",
      id = "peak",
    },
  },
  {
    TextView,
    textSize = "26sp",
    layout_margin = "8dp",
    id = "status",
  },
}

-- 本地储存的用户信息形如 {{uid=12345, cookie="xxx"}, ...}

local uids = {}
local cur_uid_idx = activity.getSharedData("cur_uid_idx") or 1
local uid_info = load(string.format("return %s", activity.getSharedData("uid_info")))() or {}
local cur_info = uid_info[cur_uid_idx] or {}
local cur_uid = cur_info.uid
local cur_cookie = cur_info.cookie

local function copy(text)
  activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(tostring(text))
end

local adapter = LuaAdapter(activity, item)
list_view.setAdapter(adapter)

local function login()
  activity.newActivity("login")
  activity.finish()
end

local function show_game_records(records)
  Http.get(homepage_url, cur_cookie, nil, nil, function(code, content)
    if code == 200 then
      local data = cjson.decode(content)
      if data.retcode == 0 then -- 展示数据
        local page_info = data.data.page_info
        username.setText(page_info.nickname)
        avatar.setImageBitmap(loadbitmap(page_info.avatar_url))
        local tier, stars = utils.get_tier_stars(page_info.ladder_score)
        info.setText(string.format("UID:%s\t\t\t段位:%s\n天梯积分:%d\t\t\t\t巅峰积分:%d",
        cur_uid, string.format("%s%s", tier, string.rep("★", stars)),
        page_info.ladder_score, page_info.peak_score))

        -- cookie有效性续费
        local cookie = CookieManager.getInstance().getCookie(homepage_url)
        uid_info[cur_uid_idx].cookie = cookie
        activity.setSharedData("uid_info", dump(uid_info))
       else
        view.setEnabled(true)
        print("UID获取失败")
      end
    end
  end)
  for k, v in ipairs(records) do
    local status_text_color = Color.GRAY
    local status_text = "空"
    local first, second = string.match(v.trans_no, "([^_]+)_([^_]+)")
    local uid = "unknown"
    if first and second then -- 不再根据胜负判断对方UID，直接把两个UID提取出来，不是用户的那个UID就是对手的
      uid = first == cur_uid and second or first
    end
    if v.result == "Lose" then
      status_text_color = Color.RED
      status_text = "负"
      --uid = first
     elseif v.result == "Win" then
      status_text_color = Color.GREEN
      status_text = "胜"
      --uid = second
    end
    local t = os.date("*t", v.timestamp)
    local date_str = string.format("%d-%d\t%d:%d",
    t.month, t.day, t.hour, t.min)
    local ladder_score = v.ladder_score.score
    local ladder_score_change = v.ladder_score.score_change
    local peak_score = v.peak_score.score
    local peak_score_change = v.peak_score.score_change
    local peak_score_text = (peak_score == 0 and peak_score_change == 0) and "巅峰\t-" or string.format("巅峰\t%d\t(%d)", peak_score, peak_score_change)
    adapter.add({
      username = v.nickname,
      avatar = {
        imageBitmap = loadbitmap(v.avatar_url), -- 不使用 src = "xx" 加载网络图片，有概率加载不出来
      },
      status = {
        textColor = status_text_color,
        text = status_text,
      },
      info = string.format("UID:%s\n%s", uid, date_str),
      ladder = string.format("天梯\t%d\t(%d)", ladder_score, ladder_score_change),
      peak = peak_score_text,
    })
    table.insert(uids, uid)
  end
end

local function show_query_dialog(uid)
  local uid = tonumber(uid)
  local code = utils.generate_code(uid, 7)
  Http.get(string.format(other_homepage_url, code, cur_uid), cur_cookie, nil, nil, function(code, content)
    if code == 200 then
      local data = cjson.decode(content)
      if data.retcode == 0 then
        local page_info = data.data.page_info
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

        local dialog = utils.show_text_dialog(string.format("昵称\t:\t%s\nUID\t:\t%d\n段位\t:\t%s\n天梯积分\t:\t%d\n巅峰积分\t:\t%d\n展示角色\t:\t%s\n参赛经历\t:\t%s",
        page_info.nickname, uid, string.format("%s%s", tier, string.rep("★", stars)),
        page_info.ladder_score, page_info.peak_score, roles_info_str, entry_experience_str))
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

-- 降低服务器压力
local last = 0
local function is_clickable()
  local now = os.time()
  if now - last < 1 then
    return false
  end
  last = now
  return true
end

info_root.onClick = function()
  if is_clickable() then
    show_query_dialog(cur_uid)
  end
end

list_view.onItemClick = function(parent, v, pos, id)
  if is_clickable() then
    show_query_dialog(uids[pos + 1])
  end
end

local function update_game_records(uid)
  Http.get(string.format(game_records_url, uid), cur_cookie, nil, nil, function(code, content)
    if code == 200 then
      local data = cjson.decode(content)
      if data.retcode == 0 then -- 展示数据
        show_game_records(data.data.game_records)
       else -- 登录已经失效，要求用户重新登录
        login()
      end
     else
      print("请检查网络重试")
    end
  end)
end

if cur_uid then
  update_game_records(cur_uid)
 else
  login()
end

function onCreateOptionsMenu(menu)
  menu.add("卡牌使用详情")
  menu.add("积分排行榜")
  menu.add("玩家查询")
  menu.add("用户管理")
  menu.add("卡面下载")
  menu.add("说明")
  menu.add("刷新")
end

function onOptionsItemSelected(item)
  local title = item.title
  if title == "玩家查询" then
    local dialog = AlertDialog.Builder(this)
    .setTitle("玩家查询")
    .setView(loadlayout({
      LinearLayout,
      layout_width="fill",
      {
        EditText,
        hint="输入玩家UID",
        layout_margin="16dp",
        layout_width="fill",
        inputType="number",
        id="uid_input",
      },
    }))
    .setPositiveButton("查询", nil)
    .setNegativeButton("取消", nil)
    .create()
    dialog.setOnShowListener(DialogInterface.OnShowListener({
      onShow=function()
        dialog.getButton(AlertDialog.BUTTON_POSITIVE).onClick=function()
          local text = uid_input.getText().toString()
          if text:len() == 9 then
            show_query_dialog(text)
            dialog.dismiss()
           else
            print("UID不符合格式")
          end
        end
      end
    }))
    dialog.show()
   elseif title == "卡牌使用详情" then
    activity.newActivity("game")
   elseif title == "积分排行榜" then
    activity.newActivity("rank")
   elseif title == "用户管理" then
    activity.newActivity("user")
   elseif title == "卡面下载" then
    activity.newActivity("cards")
   elseif title == "说明" then
    local dialog = AlertDialog.Builder(this)
    utils.show_text_dialog([[本软件（GIGI，Genshin Impact Genius Invokation TCG Tool）为免费开源项目，仅供学习交流使用。
    
首次使用时，您需要登录七圣赛事官网，登录一次后，只要不清除软件数据，通常无需重复登录。成功登录后，点击屏幕下方的确认按钮，软件便会记录您的信息并同步最近的对局数据。若登录环节出现异常，请及时反馈。

与抽卡记录类似，新对局数据的获取存在一定延迟，如果未能即时获取到最新记录，请稍后重试。如急着更新数据，请小退原神（即返回开门的界面)，再次进门，可加快数据更新速度。

首页的对局查询功能最多可查看最近十局的对局详情，单击列表中的任一项目即可查看对手信息。

此外，您也可以在右上角的玩家查询功能中手动输入UID，查询该玩家的七圣相关信息。鉴于赛事已经关停，无法确保赛事信息部分长期有效。

若在使用中遇到任何异常错误，欢迎随时反馈。

软件内此类说明对话框的消息均可长按复制。

所有信息均来自七圣赛事和米游社。最早借助七圣赛事官网查询对手信息的原理见
https://www.bilibili.com/video/BV1boF5z6E9G

致谢开源
1.https://github.com/piovium/scoreboard-bot-server
2.https://gist.github.com/guyutongxue/239d246a68ce71fcb3f83be82e277a61
3.https://github.com/nirenr/AndroLua_pro
4.https://gitee.com/huangshx2001/call_of_seven_saints
5.https://github.com/bumptech/glide

作者@Dexphase。反馈请联系
https://space.bilibili.com/560719483]]
    ).setNeutralButton("反馈", function()
      local intent = Intent("android.intent.action.VIEW", Uri.parse("https://space.bilibili.com/560719483"))
      activity.startActivity(intent)
    end)
   elseif title == "刷新" then
    activity.recreate()
  end
end

function onResume()
  local idx = activity.getSharedData("cur_uid_idx")
  if cur_uid_idx ~= idx then
    activity.recreate()
  end
end