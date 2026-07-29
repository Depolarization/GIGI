--登录
local utils = require "utils"
import "api"

activity.setTitle("登录")
activity.getActionBar().setSubtitle("登录后，点击网页下方的保存按钮！")
activity.setContentView(loadlayout({
  LinearLayout,
  orientation = "vertical",
  layout_width = "fill",
  layout_height = "fill",
  gravity = "center|bottom",
  id = "login_root",
  {
    LuaWebView,
    id = "web_view",
    layout_width = "fill",
    layout_height = "fill",
    layout_weight = 1,
    visibility = View.GONE,
  },
  {
    Button,
    id = "login_btn",
    textSize = "18sp",
    layout_height = "56dp",
    layout_width = "fill",
    text = "登录成功后，点此保存！",
  },
}))

local cur_uid_idx = activity.getSharedData("cur_uid_idx")
local uid_info = load(string.format("return %s", activity.getSharedData("uid_info")))() or {}
local has_logged_out = false
local settings = web_view.getSettings()
settings.setUserAgentString("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
settings.setJavaScriptEnabled(true)
settings.setDomStorageEnabled(true)
web_view.setWebViewClient({
  onPageFinished=function(view, url)
    if has_logged_out then return end
    web_view.postDelayed(Runnable({
      run = function()
        -- 基于模拟点击的自动登出
        local js = [[
            (function() {
                var target = document.querySelector('span.mihoyo-account-role__logout-txt');
                if (target) {
                    target.click();
                   
                    var evt = new MouseEvent('click', {
                        view: window,
                        bubbles: true,
                        cancelable: true
                    });
                    target.dispatchEvent(evt);
                    
                    return true;
                } else {                
                    var spans = document.querySelectorAll('span');
                    for (var i = 0; i < spans.length; i++) {
                        if (spans[i].innerText.trim() === '注销') {
                            spans[i].click();
                            return true;
                        }
                    }
                    return false;
                }
            })();
        ]]
        web_view.evaluateJavascript(js, ValueCallback({
          onReceiveValue = function(result)
            if result and result == "true" then -- 返回string
              has_logged_out = true
            end
            web_view.setVisibility(View.VISIBLE)
          end
        }))
      end
    }), 500)
  end
})

web_view.loadUrl(login_url)

login_btn.onClick=function(view)
  view.setEnabled(false)
  local cookie = CookieManager.getInstance().getCookie(login_url)
  Http.get(user_info_url, cookie, nil, nil, function(code, content)
    if code == 200 then
      local data = cjson.decode(content)
      if data.retcode == 0 then -- 展示数据
        local uid = data.data.game_uid
        local existed_key
        for k, v in ipairs(uid_info) do
          if v.uid == uid then
            existed_key = k
            break
          end
        end
        if existed_key then -- 如果已经登录又重复登录，就切换到这个账号，同时保存最新的cookie，防止账号登录状态失效导致的重新登录
          uid_info[existed_key].cookie = cookie
          activity.setSharedData("uid_info", dump(uid_info))
          activity.setSharedData("cur_uid_idx", existed_key)          
         else
          table.insert(uid_info, {uid = uid, cookie = cookie})
          activity.setSharedData("uid_info", dump(uid_info))
          activity.setSharedData("cur_uid_idx", #uid_info)
        end
        activity.newActivity("main")
        activity.finish()
       else
        view.setEnabled(true)
        print("获取失败，请确保已成功登录")
      end
     else
      print("请检查网络重试")
    end
  end)
end

local function show_dialog()
  utils.show_text_dialog([[首次使用必须登录一个账号，请手动登录七圣赛事官网。
  
确定登录成功后，点击屏幕下方的确认按钮，将自动跳转页面并同步最近的对局数据。

添加新账号时，软件会尝试自动登出原有账号，如果没有生效，请手动退登旧账号，再登录新账号。

如果登录环节出现异常，请及时反馈。

作者@Dexphase，反馈请联系https://space.bilibili.com/560719483]]
  )
end

function onCreateOptionsMenu(menu)
  menu.add("刷新")
  menu.add("说明")
  menu.add("退出")
end

function onOptionsItemSelected(item)
  local title = item.title
  if title == "退出" then
    activity.finish()
   elseif title == "刷新" then
    web_view.reload()
   elseif title == "说明" then
    show_dialog()
  end
end

local dialog_has_shown = activity.getSharedData("dialog_has_shown")
if not dialog_has_shown then
  show_dialog()
  activity.setSharedData("dialog_has_shown", true)
end

local last = 0
function onKeyDown(code, event)
  if code == KeyEvent.KEYCODE_BACK then
    if web_view.canGoBack() then
      web_view.goBack()
      return true
    end
    if last + 2 > os.time() then
      activity.finish()
     else
      print("再按一次返回键退出页面")
      last = os.time()
    end
    return true
  end
end
