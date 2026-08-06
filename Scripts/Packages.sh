#!/bin/bash

# ===== 修复 gettext-full 1.0 编译失败问题 (双保险) =====
echo "Checking gettext-full version..."
if [ -d "libs/gettext-full" ]; then
    if grep -q "PKG_VERSION:=1.0" libs/gettext-full/Makefile; then
        echo "Detected buggy gettext 1.0, reverting to stable 0.24.x..."
        rm -rf libs/gettext-full

        git clone --depth 1 --branch openwrt-24.10 --filter=blob:none --sparse https://github.com/openwrt/openwrt.git /tmp/openwrt-core
        cd /tmp/openwrt-core
        git sparse-checkout set package/libs/gettext-full

        cp -rf package/libs/gettext-full $GITHUB_WORKSPACE/wrt/package/libs/

        cd $GITHUB_WORKSPACE/wrt/package
        rm -rf /tmp/openwrt-core
        echo "gettext-full reverted successfully!"
    fi
fi
# =====================================================

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi

#删除官方的默认插件
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}

#复制本地自定义包（dae / luci-app-dae / v2ray-geodata）进入编译树
cp -r $GITHUB_WORKSPACE/package/v2ray-geodata ./
cp -r $GITHUB_WORKSPACE/package/dae ./
cp -r $GITHUB_WORKSPACE/package/luci-app-dae ./
echo "local packages copied: dae, luci-app-dae, v2ray-geodata"

#修复 dae/daed 相关文件（仅当目标文件存在时才执行，杜绝因文件缺失而中断）
for MK_FILE in luci-app-daed/daed/Makefile dae/Makefile luci-app-dae/Makefile; do
	if [ -f "$MK_FILE" ]; then
		sed -i 's/pnpm install ; /pnpm install --no-frozen-lockfile ; /g' "$MK_FILE"
		echo "fixed pnpm: $MK_FILE"
	fi
done

for INIT_FILE in $(find . -maxdepth 5 -type f -path "*root/etc/init.d/*dae*" 2>/dev/null); do
	if grep -q "/run/i  procd_set_param" "$INIT_FILE" 2>/dev/null; then
		sed -i 's|/run/i  procd_set_param|/procd_set_param command/i \tprocd_set_param|g' "$INIT_FILE"
		echo "fixed init: $INIT_FILE"
	fi
done

echo "Custom packages done!"
