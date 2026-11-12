# MIUI / HyperOS OTA Block

通过 hosts 阻断小米系统更新的检查接口，让「检查更新」直接失败。
**不卸载、不停用、不改任何系统应用状态**，删除模块即完全恢复。

---

## 为什么做这个

GitHub 上现有的几个方案都有明显问题（均经解包审查）：

| 项目 | 问题 |
|---|---|
| `spoliator/xiaomi-ota-update-blocker` | 2022 年停更；hosts 里**没有** `update.miui.com`，只有国际版域名，国行无效；还顺带屏蔽了 `firebaseinstallations.googleapis.com`，影响其他应用推送 |
| `manhgdev/Block-OTA-Update` | 代码质量好，但 Intent Firewall 规则写死 Google GMS，对小米无效；其 smart scan 会按包名猜测目标 |
| `CxZMoE/system_update_blocker` | 方向正确（一行 hosts），但 2023 年停更、无说明、无卸载脚本 |

本项目的取舍：**只做最少的事，并且把每一处改动都写在 README 里让使用者自己判断。**

---

## 它做了什么

模块全部内容：

```
module.prop                          元数据
post-fs-data.sh                      开机时把模块内的 hosts 绑定到 /system/etc/hosts
system/etc/hosts                     实际生效的 hosts
META-INF/com/google/android/...      Magisk 安装入口（官方模板）
```

`system/etc/hosts` 全文：

```
127.0.0.1 localhost
::1 localhost
127.0.0.1 update.miui.com
127.0.0.1 update.intl.miui.com
```

就这些。**没有 `service.sh`，没有 `uninstall.sh`，不执行任何 `pm` / `cmd package` 命令**，`com.android.updater` 的安装状态和启用状态完全不变。

---

## 兼容性

**系统版本**

| 系统 | 是否适用 |
|---|---|
| MIUI 13 / 14 | ✅ |
| HyperOS 1 / 2 / 3 | ✅ |
| MIUI 12 及更早 | ✅（本模块不卸载，仅断网，因此不受该版本卸载卡米问题影响） |
| 国际版 / 欧洲版 ROM | ✅（已覆盖 `update.intl.miui.com`） |

**Root 方案**

| 方案 | 状态 | 说明 |
|---|---|---|
| Magisk | ✅ 已实测 | 见下方实测记录 |
| KernelSU | ⚠️ 需元模块 | 新版 KernelSU 把 `system/` 挂载交给元模块，未装 `meta-overlayfs` 时该目录不会自动挂载；`post-fs-data.sh` 会正常执行并可 bind mount 兜底，但**未实机验证** |
| APatch | ⚠️ 未实测 | 机制与 KernelSU 接近，建议同样先装元模块 |

---

## 实测记录

| 项目 | 值 |
|---|---|
| 机型 | Redmi Note 12T Pro |
| 系统 | MIUI 14.0.5 |
| Root 方案 | Magisk |

结果：

- 打开「设置 → 我的设备 → 系统更新」，页面提示**「请联网后检查更新」**
- 未再收到系统更新通知
- 更新应用本体与设置入口仍然存在，仅无法连接服务器

> 副作用：「检查更新」会持续失败，表现为网络故障。这是预期行为。

---

## 安装

1. 设备已 root（Magisk / KernelSU / APatch 任一）。
2. 在 root 管理器里选择「从本地安装」，选中 release 中的 zip。
3. 重启。

> **重要**：安装前请确认没有其他 hosts 类模块在运行——包括 Magisk 设置里的「Systemless hosts」开关、AdAway、以及其他 hosts 模块。多个 hosts 挂载会互相覆盖，这是本方案唯一确定会踩的坑。

---

## 验证

装完重启后，务必执行：

```sh
su -c ping -c 1 update.miui.com
su -c cat /system/etc/hosts
```

- 第一条应解析到 `127.0.0.1`
- 第二条应能看到模块写入的两行
- 然后进「设置 → 我的设备 → 系统更新 → 检查更新」，应提示失败或长时间无响应

三步都通过才算生效。若 `ping` 仍解析到真实 IP，说明挂载没成功，见下方 FAQ。

---

## 卸载

在 root 管理器里删除模块 → 重启。hosts 立即还原，无残留。

需要恢复更新时，删掉模块重启，再正常检查即可。

---

## 原理与边界

小米的更新检查走单一接口 `https://update.miui.com/updates/miotaV3.php`，下载走 `bigota.d.miui.com` / `ultimateota.d.miui.com`。阻断检查接口即可让「检查 → 决定下载 → 下载 → 安装」在第一步断掉。

Android 的域名解析由 `netd` 处理，顺序是**先查 hosts，再走 DNS**。`com.android.updater` 是系统应用，使用系统解析器，因此 hosts 对其有效；私人 DNS 不影响这个顺序。

**本项目不承诺永久有效。** 各论断的置信度：

| 论断 | 置信度 | 说明 |
|---|---|---|
| `update.miui.com` 是国行更新检查接口 | 高 | 2026 年仍活跃的开源项目在调用 |
| 阻断后「检查更新」失败 | 高 | 接口单一，机制明确 |
| 国际版接口为 `update.intl.miui.com` | 中 | 见于 2022 年的模块，缺近期一手证据，需实测 |
| 不存在备用域名或 IP 直连 | 低 | 无反证，也无法证明不存在 |
| 长期有效 | 低 | 厂商可随时更换接口 |

详见 [`docs/核实报告.md`](docs/核实报告.md)。

---

## FAQ

**Q：装完 `ping` 还是真实 IP？**
说明 hosts 没挂上。先检查是否与其他 hosts 模块冲突；也可手动执行：

```sh
su -c mount -o bind /data/adb/modules/miui_ota_hosts_block/system/etc/hosts /system/etc/hosts
```

**Q：更新入口消失了 / 点进去空白，正常吗？**
正常。检查接口不通，页面拿不到数据。

**Q：会不会卡米？**
不会。本模块不改变任何包的状态，也不写系统分区，只挂载一个 hosts 文件。卡米的成因是系统组件缺失，本模块不制造这种条件。

**Q：为什么屏蔽两个域名，不是只屏蔽国行那个？**
为了兼容刷了国际版 / 欧洲版 ROM 的设备。多写一条对国行无副作用。

**Q：为什么不把 `bigota.d.miui.com` 也屏蔽？**
该域名同时服务主题商店和部分系统资源，一并屏蔽会导致主题、壁纸下载异常。阻断检查接口已足够。

---

## 项目结构

给不熟悉 Android 模块的读者：

- `module.prop` — 模块的身份证。root 管理器靠它识别名字、版本、作者。
- `system/etc/hosts` — 模块要"覆盖"到系统里的文件。这里放什么，开机后 `/system/etc/hosts` 就是什么。
- `post-fs-data.sh` — 开机早期执行的脚本，把上面的文件绑定到系统路径。不同 root 管理器对单文件挂载的处理不一致，显式绑定更可靠。
- `META-INF/...` — 安装入口。Magisk 通过它调用安装逻辑，内容就是官方模板，没有自定义代码。
- `.github/workflows/release.yml` — 自动打包发布的 GitHub Actions 配置。

---

## 免责声明

屏蔽系统更新意味着不再接收安全补丁，长期使用可能使部分银行、政务类应用因系统版本过旧而拒绝运行。是否使用、如何使用，由使用者自行判断并承担后果。本项目仅修改 hosts 文件，不涉及系统分区与其他系统组件。

## License

[MIT](LICENSE)
