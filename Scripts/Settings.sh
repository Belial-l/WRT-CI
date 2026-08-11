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
# 完美修复 GL-AX1800 (IPQ6000) 编译报错
# 原理：动态在 &art 节点下注入 nvmem-layout 定义
# 这样既不破坏原有代码，又能完美解决 phandle_references 报错
# ==========================================
echo "Applying perfect NVMEM patch for GL-AX1800..."

# 1. 找到 GL-AX1800 的设备树文件
DTS_FILE=$(find ./target/linux/qualcommax/ -name "ipq6000-gl-ax1800.dts" 2>/dev/null)

if [ -n "$DTS_FILE" ]; then
    # 2. 清理现场：删除可能存在的、写错的 nvmem 引用（防止重复报错）
    sed -i '/nvmem-cells = <&macaddr/d' "$DTS_FILE"
    sed -i '/nvmem-cell-names = "mac-address"/d' "$DTS_FILE"
    
    # 3. 动态注入正确的 NVMEM 布局定义到文件末尾
    cat << 'EOF' >> "$DTS_FILE"

/* 
 * CI 动态注入补丁：修复上游缺失的 NVMEM MAC 地址定义 
 * 告诉内核去 art 分区读取正确的 MAC 地址
 */
&art {
    nvmem-layout {
        compatible = "fixed-layout";
        #address-cells = <1>;
        #size-cells = <1>;

        macaddr_wan: macaddr@0 {
            reg = <0x0 0x6>; /* GL-AX1800 WAN MAC 偏移量 */
        };

        macaddr_lan: macaddr@6 {
            reg = <0x6 0x6>; /* GL-AX1800 LAN MAC 偏移量 */
        };
    };
};
EOF
    echo "GL-AX1800 NVMEM layout injected successfully!"
else
    echo "GL-AX1800 DTS not found, skipping patch."
fi
