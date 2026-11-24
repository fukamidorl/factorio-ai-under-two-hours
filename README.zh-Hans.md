# 如何让 AI 在 1 小时 40 分钟内通关《异星工厂》

[English](README.md) · [日本語](README.ja.md) · **简体中文**

**发布候选版 v0.2.0-rc.1** 在《异星工厂》2.1.25 的固定种子地图上，以专用 Lua 模组自动运行。游戏内 **1:34:05.300** 完成火箭升空，**1:34:14.783** 收到 1,000 个太空科技包。 [简体中文使用说明](replay-kit/README.zh-Hans.md)

## 初次发布版 v0.1.0

下文保留了初次发布时的路线、操作步骤和实测结果。

这套文件在《异星工厂》**2.1.25** 基础游戏中，使用种子 **4263722700** 从新地图建厂并发射卫星。仓库包含地图生成设置、负责施工和供料的 Lua 模组，以及支持观看游戏画面或无界面验证的启动器。

从路线设计、实现、试跑和验证到编写文档，**几乎全部工作由 ChatGPT 完成。** 用户设定了目标，提供参考速通记录和改进建议，并确认了最终发射。公开署名为 **Factory Launch Project**。

## 观看或复现

需要 Windows、《异星工厂》2.1.25 和 Python 3.11 或更高版本。请在此目录打开 PowerShell。启动器使用 Python 标准库。若 Steam 弹出自定义启动参数确认框，请核对参数里的路径属于本次运行目录，再选择继续。

~~~powershell
py -3 -X utf8 .\run_route.py check
py -3 -X utf8 .\run_route.py visible watch-01
py -3 -X utf8 .\run_route.py report watch-01
~~~

如需无界面验证发射及到货，将 `visible watch-01` 换成 `headless verify-01`。每次请使用新的运行名称。游戏安装在 Steam 默认位置以外时，给检查和启动命令追加 `--factorio "D:\Games\Factorio\bin\x64\factorio.exe"`。也可将 `py -3` 换成可用的 Python 可执行文件路径。

启动器使用本机安装的《异星工厂》为每次运行生成起始存档，然后启用随附模组 **`first-rocket-route-check` 0.1.0** 打开存档。若游戏已打开，请保存需要保留的进度并关闭现有窗口，再启动带画面的试跑。 [游戏的启动、观看与退出](docs/zh-Hans/METHOD_AND_TOOLS.md)

## 实测结果

| 运行方式 | 自动操作开始至发射 | 最后确认的状态 |
| --- | ---: | --- |
| 打包版，无界面 | **1:50:18** | 1:50:27 收到 1,000 个太空科技包 |
| 此前带画面的完整试跑 | **1:52:59** | 胜利画面显示 1:53:21，含开场阶段 |
| 此前的整合版，两次重复验证 | **1:49:38** | 第 65 分钟切换至本地服务器，1:49:47 到货，两次记录的 173 个事件刻一致 |

表中使用游戏内时间。此前的带画面完整试跑确认了发射和胜利画面，后续用早期打包版复查到蒸汽发电后的镜头切换。 [打包版验证记录](reference/package_verification.json) · [此前的试跑记录](reference/confirmed_runs.json)

存档始于角色创建之前。Lua 驱动移动、施工、研究队列及物品和流体调配，游戏引擎负责采矿、制造、发电、研究和发射。路线在 Codex 辅助下开发，计时期间由模组执行。

## 试跑环境

| 项目 | 配置 |
| --- | --- |
| 电脑 | Intel Core i5-12450H（8 核、12 线程）、16 GB 内存、约 512 GB 的 NVMe 固态硬盘 |
| 游戏画面渲染 | GeForce RTX 3050 Ti Laptop GPU（约 4 GB 独立显存，Direct3D 11）。机器也配有 Intel UHD Graphics。 |
| 操作系统 | Windows 11 Home 64 位（内部版本 26200） |
| 游戏 | Steam 版《异星工厂》2.1.25（构建号 88022），基础游戏，关闭 Space Age。公开版在本机使用 2.1.25 生成起始存档。 |
| 自动操作 | `first-rocket-route-check` 0.1.0，用 Python 3.12.16 验证启动器。 |

开发使用 **ChatGPT Codex 中的 GPT-6.2 Sol**。根据用户的说明，试跑调试时在**超高（`xhigh`）和 Max（`max`）**两档推理强度之间切换，最终阶段使用 **Max**。Codex 参与路线设计、实现和试跑分析，复现时由本地 Lua 模组操作游戏。

带画面模式的速度设置最高为 12 倍，发射时恢复正常速度。使用本机生成的地图时，上述电脑从游戏测试进程启动到完成实耗 **约 7 分 7 秒**。发射和到货发生的游戏刻与此前验证一致。 [环境记录](reference/run_environment.json) · [打包版验证与复查](reference/package_verification.json)

## 文档

- [开发时间线](docs/zh-Hans/DEVELOPMENT_HISTORY.md) · 从早期试跑到通关，沿时间顺序记录速通参考、用户反馈、瓶颈和改动。
- [AI 操作手册](docs/zh-Hans/AI_OPERATIONS.md) · 说明如何理解任务、观测进度、排查故障及判定成功。
- [所用工具与开发阶段的每周额度](docs/zh-Hans/METHOD_AND_TOOLS.md#开发与验证用过的工具) · 说明专用模组、Computer Use、早期 Factorio LLM Use 各自的用途，以及用户估计的 Pro 100 额度变化。
- [成就候选](docs/zh-Hans/METHOD_AND_TOOLS.md#成就候选) · 列出与火箭发射、用时和设备限制有关的成就，以及解锁 Steam 成就的条件。
- [发布准备](docs/zh-Hans/PUBLISHING.md) · 列出拟分发文件、计时表述、许可和起始存档的处理。

## 许可与再分发

项目原创代码、文档和设计数据采用 MIT 许可证。再分发时请保留版权声明和许可声明。《异星工厂》本体及素材的权利归 Wube Software Ltd. 所有。 [MIT 许可证](LICENSE) · [《异星工厂》服务条款](https://www.factorio.com/terms-of-service#intellectual-property-rights-and-sharing)

**再分发或发布改进版时，请更新试跑记录。** 如果进行计时，请附上发射的游戏内用时、游戏版本、种子、运行模式和主要改动。欢迎挑战 1 小时 50 分 18 秒的成绩。
