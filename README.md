# CachyOS & Linux AI Agent Environment Automated Setup
# cachyOSandAIagentSetup

一套面向 CachyOS (及 Arch/Debian/Ubuntu) 电脑的 **全自动、零冗余、防冲突** AI Agent 与开发环境自动化配置工程。

设计用于人类开发者与自主 Coding Agent（Pi、omp、OpenCode、Hermes、Claude）在新装电脑上一键运行。

---

## 核心设计原则

1. **单一真实可信源 (SSOT)**：所有 Skills 统一收敛至 `~/.agents/skills/`，各 Agent 目录只建立符号链接，彻底消除版本分化与冲突。
2. **严苛包隔离 (Strict Package Exclusions)**：引入 `mitsuhiko/agent-stuff` 与 `bestony/bestony-pi` 时严格剔除冗余冲突插件（如 `@narumitw/pi-goal`、`pi-web-access`、`pi-xai-oauth` 等）。
3. **原生 CLI 优先**：放弃繁重笨拙的 MCP Adapter 桥接层，全面采用高性能原生 CLI（`gh`、`vibeshell`、`loopx`、`agent-reach` 等）。
4. **多 Agent 终端解耦**：基于 `herdr` + `herd-dispatch` + `herdr-swarm` 实现多 Agent 窗格调度与状态同步。
5. **双层沙箱体系**：Bubblewrap 进程级安全放行沙箱 + Docker 容器化隔离沙箱。
6. **灵活多模型接入**：解耦硬编码，灵活支持直连 API Key（DeepSeek、Anthropic、OpenAI）与反代网关。

---

## 快速开始 (Quickstart)

在新装的电脑终端上运行：

```bash
git clone https://github.com/jssyxd/cachyOSandAIagentSetup.git ~/cachyOSandAIagentSetup
cd ~/cachyOSandAIagentSetup
chmod +x install.sh
./install.sh
```

---

## 安装阶段编排 (Phases)

| 阶段 | 脚本 | 内容概述 |
| :--- | :--- | :--- |
| **Phase 0** | `00_base_system.sh` | 系统更新、base-devel、git、bwrap、中文输入法 (fcitx5)、yay、Chrome |
| **Phase 1** | `01_runtimes_cli.sh` | Node.js LTS (v22)、Bun、Astral uv & uvx、GitHub CLI (`gh`) |
| **Phase 2** | `02_sandbox_docker.sh` | Docker 与 Compose 服务、Bubblewrap (`bwrap.json` 及放行规则) |
| **Phase 3** | `03_install_agents.sh` | 核心 Coding Agent：Pi (`@earendil-works/pi-coding-agent`)、omp、OpenCode |
| **Phase 4** | `04_browser_computer_use.sh` | Browser-Use (Python CLI + Pi CDP) 与 Computer-Use Linux 驱动 |
| **Phase 5** | `05_skills_ssot.sh` | 全局技能库 SSOT：`agent-reach`, `vibeshell`, `loopx`, `herdr-skills` |
| **Phase 6** | `06_packages_config.sh` | 严格去重配置包集成、Pi `settings.json` 与代理设置 |
| **Phase 7** | `07_herdr_setup.sh` | Herdr 多 Agent 终端编排器与状态集成同步 |
| **Phase 8** | `08_models_config.sh` | 模型配置文件模板初始化 (支持自定义 Provider/Key) |
| **Phase 9** | `09_sync_skills.sh` | 自动化将 SSOT 技能软链接分发至所有 Agent 目录 |

---

## 验收与自检 (Verification)

运行内置测试脚本检验全部工具链与技能链接：

```bash
./verify.sh
```
