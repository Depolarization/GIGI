utils = require "utils"
import "api"
import "com.bumptech.glide.Glide"
activity.setTitle("卡面下载")
activity.setContentView(loadlayout({
  LinearLayout,
  layout_width = "fill",
  layout_height = "fill",
  orientation = "vertical",
  {
    TextView,
    textSize = "22sp",
    id = "card_name",
    layout_width = "fill",
    gravity = "center",
    layout_margin = "6dp",
  },
  {
    FrameLayout,
    layout_width = "fill",
    layout_height = "fill",
    layout_weight = 1,
    {
      ImageView,
      id = "card_image",
      layout_width = "fill",
      layout_height = "fill",
      scaleType = "fitCenter",
    },
    {
      ProgressBar,
      id = "image_progress",
      layout_gravity = "center",
    },
  },
  {
    RadioGroup,
    layout_width = "fill",
    layout_margin = "6dp",
    id = "radio_group",
    {
      RadioButton,
      text = "普通卡面(PNG)",
      layout_weight = "1",
    },
    {
      RadioButton,
      text = "动态卡面(GIF)",
      layout_weight = "1",
    },
  },
  {
    Button,
    text = "下载",
    id = "download_btn",
    layout_width = "fill",
  },
}))

local function download_file(url, name)
  local manager=activity.getSystemService(Context.DOWNLOAD_SERVICE)
  local request=DownloadManager.Request(Uri.parse(url))
  request.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_MOBILE|DownloadManager.Request.NETWORK_WIFI)
  request.setDestinationInExternalPublicDir("Download", name)
  request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
  manager.enqueue(request)
end

local cur_img_url, cur_img_name

local last = 0
download_btn.onClick = function()
  local cur = os.time()
  if cur - last < 1 then
    return
  end
  last = cur

  if cur_img_url and cur_img_name then
    download_file(cur_img_url, cur_img_name)
  end
end

local id = tonumber(...)
Http.get(string.format(card_detail_url, id), function(code, content)
  if code == 200 then
    local data = cjson.decode(content)
    if data.retcode == 0 then
      local basic_info
      for k, v in ipairs(data.data.page.modules) do
        if v.name == "基础信息" then
          basic_info = table.clone(cjson.decode(v.components[1].data))
          break
        end
      end
      if basic_info then
        card_name.setText(basic_info.name)
        radio_group.setOnCheckedChangeListener({
          onCheckedChanged=function(group, child)
            local idx = group.indexOfChild(group.findViewById(child))
            image_progress.setVisibility(View.VISIBLE)
            card_image.setVisibility(View.GONE)
            cur_img_name = string.format("%s.%s", basic_info.name, idx == 0 and "png" or "gif")
            cur_img_url = idx == 0 and basic_info.common_img or basic_info.gold_img
            Glide.with(this)
            .load(cur_img_url)
            .listener({
              onResourceReady=function()
                activity.runOnUiThread(function()
                  image_progress.setVisibility(View.GONE)
                  card_image.setVisibility(View.VISIBLE)
                end)
                return false
              end,
            })
            .into(card_image)
          end
        })
        radio_group.check(radio_group.getChildAt(0).getId())
       else
        print("获取数据失败")
      end
     else
      print("获取数据失败")
    end
   else
    print("请检查网络重试")
  end
end)

function onCreateOptionsMenu(menu)
  menu.add("下载管理")
  menu.add("说明")
end

function onOptionsItemSelected(item)
  local title = item.title
  if title == "下载管理" then
    local intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    activity.startActivity(intent)
   elseif title == "说明" then
    utils.show_text_dialog([[静态卡面为PNG格式，动态卡面为GIF格式。

卡面预览与下载独立，由于网络文件可能加载较慢，可在预览没有加载完成时直接下载。    
    
选中的卡面将下载到sdcard/Download目录，可在系统下载管理中查看该文件，文件名同卡牌名称，不同格式的同一卡面可以共存。

卡牌数据及卡面图片均来自米游社七圣Wiki。]])
  end
end