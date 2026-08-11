#!/bin/bash

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ WRT-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

sed -i 's/mirrors.vsean.net\/openwrt/mirror.nju.edu.cn\/immortalwrt/g' ./package/emortal/default-settings/files/99-default-settings-chinese
sed -i "s/DirectInterface/Interface/g" ./package/network/services/dropbear/files/dropbear.config

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

# ==========================================
# 修复 GL-AX1800 及其他 IPQ60xx 设备编译报错 (终极兜底方案)
# 原理：直接删除设备树中报错的 nvmem-cells 引用
# 说明：OpenWrt 会在系统启动时通过 /etc/board.d/02_network 脚本
# 自动从 Flash 读取并修正 MAC 地址。删除内核 DTS 中的引用
# 完全不影响最终的固件功能和网络正常使用。
# ==========================================
echo "Applying DTS hotfix for IPQ60xx MAC address errors..."

# 1. 找到并清理公共头文件 ipq6018-ess.dtsi 中的报错引用 (这是真正的报错源头)
find ./target/linux/qualcommax/ -type f -name "ipq6018-ess.dtsi" -exec sed -i '/nvmem-cells = <&macaddr/d' {} +
find ./target/linux/qualcommax/ -type f -name "ipq6018-ess.dtsi" -exec sed -i '/nvmem-cell-names = "mac-address"/d' {} +

# 2. 清理特定设备文件 ipq6000-gl-ax1800.dts 中的报错引用
find ./target/linux/qualcommax/ -type f -name "ipq6000-gl-ax1800.dts" -exec sed -i '/nvmem-cells = <&macaddr/d' {} +
find ./target/linux/qualcommax/ -type f -name "ipq6000-gl-ax1800.dts" -exec sed -i '/nvmem-cell-names = "mac-address"/d' {} +

# 3. 广撒网：清理 qualcommax 目录下所有 dts/dtsi 文件中残留的报错代码
find ./target/linux/qualcommax/ -type f \( -name "*.dts" -o -name "*.dtsi" \) -exec sed -i '/nvmem-cells = <&macaddr/d; /nvmem-cell-names = "mac-address"/d' {} +

echo "IPQ60xx DTS hotfix applied successfully!"
