
#!/bin/bash

# 安装额外依赖软件包
# sudo -E apt-get -y install rename

# 更新feeds文件
# sed -i 's@#src-git helloworld@src-git helloworld@g' feeds.conf.default # 启用helloworld
# sed -i 's@src-git luci@# src-git luci@g' feeds.conf.default # 禁用18.06Luci
# sed -i 's@## src-git luci@src-git luci@g' feeds.conf.default # 启用23.05Luci
cat feeds.conf.default

# 添加自用插件
git clone https://github.com/nihaoya9527/OpenWrt_Build_x64_Packages package/nihaoya9527-packages

# 更新并安装源
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a -f

# 删除部分默认包
rm -rf feeds/luci/applications/luci-app-qbittorrent
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/themes/luci-theme-argon

# 自定义定制选项
NET="package/base-files/luci2/bin/config_generate"
ZZZ="package/lean/default-settings/files/zzz-default-settings"
# 读取内核版本
KERNEL_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_PATCHVER | sed 's/^.\{17\}//g')
KERNEL_TESTING_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_TESTING_PATCHVER | sed 's/^.\{25\}//g')
if [[ $KERNEL_TESTING_PATCHVER > $KERNEL_PATCHVER ]]; then
  sed -i "s/$KERNEL_PATCHVER/$KERNEL_TESTING_PATCHVER/g" target/linux/x86/Makefile        # 修改内核版本为最新
  echo "内核版本已更新为 $KERNEL_TESTING_PATCHVER"
else
  echo "内核版本不需要更新"
fi

#
sed -i 's#192.168.1.1#192.168.1.11#g' $NET                                               # 定制默认IP
sed -i 's#LEDE#OpenWrt-GXNAS#g' $NET                                                     # 修改默认名称为OpenWrt-X86
sed -i 's@.*CYXluq4wUazHjmCDBCqXF*@#&@g' $ZZZ                                            # 取消系统默认密码
sed -i "s/LEDE /GXNAS build $(TZ=UTC-8 date "+%Y.%m.%d") @ LEDE /g" $ZZZ                   # 增加自己个性名称
# sed -i "/uci commit luci/i\uci set luci.main.mediaurlbase=/luci-static/neobird" $ZZZ        # 设置默认主题(如果编译可会自动修改默认主题的，有可能会失效)
sed -i 's#localtime  = os.date()#localtime  = os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")#g' package/lean/autocore/files/*/index.htm               # 修改默认时间格式

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #
sed -i 's#%D %V, %C#%D %V, %C Lean_x86_64#g' package/base-files/files/etc/banner               # 自定义banner显示
# sed -i 's@list listen_https@# list listen_https@g' package/network/services/uhttpd/files/uhttpd.config               # 停止监听443端口
# sed -i 's#option commit_interval 24h#option commit_interval 10m#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计写入为10分钟
# sed -i 's#option database_generations 10#option database_generations 3#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据周期
# sed -i 's#option database_directory /var/lib/nlbwmon#option database_directory /etc/config/nlbwmon_data#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据存放默认位置
sed -i 's#interval: 5#interval: 1#g' feeds/luci/applications/luci-app-wrtbwmon/htdocs/luci-static/wrtbwmon/wrtbwmon.js               # wrtbwmon默认刷新时间更改为1秒
sed -i '/exit 0/i\ethtool -s eth0 speed 10000 duplex full' package/base-files/files//etc/rc.local               # 强制显示2500M和全双工（默认PVE下VirtIO不识别）

# ●●●●●●●●●●●●●●●●●●●●●●●●定制部分●●●●●●●●●●●●●●●●●●●●●●●● #

cat >> $ZZZ <<-EOF
# 设置旁路由模式
uci set network.lan.gateway='192.168.1.1'                    # 旁路由设置 IPv4 网关
uci set network.lan.dns='223.5.5.5 114.114.114.114'          # 旁路由设置 DNS(多个DNS要用空格分开)
uci set dhcp.lan.ignore='1'                                  # 旁路由关闭DHCP功能
uci delete network.lan.type                                  # 旁路由桥接模式-禁用
uci set network.lan.delegate='0'                             # 去掉LAN口使用内置的 IPv6 管理(若用IPV6请把'0'改'1')
uci set dhcp.@dnsmasq[0].filter_aaaa='0'                     # 禁止解析 IPv6 DNS记录(若用IPV6请把'1'改'0')

# 旁路IPV6需要全部禁用
uci set network.lan.ip6assign=''                             # IPV6分配长度-禁用
uci set dhcp.lan.ra=''                                       # 路由通告服务-禁用
uci set dhcp.lan.dhcpv6=''                                   # DHCPv6 服务-禁用
uci set dhcp.lan.ra_management=''                            # DHCPv6 模式-禁用

# 如果有用IPV6的话,可以使用以下命令创建IPV6客户端(LAN口)（去掉全部代码uci前面#号生效）
uci set network.ipv6=interface
uci set network.ipv6.proto='dhcpv6'
uci set network.ipv6.ifname='@lan'
uci set network.ipv6.reqaddress='try'
uci set network.ipv6.reqprefix='auto'
uci set firewall.@zone[0].network='lan ipv6'

EOF

# 修改退出命令到最后
sed -i '/exit 0/d' $ZZZ && echo "exit 0" >> $ZZZ

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #


# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #
# 下载 OpenClash 内核
grep "CONFIG_PACKAGE_luci-app-openclash=y" $WORKPATH/$CUSTOM_SH >/dev/null
if [ $? -eq 0 ]; then
  echo "正在执行：为OpenClash下载内核"
  mkdir -p $HOME/clash-core
  mkdir -p $HOME/files/etc/openclash/core
  cd $HOME/clash-core

# 下载Meta内核
  wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz
  if [[ $? -ne 0 ]];then
    wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz
  else
    echo "OpenClash Meta内核压缩包下载成功，开始解压文件"
  fi
  tar -zxvf clash-linux-amd64.tar.gz
  if [[ -f "$HOME/clash-core/clash" ]]; then
    mv -f $HOME/clash-core/clash $HOME/files/etc/openclash/core/clash_meta
    chmod +x $HOME/files/etc/openclash/core/clash_meta
    echo "OpenClash Meta内核配置成功"
  else
    echo "OpenClash Meta内核配置失败"
  fi
  rm -rf $HOME/clash-core/clash-linux-amd64.tar.gz

  rm -rf $HOME/clash-core
fi

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #

