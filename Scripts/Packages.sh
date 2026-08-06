#!/bin/bash

# ===== 修复 gettext-full 1.0 编译失败问题 (双保险) =====
echo "Checking gettext-full version..."
if [ -d "libs/gettext-full" ]; then
    if grep -q "PKG_VERSION:=1.0" libs/gettext-full/Makefile; then
        echo "Detected buggy gettext 1.0, reverting to stable 0.24.x..."
        rm -rf libs/gettext-full
        
        # 从 OpenWrt 官方 24.10 稳定分支拉取 gettext
        git clone --depth 1 --branch openwrt-24.10 --filter=blob:none --sparse https://github.com/openwrt/openwrt.git /tmp/openwrt-core
        cd /tmp/openwrt-core
        git sparse-checkout set package/libs/gettext-full
        
        # 覆盖到当前源码树
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

cp -r $GITHUB_WORKSPACE/package/v2ray-geodata ./
#修复daed/Makefile
sed -i 's/pnpm install ; /pnpm install --no-frozen-lockfile ; /g' luci-app-daed/daed/Makefile
sed -i 's|/run/i  procd_set_param|/procd_set_param command/i \tprocd_set_param|g' luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed
