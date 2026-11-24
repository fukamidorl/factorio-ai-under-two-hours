# GitHub 发布准备

[给读者的 README](../../README.zh-Hans.md) · [AI 操作手册](AI_OPERATIONS.md) · [日本語](../ja/PUBLISHING.md) · [English](../en/PUBLISHING.md)

## 发布信息

| 项目 | 内容 |
| --- | --- |
| 标题 | 如何让 AI 在两小时内通关《异星工厂》 |
| 公开署名 | Factory Launch Project |
| GitHub 仓库名 | `factorio-ai-under-two-hours` |
| 许可证 | [MIT](../../LICENSE)，适用于原创代码、文档和设计数据 |

## GitHub 简介

> 复现 AI 为《异星工厂》2.1.25 基础游戏编排的自动流程，在游戏内 1:50:18 发射卫星。几乎全部工作由 ChatGPT 完成。

## 发布说明

> 这套 Lua 模组和 Windows 启动器可在《异星工厂》2.1.25 基础游戏中，从固定种子 4263722700 的新地图自动发射卫星。几乎全部工作由 ChatGPT 完成。用户设定了目标，提供了参考速通记录和改进建议，并确认了最终发射。无界面试跑在游戏内 1:50:18 发射，并确认 1,000 个太空科技包到货。再分发或发布改进版时，请更新试跑记录。

## 仓库内容

| 路径 | 内容 |
| --- | --- |
| `README*.md`、`AGENTS.md`、`docs/` | 人类读者和 AI 的入口、开发时间线和发布准备，提供简体中文、日文和英文。 |
| `run_route.py`、`mod/`、`manifest.json` | 已验证的启动器、项目 Lua 代码、布局、研究顺序、运行条件及 SHA-256。Git 属性让 Windows 检出时保持受校验文件的字节内容。 |
| `world/` | 地图生成设置。本机安装的 2.1.25 根据这些设置在运行目录中生成创建角色前的自由模式存档。 |
| `reference/` | 已摘录的关键事件和验证条件，涵盖之前的试跑、打包版无界面全程以及带画面启动测试。 |

公开 ZIP 包含整理后的源码和文档。游戏本体和场景素材来自使用者本机的安装。运行生成的 `runs/`、原始日志、个人设置及存档均保存在本机。速通资料通过开发时间线中的链接指向原出处。 [《异星工厂》服务条款](https://www.factorio.com/terms-of-service#intellectual-property-rights-and-sharing)

## 公开署名和邮箱

仓库网址会显示所有者的用户名或组织名，请使用适合公开展示的 GitHub 命名空间。公开 ZIP 是不含提交历史的源码压缩包。创建公开提交时，在该仓库使用 GitHub 提供的 `noreply` 邮箱，并同时检查作者和提交者的邮件字段。GitHub 还提供邮箱隐私设置，以及阻止命令行推送暴露个人邮箱的功能。 [设置提交邮箱](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address) · [阻止暴露个人邮箱的推送](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/blocking-command-line-pushes-that-expose-your-personal-email-address)

## 再分发与更新记录

再分发 MIT 许可的材料时，请保留版权声明和许可声明。发布改进版时，也欢迎更新试跑记录。如果进行了计时，请附上游戏内发射用时、游戏版本、种子、运行模式和主要改动。无界面的对照时间是 `1:50:18`，此前的带画面演示在 `1:52:59` 发射。 [许可证](../../LICENSE) · [实测记录](../../reference/package_verification.json)

将发布 ZIP 解压到新目录后运行 `check`，核对游戏版本与文件校验值。随每个版本记录用于验证的标签或提交。报告问题时请附上版本、模式、`check` 和 `report` 的结果、问题开始的阶段与事件刻，以及去除个人信息后的日志片段。 [GitHub Releases 说明](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
