# 需要  bg.png    DS配置   app文件 放在同一路径下
# 默认  需要打包app名:testDisk.app         弹出名:UCDisk
#      临时dmg名:temp.dmg                 生成dmg名:UCDisk.dmg
#      背景图名：bg.png
#
# ===========start=============
hdiutil detach /Volumes/testApp
rm -f *.dmg

hdiutil create -srcfolder testDisk.app -volname UCDisk -format UDRW -size 100MB -ov -attach temp.dmg

rm -f /Volumes/UCDisk/.bg.*
cp ./bg.png /Volumes/UCDisk/.bg.png
rm -f /Volumes/UCDisk/Applications
ln -s /Applications /Volumes/UCDisk/Applications

#
cp ./bg.png /Volumes/UCDisk/.bg.png
#
ln -s /Applications /Volumes/UCDisk/Applications
#
cp ./DS_Store.bak /Volumes/UCDisk/.DS_Store
#
#
sync
#
sync
#
hdiutil detach /Volumes/UCDisk
#
hdiutil convert temp.dmg -format UDZO -o UCDisk.dmg -ov
#
rm -f temp.dmg
#end