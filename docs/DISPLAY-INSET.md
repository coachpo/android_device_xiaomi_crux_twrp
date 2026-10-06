# Crux 水滴屏顶部留白

2026-10-05 已部署的 [TWRP GitHub Release](RELEASE-DEPLOYMENT-2026-10-05.md)
包含顶部留白；2026-10-04 的 TWRP DT 启动修复仍有效。这些结果不认证 PE ROM。
`device/xiaomi/crux/BoardConfig.mk` 设置 `TW_Y_OFFSET := 80` 和
`TW_H_OFFSET := -80`，给顶部 80px 横向矩形留白；内容区域为 1080×2260，
底边仍为屏幕的 2340px。它利用 TWRP 内置主题缩放和 placement offset，
物理显示模式不需要调整。

Crux overlay 的 cutout path 高度为 75px，矩形近似与 portrait status bar
高度为 77px。80px 留白覆盖该设备描述并留 3px 余量。默认主题背景
`#1A1A1A`，所以留白为深灰；这是移开全部内容，不是只移动时钟。

[TeamWin 参数导出](https://raw.githubusercontent.com/TeamWin/android_vendor_twrp/android-12.1/config/BoardConfigSoong.mk)
经 [Soong 宏](https://raw.githubusercontent.com/TeamWin/android_vendor_twrp/android-12.1/build/soong/Android.bp)
传给 [主题布局实现](https://raw.githubusercontent.com/TeamWin/android_bootable_recovery/5c3d206a5eeb3d446bcda8248a405a4b278bab5c/gui/pages.cpp)。
绘制和点击区域共享同一套实际像素坐标，输入不可另加一层偏移。

以下是 2026-10-04 的可选 RAM 增强验证记录。当天完成 recovery 构建（04:52）和 ELF 常量核验；原 PE Image
及修正版 live DT 不变。生成 ramdisk 与已部署版相比，仅 recovery ELF
及两个生成的 ramdisk 清单内容改变。可选 FIT 43,234,732 bytes，仍为
`0x293c` 块。产物 SHA-256：
`f8a1dee97ba6ad09a5d3b9f840d80e56343a1f22120e415d0393b62ee039a023`。

实机已通过 RAM 临时启动：ADB 9.607 秒出现、8 核在线、recovery ELF
SHA-256 与构建一致；recovery.log 记录 `y: 80 h: -80`、height scale
`1.177083`。整区 cache SHA-256 保持已部署值
`9005ad062a3b81abb4a949bec86c43f5811e49e4eb019e2e82b812112bae9e47`。
该次验证时增强尚未持久化到 cache，重启回到当时的已部署布局。
后续 2026-10-05 Release 已包含相同 80px 配置并部署；本地 haptics RAM
版本的基本触摸已获用户接受，但完整顶部/底部布局、手势和键盘覆盖及
已安装 Release 的最终物理 UI 反馈仍未完成，不能把 offset 日志当作完整交互验收。

该配置针对当前内置竖屏主题。自定义 zip 主题在此 TWRP 版本会重置
默认偏移，需自行提供安全区；横屏不属于本轮要求。关闭增强时同时移除
两项 offset，避免仅改变位置导致底部内容裁切。

完整证据与 FIT 保存在工作区
`out/twrp-crux-top-inset-2026-10-04/` 及发起 Codex 任务的
`outputs/optional-display-inset/`。这些历史产物保留；当前已部署产物及验证边界见上述 Release 记录。
