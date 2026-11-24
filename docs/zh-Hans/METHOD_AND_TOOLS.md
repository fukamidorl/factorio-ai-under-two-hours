# 异星工厂的运行方法与所用工具

[给读者的 README](../../README.zh-Hans.md) · [AI 操作手册](AI_OPERATIONS.md) · [日本語](../ja/METHOD_AND_TOOLS.md) · [English](../en/METHOD_AND_TOOLS.md)

## 运行打包版

需要 64 位 Windows、已安装的**《异星工厂》2.1.25** 和 Python 3.11 或更高版本。验证时使用 Steam 版构建号 88022。若使用其他位置安装的 2.1.25，在检查和启动命令末尾追加 `--factorio "D:\Games\Factorio\bin\x64\factorio.exe"`。 [《异星工厂》官方历史版本](https://www.factorio.com/download/archive/2.1.25)

1. 解压发布 ZIP，在含有 `run_route.py` 的目录打开 PowerShell。运行 `check` 核对游戏版本与发布文件校验值。启动时，游戏根据 `world/map-gen-settings.json` 生成起始存档。
2. **想观看游戏画面**时用下方的 `visible`。若 Steam 要求确认自定义启动参数，核对配置、模组目录和存档都指向本次运行的 `runs/watch-01/`，然后选择继续。如果游戏已打开，请先保存需要保留的存档并关闭现有游戏窗口，再启动带画面的试跑。
3. 在游戏窗口观看采矿、发电和研究。刚开始是工程师视角，之后游戏内镜头会切换到工厂的各个区块。发布版的窗口语言和镜头标题默认为日文。火箭等速发射，胜利画面会显示结果。
4. **想无界面验证至到货**时用 `headless`。启动器通过 `--test-save` 运行游戏，检查卫星发射和 1,000 个太空科技包到货。PowerShell 命令完成后，可以用 `report` 读取结果。

~~~powershell
py -3 -X utf8 .\run_route.py check
py -3 -X utf8 .\run_route.py visible watch-01
py -3 -X utf8 .\run_route.py report watch-01
~~~

~~~powershell
py -3 -X utf8 .\run_route.py headless verify-01
py -3 -X utf8 .\run_route.py report verify-01
~~~

每次使用新的运行名称。带画面模式可以根据需要保存再关闭那个游戏窗口。要中断无界面模式，在 PowerShell 按 `Ctrl+C`，启动器将结束为该次试跑创建的进程。`report` 读取已保存的日志，因此中断后会显示最后记录到的阶段。有观众时保留胜利窗口，如需在带画面模式中观察到货，可从胜利窗口选择继续。游戏日志写入 `runs/<运行名称>/script-output/`。带画面模式还会将发射井和发射截图保存到这里。

## 自动发射火箭的专用模组

**`first-rocket-route-check` 0.1.0** 是为这个种子的卫星发射编写的 Lua 模组。启动器用基础游戏生成 `runs/<运行名称>/input-world.zip`，将生成日志写入 `world-generation.log`，并在 `run.json` 中记录存档的 SHA-256。随后将 `mod/` 中的专用模组复制到运行目录，按所选模式生成 `trial-policy.lua`。`design.lua` 保存坐标和研究顺序，`watch.lua` 控制游戏镜头。 [模组源码](../../mod/first-rocket-route-check_0.1.0/) · [启动器](../../run_route.py)

- **开场。** 开场阶段结束后，Lua 指示角色步行、挖掘和手工制造。燃烧采矿机、石炉和木材来自游戏给予的初始物品，施工消耗库存中的设备。
- **首次蒸汽发电之后。** Lua 将游戏采集或生产的物品及流体收集进脚本的库存表，直接供应熔炉、组装机、发电设备和研究中心。Lua 辅助部分跨区输送、施工和清理场地。模组消耗已制成的设备，检查碰撞后放置，并向研究队列加入项目。
- **发射。** 游戏引擎处理开采、冶炼、制造、发电和研究。Lua 将制成的卫星装入发射井，启用自动发射，并记录发射事件及物流接驳站到货。

与人工速通对照时，请注明 Lua 辅助施工、供料和游戏速度设置。

## 成就候选

以下是这条路线在《异星工厂》2.1.25 基础游戏中可以争取的主要成就。打包版的试跑日志记录了发射、产量和设备情况。 [2.1.25 的成就定义](https://github.com/wube/factorio-data/blob/2.1.25/base/prototypes/achievements.lua)

| 成就 | 条件 |
| --- | --- |
| 自动化生产！ | 放置一台组装机 1。 |
| 你不环保 | 完成基础原油处理研究。 |
| 规模量产 1 | 累计生产 10,000 块电路板。 |
| 出门一趟，等我回来！ | 向太空发射火箭。 |
| 无暇闲谈 | 在游戏内 15 小时内发射火箭。 |
| 拒绝加班 | 在游戏内 8 小时内发射火箭。 |
| 蒸蒸日上 | 在未放置太阳能板的情况下发射火箭。 |
| 枪林弹雨 | 在未放置激光炮塔的情况下发射火箭。 |

打包版的无画面试跑在自动操作开始后经过 1 小时 50 分 18 秒的游戏时间发射了火箭，共生产了 130,478 块电路板。全程放置的太阳能板和激光炮塔均为 0，制造卫星时用掉了 100 块太阳能板。 [打包版试跑记录](../../reference/package_verification.json)

**已在 Steam 上确认。**「拒绝加班」于 2026 年 11 月 22 日 21:02（日本时间）在旧种子 `210539101` 的修订试跑中解锁。当时在《异星工厂》2.1.24 基础游戏中，关闭专用模组并从胜利前的存档继续，在游戏内时间 5:49:24 获胜。Steam 页面还显示了当天解锁的其他相关成就。 [解锁时间与试跑记录](DEVELOPMENT_HISTORY.md)

按照游戏的默认规则，启用专用模组时，解锁的成就记入游戏内的模组成就列表。Steam 成就需要在无模组且成就有效的自由模式中满足条件。将敌人或污染设置调低至默认值以下会禁用部分限时或限制设备的成就。 [《异星工厂》Wiki 的成就规则](https://wiki.factorio.com/Achievements#Disabling_achievements)

发射后若还想解锁「查封物流网络」，请在全程未放置主动供货箱（紫箱）、主动存货箱（绿箱）和优先集货箱（蓝箱）的情况下，用送达的太空科技包完成一项研究。

## 开发与验证用过的工具

| 工具 | 使用场景 |
| --- | --- |
| ChatGPT Codex、GPT-6.2 Sol | 设计路线、实现、分析试跑以及编写文档。用户说明调试时交替使用超高（`xhigh`）与 Max（`max`）推理强度，最后阶段使用 Max。 |
| Computer Use | 查看 Windows 游戏画面，确认 Steam 启动对话框和带画面演示。铁板试验中需要长按以移动和挖掘时，使用了一个 Windows 输入辅助程序。 |
| Factorio LLM Use 0.1.1、`uv`、MCP、本地 RCON | 在《异星工厂》2.1.24 中做初次连接试验，采集铁矿石、冶炼并收取一块铁板，用于验证通用的游戏操作。 [Factorio LLM Use](https://github.com/Tsyklop/factorio-llm-use) |
| `visible-first-iron-demo` 0.1.0 | 2.1.24 的单块铁板带画面演示。将熔炉原料栏改为使用 `defines.inventory.crafter_input` 后，试跑在开始后的第 1,310 刻结束，确认角色背包有一块铁板、熔炉输出栏为零。 |
| `first-rocket-route-check` 0.1.0、Python、PowerShell | 当前路线从新地图运行到卫星发射。有画面时用游戏窗口，无画面时用游戏测试模式。此前的整合试跑将同一份存档接续到本地服务器，并在其中观测到货。 |
| 公开速通视频和存档、Python、Git | 对照人工速通的流程与产量、汇总日志、检查打包文件及生成 ZIP。 [开发时间线](DEVELOPMENT_HISTORY.md) |

复现只需已安装的游戏、Python 和打包文件。Computer Use 和 Factorio LLM Use 是开发、验证阶段所用的工具。

## 开发阶段的每周额度

根据用户的估计，在项目工作期间，**ChatGPT Pro 100** 的每周额度剩余显示由**约 100% 变成约 75%**。**约 25 个百分点**是界面显示的变化。确切观测时间、同一额度周期内的其他活动，以及项目独立的 token 数与费用均未记录。额度显示、游戏内计时和本地复现耗时使用不同的计量单位。 [环境与额度记录](../../reference/run_environment.json)

额度消耗随模型、推理强度、处理的上下文和工具使用而变化。这条观察只作为当时开发工作量的参考。 [OpenAI 的额度说明](https://learn.chatgpt.com/docs/pricing#usage-limits)
