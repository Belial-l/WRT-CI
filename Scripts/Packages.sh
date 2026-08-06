#!/bin/bash

# ===== 修复 gettext-full 1.0 编译失败（借同世代 0.24.2，杜绝版本代差） =====
echo "Checking gettext-full version..."
if [ -d "libs/gettext-full" ]; then
    if grep -q "PKG_VERSION:=1.0" libs/gettext-full/Makefile; then
        echo "Detected buggy gettext 1.0, restoring pre-bump 0.24.2 from same repo..."
        rm -rf libs/gettext-full

        # 从上游仓库的“升级前提交”精确提取 0.24.2 的 gettext-full（与主树 autotools 同世代）
        git clone --filter=blob:none --no-checkout https://github.com/VIKINGYFY/immortalwrt.git /tmp/openwrt-core
        cd /tmp/openwrt-core
        git checkout 45ae5043b752ec61b7c36b7443cc10aca721bd3a -- package/libs/gettext-full

        cp -rf package/libs/gettext-full $GITHUB_WORKSPACE/wrt/package/libs/

        cd $GITHUB_WORKSPACE/wrt/package
        rm -rf /tmp/openwrt-core
        echo "gettext-full restored to 0.24.2 (pre-bump) successfully!"
    fi
fi
# =====================================================================

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi

#清理官方 feeds 中可能冲突的代理/规则包，保持编译树干净
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}

echo "Environment cleaned. Ready for eBPF dependency build!"
