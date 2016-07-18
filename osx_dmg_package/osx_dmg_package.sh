set -e

title='千尋影視' # dmg 文件 mount 了之后在文件系统中显示的名称
background_picture_name='mac-dmg-bg.png' # dmg 文件在 mount 了之后界面中显示的背景图片路径
application_name='千尋影視.app' # 应用程序的名称
# Developer ID 证书的名称（名字的一部分即可，但是需要能在 Keychain Access 中唯一定位到该证书）
developer_id='Developer ID Application: Shanghai Truecolor Multimedia'

# dmg 窗口相关的一些设置，需要根据实际情况做变更
window_left=200 # 窗口位置的 x 坐标
window_top=100  # 窗口位置的 y 坐标
app_icon_width=128  # 应用的 logo 大小
app_icon_left=150   # 应用的 logo 在窗口中的 x 坐标
app_icon_top=200    # 应用的 logo 在窗口中的 y 坐标
applications_link_left=450 # Application 文件链接在窗口中的 x 坐标
applications_link_top=200  # Application 文件链接在窗口中的 y 坐标




# 获取到项目名称，如果自动获取的项目名称不正确，可以手动进行指定
cd $(dirname $0)
project_name=`find . -name *.xcodeproj | tail -n 1 | grep -oE '\./[^\.]+' | grep -oE '[^\./]+$'`
# 后续需要根据 target 的名称查找最新的打包文件路径
project_target_name=$project_name
# 后续需要从 info 文件中获取到版本号信息
project_plist_filepath="./${project_name}/${project_name}-Info.plist"
# 在这个目录下面查找 archive 包
archive_path=~/Library/Developer/Xcode/Archives




mkdir -p dmg-releases
rm -f dmg-releases/pack.temp.dmg
# 创建一个临时的可读可写 dmg 文件，如果程序大小超过 100M，就需要调整这个参数
hdiutil create -size 100M -volname "${title}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" dmg-releases/pack.temp.dmg




function ejectDmgMount() {
  # 弹出临时的 dmg mount
  echo '
     tell application "Finder"
       tell disk "'${title}'"
             open
             delay 2
             eject
             delay 2
       end tell
     end tell
  ' | osascript
}
# 如果有 mount 了其他的 dmg 文件在 Finder 里面了，先弹出掉
if [ -d /Volumes/${title} ]; then
  ejectDmgMount
fi
hdiutil mount dmg-releases/pack.temp.dmg



# 查找 archive 包
latest_archive_path=`find ~/Library/Developer/Xcode/Archives -name "${project_target_name} *.xcarchive" | tail -n 1`
echo path of archive found is: $latest_archive_path

# 获取应用程序的包名
app_folder_name=`ls "$latest_archive_path/Products/Applications" | head -n 1`
echo executable app folder name is: $app_folder_name


if ! [ -d /Volumes/${title} ]; then
  echo -e "\033[31m"
  echo "ERROR: /Volumes/${title} holder volume not mounted!"
  echo "You need to mount ${title} holder by hand before run this command."
  echo -e "\033[39m"
  exit 1
elif ! [ -w /Volumes/${title} ]; then
  echo -e "\033[31m"
  echo "ERROR: /Volumes/${title} is not writable!"
  echo -e "\033[39m"
  exit 1
fi

# 获取到背景图片的大小，dmg mount 之后的窗口大小设定为背景图片的大小
image_width=`sips -g pixelWidth ${background_picture_name} | tail -n 1 | grep -oE '[0-9]+$'`
image_height=`sips -g pixelHeight ${background_picture_name} | tail -n 1 | grep -oE '[0-9]+$'`


# 复制编译好的app目录
rm -rf /Volumes/${title}/$app_folder_name
cp -R "$latest_archive_path/Products/Applications/$app_folder_name" /Volumes/${title}/$app_folder_name
echo 1kxun &gt; "/Volumes/${title}/$app_folder_name/Contents/Resources/configuration_source.txt"
echo "app copied is: $latest_archive_path/Products/Applications/$app_folder_name"


rm -f /Volumes/${title}/.background/*
mkdir -p /Volumes/${title}/.background
cp ./${background_picture_name} /Volumes/${title}/.background/bg.png
rm -f /Volumes/${title}/Applications
ln -s /Applications /Volumes/${title}/Applications


# 获取到当前配置的版本号信息
plist_content=`cat "$project_plist_filepath" | tr "\n" " "` # 去除掉plist文件里面的换行符，以方便提取版本号
version=`echo $plist_content | grep -oE 'CFBundleShortVersionString[^&lt;]*[0-9\.]+' | grep -oE '[0-9\.]+'`

# 设置背景图片等信息
function setDmgFinderInfo() {
  window_right=$(($image_width+$window_left))
  window_bottom=$(($image_height+$window_top))
  echo '
     tell application "Finder"
       tell disk "'${title}'"
             open
             set current view of container window to icon view
             set toolbar visible of container window to false
             set statusbar visible of container window to false
             set the bounds of container window to {'$window_left', '$window_top', '$window_right', '$window_bottom'}
             set theViewOptions to the icon view options of container window
             set arrangement of theViewOptions to not arranged
             set icon size of theViewOptions to '$app_icon_width'
             set background picture of theViewOptions to file ".background:bg.png"
             set position of item "'${application_name}'" of container window to {'$app_icon_left', '$app_icon_top'}
             set position of item "Applications" of container window to {'$applications_link_left', '$applications_link_top'}
             update without registering applications
             close
       end tell
     end tell
  ' | osascript
}


# 打包某一个渠道的 dmg 版本
function buildDmgForChannel() {
  local channel=$1
  
  # mount 临时的 dmg 文件
  if [ -d /Volumes/${title} ]; then
    ejectDmgMount
  fi
  hdiutil mount dmg-releases/pack.temp.dmg
  
  # 变更渠道标识文件，我们是使用一个文本文件做的记录，这样分渠道打包时，不需要重新编译
  echo $channel &gt; "/Volumes/${title}/${app_folder_name}/Contents/Resources/configuration_source.txt"

  # 执行 Developer ID code sign
  echo ""
  echo ""
  echo "About to set Deveopler ID code sign of the application"
  codesign --force --verbose --all-architectures --deep -s "$developer_id" "/Volumes/${title}/$app_folder_name"
  
  setDmgFinderInfo
  ejectDmgMount
  
  # 导出只读的 dmg 文件
  today=`date '+%Y-%m-%d.%H'`
  hdiutil convert ./dmg-releases/pack.temp.dmg -format UDZO -imagekey zlib-level=9 \
  -o "./dmg-releases/${project_name}-${version}-${channel}-${today}.dmg"
}


buildDmgForChannel 1kxun
# buildDmgForChannel app01
# 要增加一个渠道就在这里增加一行函数调用就可以了

rm -f ./dmg-releases/pack.temp.dmg
