# Antigravity 反代网关 · 接入与运维指引

> 覆盖 **oh-my-pi (omp)**、**pi coding agent**、**opencode**、**hermes** 接入自建反代网关（CLIProxyAPI + Cloudflare WARP 出口）。
> 服务器：malaysia `155.254.60.38`（韩国服务器已永久退役）。
> 面向 **人类**（照抄命令）与 **Agent**（§7 可整段复制的任务书）。
> 最近更新：**2026-10-06** · 服务器当日被**重装**，已按 **§2.14** 一键重建并验收；含**出口方案完整实验与落地**（WARP）、**429/配额根因**、**磁盘事故处置（§2.12）**、**换机/重装重建（§2.13–2.14）**、**与 X 原帖方案对照（§11）**。所有数据均为实机实测。
> 本次变更清单见 **§0.1**。

---

## 0. 当前状态（已可用 ✅）

> **2026-09-27 重装重建**：服务器被重装（原 `/opt/cpa`、WARP、haproxy 全丢），已按 §2.14 重建至可用。korea（`168.93.224.18`）仍退役。**客户端 baseUrl 不变**：`http://155.254.60.38/v1`。

| 项 | 状态 |
|---|---|
| **主网关** | ✅ `http://155.254.60.38/v1`（malaysia；**原生二进制 + systemd 直听 :80**，无 Caddy/无 docker），12 个模型，CLIProxyAPI **v7.3.13** |
| **多协议** | ✅ 一个端口三套 API：`/v1/chat/completions`（OpenAI）、`/v1/messages`（Anthropic → 可接 Claude Code）、`/v1/responses`（OpenAI Responses）。2026-09-27 三者实测均 200（见 §5.3） |
| **出口** | ✅ **2 条 Cloudflare WARP 出口 + haproxy 聚合**：`warp-proxy@{1,2}.service`（SOCKS5 `127.0.0.1:1081`、`:1082`）→ haproxy（`127.0.0.1:1080`）→ 网关 `proxy-url`。出口落 **Cloudflare（MY）**，`hosting:false` |
| **出口自愈** | ✅ **已恢复**：`warp-watchdog.timer`（每分钟端到端探测 → 直接驱动 haproxy 运行态：通→`ready`，连续 2 轮失败→`maint` 摘除并重启隧道、等 22s 复测；全挂则 fail-open 兜底）+ `/usr/local/bin/hap-api.py` + `/run/haproxy/admin.sock`，带 `flock` 防定时器/手动并发。**已按"端口活着但隧道已死"做过演练**（§2.5） |
| **磁盘/内存自愈** | ✅ `cpa-diskguard.timer`（每 5 分钟；`/` >85% 清日志/转储/journal）＋ **`cpa-memguard.timer`（每 2 分钟；RSS >600MB 重启网关）**；网关另有 `MemoryHigh=480M / MemoryMax=680M` drop-in |
| **账号池运维** | `/root/cpa/account.sh`（`add` / `list` / `enable` / `disable` / **`key`**）＋ **`/root/cpa/import-cards.sh`**（批量卡密导入 + 逐个定向验证 + 失败自动 `disable`，已用合成卡密跑通）；网关 8 秒热加载；待验证账号链接在 `/root/cpa/verify-urls.txt` |
| **管理密钥** | ✅ 2026-09-27 **已轮换**：32 位随机密钥存 `/root/cpa/mgmt.key`（600），`account.sh key` 可打印；旧口令 `admin` 已失效（实测 401） |
| **Web 面板** | ✅ **CPA-Manager-Plus v1.14.1**（原生二进制，`cpa-manager-plus.service`，无 docker）→ `http://155.254.60.38:18317/management.html`；已完成首配（`configured:true / setupRequired:false`），面板侧可读到全部账号；面板 Admin Key 存 `/root/cpamp-admin.key`（600，`/setup` 一次的凭据） |
| 账号池现状 | **10 个（2026-10-07 更新）**：**8 个正常轮询 + 2 个已 disable**（`katesmith3181`、`jamesthompson5969` 的 RT 已作废）。新增号 `ashleevc70cswanson` 导入前已直连 Google 验 RT = LIVE，导入后实测 3/3 请求 200 |
| Gemini 系 | ✅ 可用（`gemini-3.8-flash-high` 连打 12/12 全 200，工具调用正常） |
| Claude / GPT-OSS | ✅ **4.6 系可用**（`claude-sonnet-4-6`、`claude-opus-4-6-thinking`、`gpt-oss-120b-medium` 实测可达）。⚠️ **5.5 系在本池返回 404**（原因见 §0.2）。⚠️ 4.6 系官方 **2026-11-02 下线**，到期须迁移 |
| **负载均衡（2026-09-27 起）** | `routing.session-affinity: false` —— **按请求轮询**；实测 12 次请求在 2 个健康号上 **6:6**。代价与切换见 §2.6「粘滞 vs 轮询」 |
| **默认模型（2026-10-06 修订）** | **omp / pi / opencode → `antigravity/claude-sonnet-4-6`（默认，思考档由 `defaultThinkingLevel: medium` 全局控制）；用量耗尽自动 fallback 至 `gemini-3.8-flash-high:medium`**；**hermes → `antigravity/gemini-3.8-flash-high`**（不设 thinking，直接走 Gemini 池）|
| 上下文窗口（防配额打爆） | omp `models.yml` 保持 1M **但压缩阈值写死 20 万**（`settings.json.compaction.thresholdTokens`）；pi/opencode 的 gemini 系**声明窗口已从 1M 降到 25 万**，强制在 ~21 万自动压缩（实测长会话 443K→245K、403K→68.5K） |
| 网关自带 UI | 另有一套网关**原生** `management.html`（`http://155.254.60.38/management.html`，用 CPA 管理密钥登录）：轻量、只连本机网关，与上面独立的 CPA-Manager-Plus 面板互补 |
| **一键排障** | `bash /root/cpa/account.sh list`（账号）；`systemctl list-timers 'cpa-*' 'warp-watchdog.timer'`；`journalctl -u cli-proxy-api -t warp-watchdog -t cpa-diskguard -t cpa-memguard`；面板 `http://155.254.60.38:18317/management.html`；密钥 `account.sh key` / `/root/cpamp-admin.key` |

**一句话**：Gemini 之前不是"被地区限制不能用"，而是**出口 IP 被 Google 判定为不受支持**；换成 Cloudflare WARP 出口后全通。**容量不足（429）的唯一解是加号**；而**账号被判"需要验证"（403 `VALIDATION_REQUIRED`）只能在浏览器里人工走一遍验证**，服务器侧无解（§2.14 末）。

### 0.1 变更日志（Changelog）

| 日期 | 事件 |
|---|---|
| 2026-09-23 | omp 通道治理（402 / `Unable to connect`）：`modelRoles` 显式化 + `retry.fallbackChains`（§3.2、§10） |
| **2026-09-27** | **服务器被重装**（CPA/WARP/haproxy 全丢）→ 按 §2.14 重建并验收；新增 `cpa-memguard`；`session-affinity` 改为 `false`（按请求负载均衡）；两个账号被 Google 判需验证并停用；确认网关三套 API（OpenAI / Anthropic / Responses）均可用 |
| **2026-09-27（加固轮）** | ① 管理密钥轮换为 32 位随机（`/root/cpa/mgmt.key`，旧 `admin` 失效）；② 重建**出口自愈** `warp-watchdog` + `hap-api.py` + haproxy admin socket，并做了"端口活/隧道死"演练；③ 部署 **CPA-Manager-Plus v1.14.1** 面板（:18317）并完成首配；④ 新增 **`import-cards.sh`** 批量卡密导入器（含定向验证与失败自动 disable），已用合成卡密跑通 |
| **2026-10-06** | ① 账号池 6 → **9 个**（新增 `lindasimmons2532` / `katesmith3181` / `jamesthompson5969`）；② `max-retry-credentials` 由 `0` 改为 **`5`**；③ omp / pi / opencode 默认模型统一为 Claude 系（用量耗尽自动 fallback 至 `gemini-3.8-flash-high:medium`），hermes 保持 `gemini-3.8-flash-high` |
| **2026-10-06（修订）** | ① **Claude 5.5 系实测 404** → 全客户端默认回退 **Claude 4.6**（见 §0.2）；② RT 权威审计：9 号中 **7 live / 2 dead**，死号已 `disable`（见 §12.4）；③ 新增 `/root/rt_audit.py` 一键 RT 体检 |
| **2026-10-07** | 新增账号 **`ashleevc70cswanson@gmail.com`**（池 9 → **10**）。按新流程**先验 RT 再导入**：直连 Google 换取 access_token 成功（LIVE，无轮换）→ `account.sh add` → 网关热加载 → 冒烟 3/3 返回 200 |

### 0.2 Claude 5.5 系为什么返回 404（2026-10-06 实测）

官方可用性矩阵（<https://antigravity.google/docs/models>）：

| 模型 | Free / AI Plus | Google AI Pro | Google AI Ultra | Enterprise |
|---|---|---|---|---|
| Claude Sonnet 5.5 / Opus 5.5 | ❌ | ✅\*\* | ✅ | ❌ |
| Claude Sonnet 4.6 / Opus 4.6 | ✅ | ✅ | ❌ | ❌ |

> \*\* **Available on Google AI Pro for non-trial subscriptions only** —— 本池的号是 **Pro 试用**，因此 5.5 系对它们**不可用**。

实测（同一网关、逐个模型）：

```
claude-sonnet-5-5-high    404 Requested entity was not found.
claude-opus-5-5-high      404 Requested entity was not found.
claude-sonnet-4-6         429（模型存在，仅额度问题）
claude-opus-4-6-thinking  429（模型存在，仅额度问题）
gemini-3.8-flash-high     429 / 200
```

**判据**：**404 = 该账号没有这个模型**（订阅层级问题，与额度无关）；**429 = 模型存在但额度耗尽**。
⇒ 看到 404 不要去查额度，先查订阅层级。

⚠️ **4.6 系官方标注 2026-11-02 下线**。到期前二选一：① 把号升级为**非试用** Google AI Pro 以解锁 5.5；② 全量切到 `gemini-3.8-flash-high`。

---

## 1. 网关事实（malaysia）

| 项 | 值 |
|---|---|
| 模型 API | `http://155.254.60.38/v1`（**直接 :80**，无 Caddy 中转） |
| 管理 API | `http://127.0.0.1/v0/management/auth-files`、`/config`、`/usage`（`Authorization: Bearer <密钥>`）。密钥在 `/root/cpa/mgmt.key`（600），`/root/cpa/account.sh key` 可打印；**2026-09-27 已从 `admin` 轮换为 32 位随机值**。端口 80 对外，故管理 API 也从公网可达（见 §11.2 风险项） |
| 鉴权 | 无（`api-keys` 为空，任意字符串当 key 都行） |
| 部署目录（服务器） | `/opt/cpa/`：`cli-proxy-api`（二进制）、`config.yaml`、`auths/`、`logs/` |
| 凭据文件 | `/opt/cpa/auths/antigravity-<email>.json`（`{type,email,refresh_token,disabled}` 最小格式即可） |
| 组件版本 | CLIProxyAPI **v7.3.13**（commit `24303543`，2026-09-22 构建）· wireproxy **1.0.9** · wgcf **2.3.0** · haproxy **2.6.12**。⚠️ 上游已有 **v8.0.2**，但它会**迁移配置**（"preserve unknown legacy sections as comments"）→ 我们的 `session-affinity` / `oauth-request-scoped-errors` 等键存在被降级成注释的风险，故**有意留在 7.3.13**；要升级先备份并在测试机验证迁移结果 |
| systemd 单元 | 网关 `cli-proxy-api.service` · 出口 `warp-proxy@1.service`、`warp-proxy@2.service` · LB `haproxy` · 面板 `cpa-manager-plus.service` · 定时器 `cpa-diskguard.timer`（5min）、`cpa-memguard.timer`（2min）、`warp-watchdog.timer`（1min）（**全部 enabled，重启自启**） |
| 运维脚本 | `/root/cpa/account.sh`（账号池 + `key`）、`/root/cpa/import-cards.sh`（批量卡密）、`/root/cpa/mgmt.key`（网关管理密钥）、`/root/cpamp-admin.key`（面板 Admin Key）、`/root/cpa/verify-urls.txt`（待验证账号链接）、`/usr/local/bin/{cpa-diskguard,cpa-memguard,warp-watchdog}.sh`、`/usr/local/bin/hap-api.py` |
| WARP 出口 | `/root/warp/profiles/{1,2}/wireproxy.conf` + `/root/warp/wireproxy`；wgcf 在 `/root/wgcf`（注册产物 `/root/warp-reg/`）；haproxy 配置 `/etc/haproxy/haproxy.cfg` |
| Web 面板 | **两套并存**：① 网关自带 `management.html`（`/opt/cpa/static/`，`http://155.254.60.38/management.html`，用 CPA 管理密钥）；② **CPA-Manager-Plus v1.14.1**（`/opt/cpamp/`，`http://155.254.60.38:18317/management.html`，独立 Admin Key + 已完成首配）。②的用法见 **§12** |
| 面板进程 | `cpa-manager-plus.service` → `ExecStart=/opt/cpamp/cpa-manager-plus`，`WorkingDirectory=/opt/cpamp`（数据在 `/opt/cpamp/data/`，含加密用的 `data.key`），`MemoryHigh=300M / MemoryMax=500M` |

### 模型清单与可用性

| 模型 ID | 类别 | 额度池 | 现在 |
|---|---|---|---|
| `gemini-3.8-flash-high` | Gemini | Gemini 池 | ✅ 主力（1M 上下文、文本/图片/工具） |
| `gemini-3.7-flash-high` / `gemini-3.6-flash-high` | Gemini | Gemini 池 | ✅ |
| `gemini-3-flash` / `gemini-3.1-flash-lite` | Gemini | Gemini 池 | ✅ |
| `gemini-3.1-pro-low` / `gemini-pro-agent` | Gemini | Gemini 池 | ✅ |
| `gemini-3.1-flash-image` | Gemini | Gemini 池 | 生图，未接客户端 |
| `claude-sonnet-4-6` | 第三方 | Claude/GPT 池 | ✅ **omp / pi / opencode 默认主力**；用量耗尽 fallback 至 Gemini。官方 2026-11-02 下线 |
| `claude-opus-4-6-thinking` | 第三方 | Claude/GPT 池 | ✅ 可用，omp `slow` 角色。官方 2026-11-02 下线 |
| `gpt-oss-120b-medium` | 第三方 | Claude/GPT 池 | ✅ 实测 200 |

> 官方依据：Antigravity 面板把额度分成 **"Gemini Models"** 与 **"Claude and GPT models"** 两条独立额度条（各含周额度 + 5 小时窗口）——这就是"Gemini 额度远大于 Claude"的出处。
> <https://antigravity.google/docs/models> · <https://antigravity.google/docs/plans>

---

## 2. 出口（Egress）——本方案的核心，已解决

### 2.1 机制

Gemini 请求走 Google 的 Cloud Code 模型 API（日志实测：`https://daily-cloudcode-pa.googleapis.com/v1internal:generateContent`），该端点在**每次请求**上评估**发起方 IP 的地区/信誉**，不满足即返回：

```json
{"error":{"code":400,"message":"User location is not supported for the API use.","status":"FAILED_PRECONDITION"}}
```

**判的是 IP，不是国家**：马来西亚都在官方支持国家列表内，但机房 IP 段照样被打回（CLIProxyAPI PR #4000 原话：*"keyed on the request's egress IP/region … commonly affects datacenter/hosting IPs even when they geolocate to a supported country. Antigravity Claude/Codex are unaffected."*）。

网关侧三个嫌疑已排除（读服务器错误日志 + 实测）：端点就是官方域名（非 sandbox）、流式/非流式一样被拒、请求体与 token 正常（同 token 换出口即通）。

### 2.2 实测数据（同一账号、同一 token、同一网关，只换出口）

| 出口 | IP 类型 | Gemini 结果 |
|---|---|---|

| malaysia 原生 `155.254.60.38`（SSH 隧道） | `hosting:false` 但 ASN=Evoxt（机房） | 首轮 11/12 → 半小时 ~50% → 一小时 1/12 → 0/6 → **静置后在 1/6~4/6 波动**（限流而非永久封禁） |
| 中国电信家宽 `61.170.216.52`（NAS, Shanghai） | `hosting:false`，真家宽 | 直连 Google **不通**（GFW）；**其 mihomo 的香港节点出站 → Gemini 400**（HK 不在支持列表，链已确认）；WireGuard UDP 2408 被阻断 → WARP 无法在该机运行 |


**关键结论**：唯一稳定通过的是 **WARP**；机房直连（无论韩国/马来西亚/香港）都会被拒或限流；香港节点虽"住宅"，但国别不在支持列表 → 400。

### 2.3 出口方案现状

| 方案 | 状态 | 说明 |
|---|---|---|
| 住宅/移动代理 | 备用 | 按 IP 月付、不限流量最佳；最稳但需付费 |
| 日本/新加坡原生线路 VPS | 备用 | 若用，**必须先跑 §2.6 验收**；避免同一被滥用厂商（如 Evoxt） |
| 机房直连 / 香港节点 | ❌ 不可用 | 前者被限流，后者国别不支持 |

### 2.4 WARP 落地过程（历史记录，已归档）

> korea 时代（2026-09-22 前）的原始落地步骤已移除。当前 malaysia 架构直接见 **§2.5** 与 **§2.14**。

### 2.5 多出口 + 故障切换（当前生产架构）

```
网关 cli-proxy-api（systemd 原生进程，直接监听 :80）
   config.yaml:  proxy-url = socks5://127.0.0.1:1080       （malaysia 无 docker → 用 127.0.0.1）
            ▼
   haproxy (TCP 透传 LB，127.0.0.1:1080，roundrobin + TCP 健康检查 inter 10s fall 2)
     ├── 127.0.0.1:1081 ── wireproxy ← /root/warp/profiles/1 ─┐
     └── 127.0.0.1:1082 ── wireproxy ← /root/warp/profiles/2 ─┴→ Cloudflare WARP（吉隆坡 PoP）
   cpa-diskguard.timer 每 5 分钟巡检磁盘：>85% 自动清日志/转储/journal
   cpa-memguard.timer  每 2 分钟巡检 RSS：>600MB 自动重启网关
   ⚠️ warp-watchdog.timer（出口自愈）本轮重装后未重建 —— 恢复配方见本节末
```

| 文件 / 单元 | 作用 |
|---|---|
| `/root/warp/profiles/<N>/wireproxy.conf` | 第 N 个出口（`BindAddress = 127.0.0.1:108<N>`；**profile 可从别处直接拷来**，只需改 BindAddress） |
| `/etc/systemd/system/warp-proxy@.service` | 模板单元：`systemctl status warp-proxy@1` |
| `/etc/haproxy/haproxy.cfg` | LB（后端 = 存活的 `warp-proxy@N`） |
| `/usr/local/bin/cpa-diskguard.sh` + `cpa-diskguard.timer` | **磁盘自愈**（>85% 自动清理） |
| `/usr/local/bin/cpa-memguard.sh` + `cpa-memguard.timer` | **内存自愈**（RSS >600MB 重启网关）——2026-09-27 新增 |
| `/root/cpa/account.sh` | **账号池**：`add <email> <rt>` / `list` / `enable\|disable <email\|all>` |

```bash
# 看状态（malaysia 全部单元）
for u in cli-proxy-api haproxy warp-proxy@1 warp-proxy@2 cpa-diskguard.timer cpa-memguard.timer; do printf '%s=' $u; systemctl is-active $u; done
grep 'server warp' /etc/haproxy/haproxy.cfg
bash /root/cpa/account.sh list                       # 账号池

# 出口故障切换演练（停一条，聚合口与网关应照常）
systemctl stop warp-proxy@1 && sleep 26
curl -s -m 20 --socks5-hostname 127.0.0.1:1080 -o /dev/null -w 'egress=%{http_code}\n' https://www.gstatic.com/generate_204
curl -s -m 60 http://127.0.0.1/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"gemini-3.8-flash-high","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' | head -c 120
systemctl start warp-proxy@1                          # 恢复

# 新增出口：profile 需在"未被限流的出口"上注册（可直接借用现有隧道）：
#   HTTPS_PROXY=socks5h://127.0.0.1:1082 ./wgcf register --accept-tos && HTTPS_PROXY=socks5h://127.0.0.1:1082 ./wgcf generate
mkdir -p /root/warp/profiles/3
cp wgcf-profile.conf /root/warp/profiles/3/wireproxy.conf   # 再把 BindAddress 改成 127.0.0.1:1083
systemctl enable --now warp-proxy@3
# 在 /etc/haproxy/haproxy.cfg 后端加一行：server warp3 127.0.0.1:1083 check，然后 systemctl reload haproxy
```
注意：**haproxy 的 `option tcp-check` 只能证明端口在监听，无法证明隧道可用**（实测：WireGuard 隧道 DNS 卡死时端口仍开、请求全进黑洞）。所以本方案**不依赖** TCP 检查，而由 `warp-watchdog` 的端到端探测**直接驱动** haproxy 运行态。

**出口自愈已于 2026-09-27 重建并演练通过** ✅

```
haproxy global: stats socket /run/haproxy/admin.sock mode 660 level admin
        ▲
/usr/local/bin/hap-api.py        # 与运行态 socket 通话：'show stat' / 'set server … state maint|ready'
        ▲
/usr/local/bin/warp-watchdog.sh  # 每 profile：curl --socks5-hostname 127.0.0.1:<port> gstatic/generate_204 期望 204
   探测通过 → state ready（若原来不在 UP）
   连续 2 轮失败 → set server warp-socks/warpN state maint → systemctl restart warp-proxy@N → 等 22s 复测
   全部后端都不 UP → fail-open 把所有后端置回 ready（宁可抖也不要全黑）
   flock -n 防定时器与手动执行并发
warp-watchdog.timer  每 60s（OnBootSec=90s）
```

```bash
# 手动查/干预
python3 /usr/local/bin/hap-api.py 'show stat' | awk -F, '$1=="warp-socks"{print $2,$18}'
python3 /usr/local/bin/hap-api.py 'set server warp-socks/warp2 state maint'   # 手动摘除
python3 /usr/local/bin/hap-api.py 'set server warp-socks/warp2 state ready'   # 手动恢复
journalctl -t warp-watchdog -n 30
```

**演练（2026-09-27，复现"端口活着但隧道已死"）**：停掉 `warp-proxy@2`，再用 `python3 -m http.server 1082` 占住端口 → haproxy 的 `tcp-check` 仍显示 `warp2 status=UP`，聚合口 6 次探测只过 **2/6**（流量被轮询到假后端）→ watchdog 第 2 轮判定 `probe FAILED (2/2)` → `warp2 -> maint` → 聚合口恢复 **6/6** → 清掉假监听并重启真隧道后 `profile 2 back to ready`，`1081=204 1082=204`。日志原文见 journald（`warp-watchdog`）。

另三条实测经验：① 判死前必须**给足隧道启动时间**（8 秒不够，22–25 秒稳）；② 用 wgcf 新增出口时即使走 WARP 出口也可能 `429`（注册接口被限流），需换出口或稍后重试；③ WARP 免费档在**高并发下会自己抖动**（DNS 解析卡住），所以"多出口 + 精确摘除"比"单出口 + 死等"稳得多。

### 2.6 账号池管理（多号 = 唯一的产能扩展手段）

**为什么必须多号**：单个账号在 Gemini 链路上有**每分钟 token 预算**。实测：omp 一轮请求体 ≈ **103 KB ≈ 2.5 万 token**，连发时只有前 1–2 个能过，之后 `429 Resource has been exhausted`；停 1–2 分钟又恢复（连 25k token 的请求也能过）。⇒ **单号大约每分钟只能支撑 1 个 agent 回合**，这正是原帖"15–20 个号"的原因。裁剪工具集无用（11→4 个 tools 只省 4%，大头是系统提示）。

**服务器上的账号助手**（`/root/cpa/account.sh`）：

```bash
/root/cpa/account.sh add <email> <refresh_token>   # 新增账号（写入 /opt/cpa/auths/，网关自动热加载）
/root/cpa/account.sh list                          # 总览：email / disabled / status / ok / fail
/root/cpa/account.sh disable <email|all>           # 停用（额度耗尽的号先停，别让它拖累全池）
/root/cpa/account.sh enable  <email|all>           # 额度回填后再启用
```
> 只改 auth 文件里的 `"disabled": true/false`，网关靠文件监听自动生效（约 8s），不用重启容器。

**两条必须记住的池子规则（实测得出）**

1. **`disable-cooling` 保持 `true`（关冷却）**：上游的 quota 类 429 会按**模型**冷却，一旦某个号耗尽，它每次被轮到时都会把 `gemini-3.8-flash-high` 整个模型冷却 ~2 分钟（报 `All credentials for model … are cooling down`），**连累健康号**。关掉冷却后，429 直接返回给客户端（客户端重试即可），健康号不受影响。
2. **耗尽的号要显式停用**：启用状态下它会被反复选中并 429。判定方法：
   ```bash
   /root/cpa/account.sh list                       # status=error 且 fail 持续增长 → 先 disable
   ```
   停用后单号仍 429 → 说明该号当前窗口也被打满（等 1–2 分钟再试）。

**快速判定某号是否可用**（重放 agent 级大请求，最能暴露预算问题）：
```bash
curl -s -m 120 http://127.0.0.1/v1/chat/completions -H 'Content-Type: application/json' \
  -d @/tmp/ompbody.json | head -c 200      # OK 即为健康
```

**跨账号 fallback 规则（已配置并实测）**

当前 `/opt/cpa/config.yaml` 相关键：

| 键 | 值 | 含义 |
|---|---|---|
| `request-retry` | `3` | 失败后最多 3 轮额外重试；**429/403/408/500/502/503/504 都算可重试** |
| `max-retry-credentials` | `5` | 每轮最多尝试 **5 个**可用凭据（2026-10-06 由 0 改为 5） |
| `max-retry-interval` | `30` | 轮与轮之间最多等 30s，给冷却中的凭据恢复时间 |
| `disable-cooling` | `true` | 关冷却：失败的号不被标记，重试轮按轮询换到下一个号；**不会出现"整模型 2 分钟黑障"** |

链路：`客户端请求 → 选中凭据 A → 429 → 重试轮 1 换 B → 429 → 重试轮 2 换 A → …（最多 3 轮）`。

实测结果（2 个号、配额都偏紧时）：

| 场景 | 客户端看到 |
|---|---|
| 中等请求（~1–4k token）×8 | **8/8 OK**（每号各 4 次失败，被对方重试兜住；日志里单个请求出现 8 次 API REQUEST） |
| 大请求（omp 原体 103 KB ≈2.5 万 token） | 仍 429 —— 两个号的窗口同时紧张时装不下；**这不是没配 fallback，而是总容量不够** |

> 关于 `disable-cooling` 的取舍：开冷却（false）时"失败的号被临时排除"能省一次无效尝试，但**所有号都紧张时会把整个模型冷却 ~2 分钟**（报 `All credentials for model … are cooling down`），客户端直接黑障；关冷却（true）则是干净地返回 429 + 客户端重试。我们选后者。

```bash
# 回滚到"无重试"的旧行为
cp /opt/cpa/config.yaml.bak-prefallback /opt/cpa/config.yaml && systemctl restart cli-proxy-api
```

**会话粘滞 vs 按请求轮询（2026-09-27 起改为轮询）**

```yaml
routing:
  strategy: "round-robin"
  session-affinity: false        # ← 当前值：按请求轮询（真负载均衡）
  session-affinity-ttl: "1h"
```

| 取值 | 行为 | 收益 / 代价（均为实测） |
|---|---|---|
| `true`（2026-09-22 ~ 09-27） | 同一会话固定在同一个号（日志：`session-affinity: cache miss, new binding \| auth=antigravity-<email>.json`），绑定号不可用时自动 failover | ✅ 隐式前缀缓存命中，长会话省额度、TTFT 低<br>❌ **pi/omp 每轮都带同一个 session id ⇒ 该会话所有请求钉死在一个号上，等于没有负载均衡** |
| **`false`（当前）** | 每次请求独立轮询（实测 12 次 → 2 个健康号 **6:6**） | ✅ 真负载均衡、单号压力减半、可用计数器验证<br>❌ 同一会话的上下文轮流落到不同号 → 前缀缓存不一致（`cached_tokens=0`），**长会话（20–32 万 token）更费额度** |

**为什么当初要开粘滞**：长会话单请求 input 高达 20–32 万 token。轮询会把同一会话的上下文轮流发到不同号，隐式缓存前缀不一致 → 每次都按全量计费，两个号瞬间被打干。

**怎么选**：① 号少 + 会话长 + 额度紧 → `true`（省额度优先）；② 要摊平并发、或要在计数器上验证均衡 → `false`（当前，均衡优先）。想"既要均衡又要省额度"只能**同时开多个并发会话**（每个会话各自绑一个号）；号少时二者不可兼得。

```bash
# 切换（文件监听 → 约 8 秒生效，不用重启）
sed -i 's/^  session-affinity: true/  session-affinity: false/'  /opt/cpa/config.yaml   # 关粘滞
sed -i 's/^  session-affinity: false/  session-affinity: true/'  /opt/cpa/config.yaml   # 开粘滞
grep -A4 '^routing:' /opt/cpa/config.yaml
```

**prompt 体积实测（同一台机、同一天，错误日志里的完整 body 对比）**

| 配置 | body | system 提示 | 工具 schema | 含 MCP 指令 |
|---|---|---|---|---|
| 8 个 MCP 全开 | 106,889 B | **98,988 字符** | 11 个 / 6,066 B（6%） | 是 |
| MCP 全关 | 74,116 B | **66,553 字符** | 同上 | 否 |

⇒ **MCP 服务器净增约 32 KB 系统提示 ≈ 8k token/请求**；大头是各服务器注入的 *MCP Server Instructions*，**不是工具 schema**（只占 6%）。8 个服务器（6 个远程 HTTP）还会拖慢启动（配合 `auto-thinking` 分类调用 → "没输入就卡住"）。
省法：`~/.omp/agent/mcp.json` 加顶层 `"disabledServers": [...]`，或 TUI 里 `/mcp disable <name>`；同时可设 `OMP_MCP_TIMEOUT_MS=8000` 限制启动阻塞。

### 2.7 为什么 omp 报 429、pi 却"没事"（实测对照）

同一次采样（同一网关、同一模型）：

| 客户端 | 单请求 input tokens | thinking | 结果 |
|---|---|---|---|
| pi（全新会话） | **25,357** | medium | OK |
| omp（长会话） | **355,732** | **high** | OK（吃光整分钟预算） |
| omp（紧随其后） | 0（未发出） | medium | **429** |

三个放大因素（都不在 pi 侧）：

1. **上下文声明过大**：omp `models.yml` 把 gemini 写成 `contextWindow: 1000000`，而 omp 的自动压缩阈值 ≈ 窗口 × 0.85 → **要涨到 ~85 万 token 才压缩**，于是会话膨胀到 20–35 万 token/请求。**最终修法（避免"一开窗 12%"错觉）**：声明窗口保持 1M，但在 `~/.omp/agent/settings.json` 写**绝对压缩阈值** `{"compaction": {"thresholdTokens": 200000, "keepRecentTokens": 20000}}` → 到 20 万 token 硬压缩，**无需手动 `/compact`**。（曾短暂改成 `contextWindow: 250000`，但那会让同一基线从 3% 显示成 12%，已回退；备份 `models.yml.bak-ctx` / `.bak-ctx2`）
2. **thinking 档位是 high**：长会话里存在会话级 thinking 覆盖，`eff=high` 让 reasoning token 翻倍。默认已设 `medium`（角色写成 `antigravity/gemini-3.8-flash-high:medium`）；**运行中的会话要手动切档或重开**。
3. **MCP 指令**：omp 会从 `~/.claude.json` 发现 15 个 MCP 服务器并注入其 instructions（实测系统提示 99 KB ↔ 66 KB）。**已把 14 个加入 `~/.omp/agent/mcp.json` 的 `disabledServers`**（保留 context7 + filesystem）→ 系统提示降到 ~72 KB。恢复：`/mcp enable <name>` 或从数组里删掉。

**那个 `Provider requested 1800000ms wait`**：429 里带的是上游额度窗口的 retry 提示（30 分钟）。**omp 会读它**并按 `retry.maxDelayMs`（默认 300s）判定"超过上限"直接报错；**pi 不读该字段**，所以看起来"pi 没问题"——其实两个客户端都在同一池子里被限流，只是 omp 的请求把预算吃光后，报错最显眼。

**必须由你做的动作**：运行中的长会话执行 `/compact`；重启 omp 让新的 `contextWindow`/thinking/MCP 生效。**根本解法仍是加号**（2 个号扛不住 20–35 万 token/请求的工作量）。

### 2.8 思考档位（medium / high）怎么控

⚠️ **模型 id 里的 `-high` 只是网关目录里的名字，不代表思考深度**——本网关只暴露 `gemini-3.x-flash-high` 这一档 id（`-medium`/`-low`/`-tiered` 会报 `unknown provider for model`）。真正的档位由请求里的 **`reasoning_effort`** 控制，实测（同一题、同模型）：

| reasoning_effort | reasoning_tokens | 用时 |
|---|---|---|
| `low` | 不上报（≈最低） | 3.6s |
| `medium` | 450 | 6.0s |
| `high` | 839 | 7.5s |
| 不传 | 663（≈上游默认，介于中/高） | 3.7s |

**当前默认 = medium**（省额度）：

| 客户端 | 配置 | 实测 |
|---|---|---|
| omp | `~/.omp/agent/config.yml` → `defaultThinkingLevel: medium` | 网关明细记录 `reasoning_effort=medium` ✅ |
| pi | `~/.pi/agent/settings.json` → `defaultThinkingLevel: "medium"`；同时 `models.json` 的 `compat.supportsReasoningEffort` 必须为 **true**（否则 pi 不发 effort） | 同上 ✅ |
| opencode | `~/.config/opencode/opencode.json` → 模型级 `options.reasoningEffort: "medium"` | ⚠️ 实测**未透传**（请求不带 effort，走上游默认）；如需强制，用 variant 或接受默认 |

想临时用高/低档：omp `--thinking high`、pi `--thinking high`，或在会话里切。

### 2.9 客户端切换 / 回滚模型

```bash
# 当前口径（2026-10-06 修订，Claude 系用 4.6）：
#   omp:      ~/.omp/agent/config.yml       → modelRoles.default: antigravity/claude-sonnet-4-6（fallback 至 gemini-3.8-flash-high:medium）
#   pi:       ~/.pi/agent/settings.json     → defaultProvider: antigravity, defaultModel: claude-sonnet-4-6, defaultThinkingLevel: medium（fallback 至 gemini-3.8-flash-high:medium）
#   hermes:   ~/.hermes/config.yaml         → model.default: gemini-3.8-flash-high（直接走 Gemini 池，不设 thinking）
#   opencode: ~/.config/opencode/opencode.jsonc → "model": "antigravity/claude-sonnet-4-6"（fallback: gemini-3.8-flash-high:medium）
#
# 一条命令切换（Git bash）：
#   omp  → claude： sed -i 's|default: antigravity/[^ ]*|default: antigravity/claude-sonnet-4-6|' ~/.omp/agent/config.yml
#   pi   → gemini： sed -i 's|"defaultModel": "[^"]*"|"defaultModel": "gemini-3.8-flash-high"|'        ~/.pi/agent/settings.json
#   oc   → gemini： sed -i 's|"model": "antigravity/[^"]*"|"model": "antigravity/gemini-3.8-flash-high"|' ~/.config/opencode/opencode.jsonc
# 单会话临时切换不写配置：omp/pi 里 /model，opencode 里 /models
```

### 2.10 出口合格性验证脚本（**任何新出口迁移前必跑**）

```bash
B=http://155.254.60.38; ok=0
for i in $(seq 20); do
  r=$(curl -s -m 90 $B/v1/chat/completions -H 'Content-Type: application/json' \
      -d '{"model":"gemini-3.8-flash-high","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' \
      | jq -r 'if .error then "FAIL" else "OK" end')
  printf '%s ' "$r"; [ "$r" = "OK" ] && ok=$((ok+1))
done; echo; echo "通过 $ok/20"
```
**两道门槛**：① 20 次 ≥19 通过；② **持续负载 50 次以上、≥95% 通过且中途不掉零**（本方案的马来西亚出口就是"快测 92%、一小时被打到 0"，只做①会误判）。

### 2.11 如何获得"干净出口"（判据与采购）

```bash
curl -s "http://ip-api.com/json/<IP>?fields=country,isp,org,as,hosting,proxy,mobile,reverse"
```
| 信号 | 干净 | 不干净 |
|---|---|---|
| ASN org | 家宽 ISP / Cloudflare | hosting 品牌（Evoxt、DigitalOcean、Vultr…） |
| rDNS | ISP 风格（`*.ap.nuro.jp`） | `*.aceips.com`、空 |

获取途径：① **WARP**（免费，本方案已用；注册需在未被限流的出口上完成）；② 独享**静态住宅 IP**（按月、不限流量）；③ 日本/新加坡**原生线路 VPS**（买前必测）；④ 家宽隧道（需在**支持国家**有常开设备）；⑤ 移动 4G/5G 代理。
⚠️ **HK / CN / MO 不在 Google 支持列表**——实测香港住宅节点直接 400，别在这类节点上浪费时间。
⚠️ 流量账：agent 每次请求要发完整上下文（200k ≈ 0.6–0.8 MB/次，1M ≈ 3–4 MB/次），按 GB 计费的代理会很贵 → 优先"独享 IP + 不限流量"。

---

### 2.12 磁盘事故加固清单（永久有效）

> korea 事故全文复盘已归档。当前 malaysia 已落地所有防护措施：`logs-max-total-size-mb: 300`、`cpa-diskguard.timer`、`cpa-memguard.timer`、journald 封顶 80M。**保留以下加固清单供换机/重装参考。**

| 项 | 目标值 | 说明 |
|---|---|---|
| 网关日志总量 | `logs-max-total-size-mb: 300` | **0 = 无限，是事故直接元凶** |
| 错误日志保留 | `error-logs-max-files: 10` | 别设 0（=不清理） |
| journald | `SystemMaxUse=80M` | 默认无限增长 |
| docker 日志 | `max-size=20m, max-file=3` | 如用 docker 必须配 |
| VPS 磁盘 | 建议 ≥ 25 G，或把 `logs/` 挂独立卷 | 9.8 G 盘余量有限 |
| 监控 | `df / \| awk 'NR==2 && $5+0>85'` 加进 cron/timer | 提前告警 |

### 2.13 换机重建参考（malaysia 为主网关，2026-09-22 实战）

**背景**：原服务器因满盘 → ext4 abort → 根分区只读并整机冻结。此时"换机器重建"比等修复快——本节记录 malaysia 的接管流程，也是未来换机的参考脚本。

**判据：整机冻结 vs 单服务故障**
```bash
curl -sv -m 10 http://<IP>:80/ | grep -E 'Empty reply|HTTP/'
#  Empty reply from server  + ssh: kex_exchange_identification: Connection closed  → 整机冻结（存储层）
#  正常 502/404               → 只是后端进程挂了，容器层面可修
```

**验收清单（malaysia 155.254.60.38，Debian 12 / 9.8 G 盘 / 961 M 内存 / 无 docker）**：
```bash
# 1) WARP 出口（profile 可移植，只需改 BindAddress 到本机）
systemd-run --unit=wp2 --collect --property=Restart=always /root/warp/wireproxy -c /root/warp/profiles/2/wireproxy.conf
# 2) haproxy 聚合（127.0.0.1:1080 → 1081/1082）
# 3) 网关二进制（无需 docker）：GitHub release 里是 linux_amd64.tar.gz，**解包后的文件名是小写 cli-proxy-api**
curl -sL -o cpa.tgz https://github.com/router-for-me/CLIProxyAPI/releases/download/v7.3.13/CLIProxyAPI_7.3.13_linux_amd64.tar.gz
tar xzf cpa.tgz -C /opt/cpa && systemctl enable --now cli-proxy-api   # ExecStart=/opt/cpa/cli-proxy-api
# 4) config.yaml 关键项：port: 80 / auth-dir: /opt/cpa/auths / proxy-url: socks5://127.0.0.1:1080
# 5) 验收：见 §2.14 的 D/E 阶段（逐号定向 + 均衡计数）
```
> 📌 目录与端口统一为：`/root/warp/{wireproxy,profiles/N}`、`/root/wgcf`、`127.0.0.1:1081/1082`。

**客户端改指（Git bash）**：
```bash
# 客户端 baseUrl 保持 http://155.254.60.38/v1，换机后只需确认该地址仍可达
# omp 走本机 19877 的 mitm_fix.js 代理：改该脚本里的 hostname/host 后重启进程
#   C:/Users/da/AppData/Local/Temp/mitm_fix.js
#   Stop-Process -Id <pid>; Start-Process node -ArgumentList <脚本> -WindowStyle Hidden
```

**herdr pane 复活手册（agent 因 429 停摆后用）**：
```bash
# 1) 文本与 Enter 必须分开发送（text 是括号粘贴语义，\r 不提交）
#    PowerShell pane：粘贴会被 PSReadLine 弄坏（digit-argument）→ 必须用 pane.send_text
# 2) 底层 API（CLI 未暴露 pane.send_text）：Windows 命名管道
#    \\.\pipe\C:\Users\da\AppData\Roaming\herdr\herdr.sock   （请求需带 id 字段）
# 3) pi 重启并续会话：  pane.send_text "pi --session <uuid>\r"
#    opencode 退出时会打印 "Continue  opencode -s ses_xxx"，用同一方式重启
# 4) 长会话超窗会自动压缩：pi 443K→245K、opencode 403K→68.5K（声明窗口 25 万的效果）
```

---

### 2.14 服务器重装后重建（2026-09-27 实战，可直接照抄）

**背景**：malaysia 被重装（干净 Debian 12，只剩 sshd 22），`/opt/cpa`、WARP、haproxy 全丢。账号 auth 从本地备份恢复。**客户端零改动**（baseUrl 不变）。

**分阶段脚本**（已实跑，落在 `C:\Users\da\cpa_deploy\malaysia-20260927\`：`stage-a…f.sh` + `config.yaml` + `cpa-account.sh` + 两个 guard）

| 阶段 | 内容 | 结果 |
|---|---|---|
| **A** 依赖+二进制 | apt 装 haproxy/jq；下载 CLIProxyAPI 7.3.13、wireproxy 1.0.9(octeep)、wgcf 2.3.0 | `/opt/cpa/cli-proxy-api`、`/root/warp/wireproxy`、`/root/wgcf` |
| **B** WARP 出口 | `wgcf register --accept-tos` ×2（两个独立 device）→ 生成 `wireproxy.conf`（BindAddress 1081/1082）→ `warp-proxy@.service` + `haproxy.cfg` | 两条隧道出口 `104.28.205.51`（Cloudflare MY），`gstatic 204` 通过 |
| **C** 网关上电 | SFTP 传 `config.yaml` + 4 个 auth（**md5 逐文件校验一致**）→ `cli-proxy-api.service` + `mem.conf` drop-in → 启动 | `:80` 监听、`4 clients` 加载、`management asset` 自动下载 |
| **D** 账号逐号验证 | 给每个 auth 临时加 `prefix`，用 `<prefix>/gemini-3.8-flash-high` 单打，读管理计数器归因 | 2 个 200、2 个 403（见下） |
| **E** 负载均衡验证 | 去掉 prefix，连打 12 次，对比计数器 | **12/12 200；6:6** |
| **F** 运维恢复 | `account.sh`；新建 diskguard/memguard timer；未验证账号的 Google 链接写入 `/root/cpa/verify-urls.txt`（600） | 两个 timer `active waiting` |

```bash
# 核心命令
apt-get update -qq && apt-get install -y -qq haproxy jq ca-certificates curl
curl -sSL -o /tmp/cpa.tgz https://github.com/router-for-me/CLIProxyAPI/releases/download/v7.3.13/CLIProxyAPI_7.3.13_linux_amd64.tar.gz && tar xzf /tmp/cpa.tgz -C /opt/cpa
curl -sSL https://github.com/octeep/wireproxy/releases/download/v1.0.9/wireproxy_linux_amd64.tar.gz | tar xz -C /tmp && install -m755 /tmp/wireproxy /root/warp/wireproxy
curl -sSL -o /root/wgcf https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_linux_amd64 && chmod 755 /root/wgcf
# config.yaml 关键项（重装后确认）：port: 80 / auth-dir: /opt/cpa/auths /
#   proxy-url: socks5://127.0.0.1:1080 / routing.session-affinity: false
```

**验收（本次实测输出）**

```
GET  /v1/models                → 200，12 个模型，含 gemini-3.8-flash-high（外部直连 0.68s）
POST /v1/chat/completions      → 200（2.75s，content "ok"）          ← 外部直连
POST /v1/messages  (Anthropic) → 200                                  ← 同一端口
POST /v1/responses             → 200
逐号定向：eyagogiziluj44 200 / rlinhvomason 200 / anhhoangmasoncoleman 403 / awojewahay30 403
均衡：12 次 → eyagogiziluj44 +6 / rlinhvomason +6
服务：cli-proxy-api active :80；haproxy 1080；wireproxy 1081/1082；磁盘 16%
```

**账号被 Google 判"需要验证"（403 `VALIDATION_REQUIRED`）—— 服务器侧无解**

```json
{"error":{"code":403,"message":"Verify your account to continue.","status":"PERMISSION_DENIED",
 "details":[{"reason":"VALIDATION_REQUIRED","metadata":{"validation_url":"https://accounts.google.com/signin/continue?..."}}]}}
```
- 判据：**同机同出口下另外两个号 200** → 排除网络/出口问题，纯账号侧。
- 处置：用该账号登录浏览器打开 `validation_url`（已存 `/root/cpa/verify-urls.txt`），完成后 `account.sh enable <email>`。
- 未验证完前保持 `disabled=true`，否则轮询会不断撞 403（本机实测一个被停用前累计 `fail=12`）。

**本轮新踩的坑**
- `wgcf --version` 报 unknown flag 属正常（它没有该 flag）；wireproxy 用 `--version`。
- 管理密钥沿用旧 bcrypt（`account.sh` 用 `Bearer admin`）；换密钥必须同步改脚本。
- `management.html` 由网关**自己下载**（启动日志 `management asset updated successfully`），无需手工放置。
- 重装后 `ssh` 端口可能变（本次：只剩 22，原 2222 消失）→ VibeShell 里指向 2222 的条目会连不上。

---

## 3. oh-my-pi（omp）

配置目录 `~/.omp/agent/`（`PI_CODING_AGENT_DIR` 可覆盖，或 `omp --profile <name>`）。

### 3.1 provider（`~/.omp/agent/models.yml`）

```yaml
providers:
  antigravity:
    baseUrl: http://127.0.0.1:19877/v1   # ← 本机 mitm_fix.js 代理，再转发到网关（见下）
    apiKey: antigravity-gateway
    api: openai-completions
    models:
      - { id: gemini-3.8-flash-high, name: "Gemini 3.8 Flash High (Antigravity 反代)", reasoning: true, input: [text, image], contextWindow: 1000000, maxTokens: 32000, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }
      - { id: gemini-3.7-flash-high, name: "Gemini 3.7 Flash High (Antigravity 反代)", reasoning: true, input: [text, image], contextWindow: 1000000, maxTokens: 32000, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }
      - { id: gemini-3-flash,        name: "Gemini 3 Flash (Antigravity 反代)",        reasoning: true, input: [text, image], contextWindow: 1000000, maxTokens: 32000, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }
      - { id: gemini-3.1-pro-low,    name: "Gemini 3.1 Pro Low (Antigravity 反代)",    reasoning: true, input: [text, image], contextWindow: 1000000, maxTokens: 32000, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }
      - { id: claude-sonnet-4-6,     name: "Claude Sonnet 4.6 (Antigravity 反代)",     input: [text, image], contextWindow: 200000, maxTokens: 32000, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }
      - { id: claude-opus-4-6-thinking, name: "Claude Opus 4.6 Thinking (Antigravity 反代)", input: [text, image], contextWindow: 200000, maxTokens: 32000, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }
      - { id: gpt-oss-120b-medium,   name: "GPT-OSS 120B Medium (Antigravity 反代)",   reasoning: true, input: [text], contextWindow: 131072, maxTokens: 32000, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }
```

> **omp 为什么指向 `127.0.0.1:19877`**：本机跑着一个 node 代理 `C:/Users/da/AppData/Local/Temp/mitm_fix.js`，职责是把请求体里的 `<system-conventions>` 改写成 `[system-conventions]` 后再转发到网关（脚本内**硬编码目标 `hostname`/`host`**）。
> ⇒ **迁移网关时必须同步改它并重启进程**，否则 omp 一直打向老地址（korea 已退役，会 502）：
> ```powershell
> # 1) 改脚本里的 hostname/host 为 155.254.60.38
> # 2) 重启：Stop-Process -Id <pid>; Start-Process node -ArgumentList 'C:/Users/da/AppData/Local/Temp/mitm_fix.js' -WindowStyle Hidden
> # 3) 验证：curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:19877/v1/models   # 期望 200
> ```
> pi / opencode 不经过这个代理，直接连 `http://155.254.60.38/v1`。

### 3.2 默认模型与**通道降级链**（`~/.omp/agent/config.yml`）

> ⚠️ 2026-09-23 修正：`smol`/`slow` 曾指向 `opencode-zen/*`，该通道（`https://opencode.ai/zen/v1`）**额度耗尽会返 402**；`tiny` 未设时会回落到 `@smol`，`defaultThinkingLevel: auto` 又会用 `tiny` 做分类 → 于是"402 刷屏"。现已全部改为显式、可用通道。

```yaml
modelRoles:
  default: antigravity/claude-sonnet-4-6          # 主力（Claude 池；思考档由 defaultThinkingLevel 控制）
  slow:    antigravity/claude-opus-4-6-thinking   # 规划/复杂任务（Opus 4.6）
  smol:    antigravity/claude-sonnet-4-6          # 轻量
  tiny:    antigravity/claude-sonnet-4-6          # 标题/记忆/auto 分类
defaultThinkingLevel: medium                      # 明确 medium；用 auto 会额外触发分类调用
retry:
  modelFallback: true            # 通道失败（429/配额墙/供应商故障）自动降级
  fallbackRevertPolicy: cooldown-expiry   # 冷却结束自动切回主力
  fallbackChains:
    default:                     # 任何未单独配链的角色都继承这条
      - antigravity/claude-sonnet-4-6
      - antigravity/gemini-3.8-flash-high:medium
```

**实测**：Claude 遇到 429 时自动落到 Gemini 3.8 Flash。
链的匹配优先级（`omp://settings.md`）：精确 `provider/model-id` → `provider/*` 通配 → 当前角色的链 → `default`。

配套（防 429 的关键，见 §2.7）：`~/.omp/agent/settings.json`
```json
{ "compaction": { "thresholdTokens": 200000, "keepRecentTokens": 20000 } }
```
声明窗口仍写 1M（UI 百分比好看），但**压缩在 20 万 token 硬触发**，请求不会涨到 30 万+。

**角色速查**（`omp://models.md`）：内置 `default / smol / slow / vision / plan / commit / tiny / task / advisor`；`tiny` 未设 → 回落到 `@smol`；角色值可带思考档后缀 `:minimal|low|medium|high|xhigh|max`。
设置方式：TUI `/settings`、`/models`，或 `omp config set defaultThinkingLevel medium`（**嵌套 `modelRoles.*` 不支持 `omp config set`，需直接编辑 config.yml**）。

### 3.3 验收

```bash
omp models | grep -A8 antigravity
omp -p --no-session "Reply with exactly: OMP-OK"
omp -p --no-session --mode json "hi" | grep -o '"model":"[^"]*"'
```

---

## 4. pi coding agent

配置目录 `~/.pi/agent/`（`PI_CODING_AGENT_DIR` 可覆盖）。⚠️ `models-store.json` 是**缓存**，不要手改；自定义 provider 写 `models.json`。

### 4.1 provider（`~/.pi/agent/models.json`）

```json
{
  "providers": {
    "antigravity": {
      "baseUrl": "http://155.254.60.38/v1",
      "api": "openai-completions",
      "apiKey": "antigravity-gateway",
      "compat": { "supportsDeveloperRole": false, "supportsReasoningEffort": true },
      "models": [
        { "id": "gemini-3.8-flash-high", "name": "Gemini 3.8 Flash High (Antigravity 反代)", "reasoning": true, "input": ["text","image"], "contextWindow": 250000, "maxTokens": 32000, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0} },
        { "id": "gemini-3.7-flash-high", "name": "Gemini 3.7 Flash High (Antigravity 反代)", "reasoning": true, "input": ["text","image"], "contextWindow": 250000, "maxTokens": 32000, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0} },
        { "id": "gemini-3-flash",        "name": "Gemini 3 Flash (Antigravity 反代)",        "reasoning": true, "input": ["text","image"], "contextWindow": 250000, "maxTokens": 32000, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0} },
        { "id": "gemini-3.1-pro-low",    "name": "Gemini 3.1 Pro Low (Antigravity 反代)",    "reasoning": true, "input": ["text","image"], "contextWindow": 250000, "maxTokens": 32000, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0} },
        { "id": "claude-sonnet-4-6",     "name": "Claude Sonnet 4.6 (Antigravity 反代)", "input": ["text","image"], "contextWindow": 200000, "maxTokens": 32000, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0} },
        { "id": "claude-opus-4-6-thinking", "name": "Claude Opus 4.6 Thinking (Antigravity 反代)", "input": ["text","image"], "contextWindow": 200000, "maxTokens": 32000, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0} },
        { "id": "gpt-oss-120b-medium",   "name": "GPT-OSS 120B Medium (Antigravity 反代)", "reasoning": true, "input": ["text"], "contextWindow": 131072, "maxTokens": 32000, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0} }
      ]
    }
  }
}
```

`compat.supportsDeveloperRole: false` **必须**：网关只认 `system` 角色，发 `developer` 会 400。

### 4.2 默认模型（`~/.pi/agent/settings.json`）

```json
"defaultProvider": "antigravity",
"defaultModel": "claude-sonnet-4-6",
"defaultThinkingLevel": "medium",
// fallback: 额度耗尽时在会话内切换至 gemini-3.8-flash-high:medium
```

思考档位由 `reasoning_effort` 控制（模型 id 里的 `-high` **只是名字**）：实测 low/medium/high → reasoning tokens 最低 / ~450 / ~839（§2.8）。所以 **medium 是质量与配额的平衡点**，明确写死。

### 4.3 验收

```bash
pi --list-models antigrav
pi -p --no-session "Reply with exactly: PI-OK"
pi -p --no-session --mode json "hi" | grep -o '"model":"[^"]*"'
```

---

## 5. opencode

全局配置 `~/.config/opencode/opencode.json`（或 `.jsonc`）；项目级 `./opencode.json` 优先。

### 5.1 配置

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "antigravity/claude-sonnet-4-6",   // 默认主力；额度耗尽手动切 gemini-3.8-flash-high:medium
  "provider": {
    "antigravity": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Antigravity 反代",
      "options": {
        "baseURL": "http://155.254.60.38/v1",
        "apiKey": "antigravity-gateway"
      },
      "models": {
        "gemini-3.8-flash-high": { "name": "Gemini 3.8 Flash High (Antigravity 反代)", "reasoning": true, "limit": { "context": 250000, "output": 32000 } },
        "gemini-3.7-flash-high": { "name": "Gemini 3.7 Flash High (Antigravity 反代)", "reasoning": true, "limit": { "context": 250000, "output": 32000 } },
        "gemini-3-flash":        { "name": "Gemini 3 Flash (Antigravity 反代)",        "reasoning": true, "limit": { "context": 250000, "output": 32000 } },
        "gemini-3.1-pro-low":    { "name": "Gemini 3.1 Pro Low (Antigravity 反代)",    "reasoning": true, "limit": { "context": 250000, "output": 32000 } },
        "claude-sonnet-4-6":     { "name": "Claude Sonnet 4.6 (Antigravity 反代)", "limit": { "context": 200000, "output": 32000 } },
        "claude-opus-4-6-thinking": { "name": "Claude Opus 4.6 Thinking (Antigravity 反代)", "limit": { "context": 200000, "output": 32000 } },
        "gpt-oss-120b-medium":   { "name": "GPT-OSS 120B Medium (Antigravity 反代)", "reasoning": true, "limit": { "context": 131072, "output": 32000 } }
      }
    }
  }
}
```

### 5.2 验收

```bash
opencode models antigravity
opencode run "Reply with exactly: OC-OK"        # 顶部应显示 · claude-sonnet-4-6
```

⚠️ 两个已知点（2026-09-22 实测）：
- opencode 的**模型级 `options.reasoningEffort: "medium"` 不保证透传到网关**（对比 pi/omp 会在请求里带 `reasoning_effort`）；若要强制档位，用 opencode 的 variant 机制，或改用 pi/omp。
- `limit.context` 从 1M 降到 **25 万**是**故意的**：与网关侧配额经济性直接相关（见 §2.7 / §2.12）。

### 5.3 其它客户端：Anthropic 兼容端（Claude Code / Anthropic SDK）

本网关**同一端口同时暴露 Anthropic 格式** `POST /v1/messages`（2026-09-27 实测 200），所以原帖那套 **Claude Code 别名在本网关可直接套用**（`/v1/chat/completions`（OpenAI）、`/v1/messages`（Anthropic）、`/v1/responses` 三套都在）：

```bash
export ANTHROPIC_BASE_URL=http://155.254.60.38        # ⚠️ 不要带 /v1（见下）
export ANTHROPIC_AUTH_TOKEN=antigravity-gateway       # 网关不校验（api-keys 为空）
export ANTHROPIC_MODEL=gemini-3.8-flash-high
export ANTHROPIC_DEFAULT_OPUS_MODEL=gemini-3.8-flash-high
export ANTHROPIC_DEFAULT_SONNET_MODEL=gemini-3.8-flash-high
export ANTHROPIC_DEFAULT_HAIKU_MODEL=gemini-3.8-flash-high
claude --dangerously-skip-permissions                  # 或加 --teammate-mode in-process
```

⚠️ 三个实测注意点（原帖没说透）：
1. **`ANTHROPIC_BASE_URL` 不能带 `/v1`**：Anthropic SDK 自己会拼 `/v1/messages`。带 `/v1` 会变成 `/v1/v1/messages` → **实测 404**；写 `http://155.254.60.38`（根）才对。
2. **别照抄原帖的 `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000`**：本方案 §2.7 的结论是压到 **20–25 万**才扛得住配额，1M 全开只会更快撞 429。
3. **`CLAUDE_CODE_EFFORT_LEVEL=max` 很吃额度**：§2.8 实测 high 的 reasoning token ≈ medium 的 2 倍；默认建议 medium。

---

## 6. 路径 / 环境变量速查

| 工具 | 默认配置目录 | 覆盖方式 | 关键文件 |
|---|---|---|---|
| omp | `~/.omp/agent/` | `PI_CODING_AGENT_DIR`、`--profile` | `models.yml`、`config.yml` |
| pi | `~/.pi/agent/` | `PI_CODING_AGENT_DIR` | `models.json`、`settings.json` |
| opencode | `~/.config/opencode/` | 项目内 `opencode.json` | `opencode.json(c)` |

Windows 下 `~` = `%USERPROFILE%`。改配置**不影响已运行的会话**：omp/pi 需新开会话（或 `/model`），opencode 需重开或 `/models` 重选。

---

## 7. 给 Agent 的任务书（整段复制）

```
任务：把本机 <omp|pi|opencode> 接入 Antigravity 反代网关，默认模型 claude-sonnet-4-6（用量耗尽自动 fallback 至 gemini-3.8-flash-high:medium）；hermes 默认 gemini-3.8-flash-high。

已知事实（直接采用，不要重新探测）：
- Base URL: http://155.254.60.38/v1（OpenAI 兼容，无需鉴权，apiKey 用占位符 antigravity-gateway）
  · 同一端口另有两套 API：`/v1/messages`（Anthropic，接 Claude Code 时 base 写 `http://155.254.60.38` **不带 /v1**）与 `/v1/responses`（见 §5.3）
- 出口：malaysia 网关经 Cloudflare WARP 出站（systemd: `warp-proxy@1/@2` → haproxy `127.0.0.1:1080`），Gemini 全系可用；
  出口自愈 `warp-watchdog.timer` 每分钟端到端探测、必要时摘除后端（§2.5）
- 运维入口：账号 `/root/cpa/account.sh list`；批量导号 `/root/cpa/import-cards.sh <cards.txt>`；
  面板 `http://155.254.60.38:18317/management.html`（Admin Key 在 `/root/cpamp-admin.key`）；
  网关管理密钥用 `/root/cpa/account.sh key` 打印（**不要写死 `admin`，它已失效**）
- 账号池：**9 个 auth（2026-10-06 更新）**；3 个新号满血可用，旧号 5h 窗口耗尽中待恢复；`max-retry-credentials: 5`（请求失败最多轮试 5 个账号）
- 路由：`round-robin` + `session-affinity: false`（按请求轮询）；同一会话上下文会轮流落号 → 长会话更费额度，属预期（§2.6）
- 只准配置这些模型：claude-sonnet-4-6（**omp/pi/opencode 默认**）/ gemini-3.8-flash-high（**hermes 默认 / fallback 目标**）/
  gemini-3.7-flash-high / gemini-3-flash / gemini-3.1-pro-low / claude-opus-4-6-thinking / gpt-oss-120b-medium
- ⚠️ **不要配置 claude-sonnet-5-5-high / claude-opus-5-5-high**：本批号是 Pro 试用，5.5 系返回 404（§0.2）
- claude / gpt-oss 与 gemini 走**不同额度池**，任一池临时 429 属正常，不要改路由去"修"（加号才是解）
- 严禁把面板端口当模型端点（chat 会 404）；**malaysia 只监听 :80**，模型端点就是 `http://155.254.60.38/v1`

步骤：
1. 连通性自检：curl -s -m 15 http://155.254.60.38/v1/models | grep -o '"id":"[^"]*"'
2. 备份待改文件为 <file>.bak-preantigravity。
3. 按 §3/§4/§5 写入 provider 与默认模型；只增改指定键，不得覆盖其它既有配置。
4. 验收并回贴真实输出：
   omp:      omp models | grep -A8 antigravity ; omp -p --no-session --mode json "hi" | grep -o '"model":"[^"]*"'
   pi:       pi --list-models antigrav ; pi -p --no-session --mode json "hi" | grep -o '"model":"[^"]*"'
   opencode: opencode models antigravity ; opencode run "Reply with exactly: OC-OK"
5. 工具回合（cwd 用临时目录）：omp -p --no-session "Use the bash tool to run: echo TOOL-OK. Report only the output."

约束：不跑全项目测试/lint；不改网关侧配置（改动需先备份 + 说明回滚）；
失败按 §8 排查并原样上报错误文本，不得静默降级或改用其它 provider。
```

---

## 8. 故障排查

| 症状 | 原因 | 处理 |
|---|---|---|
| `400 User location is not supported` | 出口 IP 被 Google 判定不受支持 | 确认 `proxy-url` 指向 LB：`grep '^proxy-url' /opt/cpa/config.yaml`；`systemctl is-active warp-proxy@1 warp-proxy@2 haproxy`；用 §2.10 复测 |
| LB 端口 1080 无监听 | haproxy 启动与配置写入竞态、或配置被改 | `haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl restart haproxy` |
| 管理面板 / 管理 API 报 401、403 | 密钥不对 | 网关管理密钥：`/root/cpa/account.sh key`（或读 `/root/cpa/mgmt.key`）；面板 Admin Key：`cat /root/cpamp-admin.key`。**`admin` 已在 2026-09-27 作废** |
| 面板打不开 / 显示 `usage_service_not_configured` | 面板服务未起或**未完成首次配置** | `systemctl status cpa-manager-plus`；重跑首配：`curl -X POST http://127.0.0.1:18317/setup -H "Authorization: Bearer $(cat /root/cpamp-admin.key)" -H 'Content-Type: application/json' -d "{\"cpaBaseUrl\":\"http://127.0.0.1\",\"cpaManagementKey\":\"$(cat /root/cpa/mgmt.key)\",\"pollIntervalMs\":30000,\"ensureUsageStatisticsEnabled\":true,\"requestMonitoringEnabled\":true}"` |
| 单个 WARP 出口失效 | 该 WARP 账号/线路抖动 | 自愈已内建：`journalctl -t warp-watchdog -n 30`；`python3 /usr/local/bin/hap-api.py 'show stat'`；手动摘除/恢复 `… 'set server warp-socks/warpN state maint\|ready'`；新增出口见 §2.5 末尾配方 |
| 要批量加号但一张张手敲太慢 | — | `bash /root/cpa/import-cards.sh <cards.txt>`（格式 `用户名----密码----2FA密钥----RT`），自动导入 + 逐个定向验证 + 失败自动 disable（§12） |
| `403 ... "Verify your account to continue."`（`reason: VALIDATION_REQUIRED`） | **该 Google 账号被要求二次验证**（纯账号侧，同机其它号正常） | 服务器无解。链接已存 `/root/cpa/verify-urls.txt` → 浏览器登录该号打开 → 完成后 `/root/cpa/account.sh enable <email>`（见 §2.14 末）。未验证期间保持 `disabled=true` |
| 想确认"是哪个号被拦" | 轮询下无法从客户端看出 | 给单个 auth 临时加 `"prefix": "<名>"`，用 `<名>/gemini-3.8-flash-high` 单打，再读管理计数器归因（§2.14 D 阶段） |
| 重装/换机后客户端连不上 | 入口变了：本次重装后**只剩 22 端口**（原 2222 消失），或网关尚未重建 | 先 `curl -s -o /dev/null -w '%{http_code}\n' http://155.254.60.38/v1/models`；不通就按 §2.14 重建。客户端 baseUrl 不变 |
| 管理面板 / 管理 API 报 401、403 | 管理密钥不对（当前密钥沿用旧 bcrypt，脚本用 `Authorization: Bearer admin`） | 用与 `account.sh` 相同的 Bearer；换密钥需同步改 `account.sh` 与面板登录 |
| 网关 RSS 涨到几百 MB / 磁盘涨到 90%+ | 长会话请求体巨大（单个转储 32 MB） | 已内建：`cpa-memguard`（>600MB 重启）与 `cpa-diskguard`（>85% 清日志）；查 `journalctl -t cpa-memguard -t cpa-diskguard` |
| 想升级 CLIProxyAPI | 上游已到 **v8.0.2**，v8 会**迁移并注释掉未知的旧配置段** | 先备份 `config.yaml`，在测试实例上跑一遍看 `routing.*` / `oauth-request-scoped-errors` 是否被保留，再动生产（见 §1 组件版本） |
| 所有出口一起失效 | WARP 大面积故障 / haproxy 挂 / 网关 proxy-url 被改回原生 | 逐个手测 `curl -s --socks5-hostname 127.0.0.1:1081 -o /dev/null -w '%{http_code}\n' https://www.gstatic.com/generate_204`；`systemctl restart haproxy`；确认 `grep '^proxy-url' /opt/cpa/config.yaml` = `socks5://127.0.0.1:1080` |
| `wgcf register` 返回 `429 Too Many Requests` | 注册接口按 IP 限流（机房 IP / 共享家宽 IP 均可能） | 用**未被限流的出口**发起注册（本方案在 NAS 上 `HTTPS_PROXY=… ./wgcf register` 成功） |
| 香港/机房节点测试全 400 | HK 不在支持列表；机房 IP 被限流 | 不要在这些节点上投入时间，回到 WARP/住宅出口 |
| `429 Individual quota reached ... Resets in Xh` | 该模型额度窗口用尽（账号侧） | 等重置（面板有倒计时）或加账号（原帖建议 15–20 号） |
| `429 Resource has been exhausted` | **账号的 token 预算窗口耗尽**（区别于单模型冷却）：实测小请求（数百 token）通过、约 3k token 的请求即 429，omp 的系统提示约 **2.5 万 token** 所以最先失败 | 等窗口回填（AI Pro/Ultra 每 5 小时刷新，外加周额度）；**根治 = 加账号**（原帖 15–20 个）。缓解：把 omp 的 `smol` 指到更低消耗模型，减少请求数 |
| omp 报 429 但 pi/opencode 正常 | omp 每轮请求体最大（工具 11 个 + 长系统提示 ≈100KB），最先撞到 token 预算 | 同上；确认 `~/.omp/agent/config.yml` 的 `smol` 思考档位降到最低 |
| `error.code == "model_cooldown"` | 该模型触发上游 429 后，网关按**模型**冷却该凭据（`reset_seconds` 约 66–110s） | 等冷却，或**先切到别的 Gemini 模型**（实测冷却只作用于单个模型：3.8 冷却时 3.7/3/3.1-pro/3.6 全部可用） |
| `unknown provider for model <id>` | 网关版本不同 → 模型目录不同（如 `gemini-3.8-flash-tiered` vs `-flash-high`） | 用 `/v1/models` 返回的真实 id；生产实例是 **v7.3.13**（§1） |
| `404 page not found` | 端口/路径不对：malaysia 只监听 **:80**（无 :8317/:18317） | OpenAI 端 `http://155.254.60.38/v1/...`；Anthropic 端 `http://155.254.60.38/v1/messages`（base **不带** `/v1`，见 §5.3） |
| `400` 提到 `developer` 角色 | 客户端发了 `developer` | pi 必须 `compat.supportsDeveloperRole: false` |
| 连不上网关 | 目标机网络/代理拦截 | 先 curl 验证；把网关主机加入 `NO_PROXY` |

---

## 9. 来源与参考

- CLIProxyAPI PR #4000 —— 出口 IP/地区判定机制、机房 IP 现象、`proxy-url` 解法
- OmniRoute PR #10420 —— 端点 `daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent`；"换支持地区代理出口"
- Antigravity 官方 —— [模型档位](https://antigravity.google/docs/models)、[额度规则](https://antigravity.google/docs/plans)（Gemini 与第三方两套额度）、[FAQ 地区列表](https://antigravity.google/docs/faq)
- 原 X 帖（本方案来源）：[@riba2534/status/2097574464167027121](https://x.com/riba2534/status/2097574464167027121) → 正文是 X Article《**Google Gemini 3.8 Flash 低价反代账号池搭建教程**》（2026-09-09）。要点：买成品号（自带 Refresh Token，35 元/个）+ **CLIProxyAPI + CPA-Manager-Plus + Caddy（Docker）** + **WARP 混淆出口** + 零宽字符破"假 429" + Claude Code 别名；自报 24 个号、43,216 次请求、成功率 99.88%、缓存命中 95.1%、TTFT P50 3.36s。**与本方案的逐项对照见 §11**

---

## 10. omp 通道故障实录（402 / Unable to connect）与降级治理（2026-09-23）

### 一、排查原因分析

**报错一：`Error: 402 Upstream request failed: Insufficient account funds`**

- **直接原因**：会话（session）里记录的当前模型是 `opencode-zen/gpt-5.6-sol`；该通道（`https://opencode.ai/zen/v1`）绑定的 API Key **额度已耗尽**，服务商返回 HTTP 402。
- **机制补充**（本次实测确认，比"改一个模型"更容易复发的坑）：
  - `opencode-zen` 是 **omp 内置 provider**（`omp models` 可见，106 个模型），**不写进 `models.yml` 也照样存在**，所以"配置里搜不到"≠"不会被调用"；
  - omp 的 `tiny` 角色**未设时回落到 `@smol`**，而 `defaultThinkingLevel: auto` 会用 `tiny` 做难度分类 → 只要 `smol`（或旧会话）指向该通道，就会**每回合刷 402**；
  - 402 是服务端错误（`type=server_error`），omp **不会**自动换通道，必须靠 `retry.fallbackChains`（见 §3.2 / §10 三）。

**报错二：`Default model: antigravity/gemini-3.8-flash-high` + `Error: Unable to connect. Is the computer able to access the url?`**

- **直接原因**：`~/.omp/agent/models.yml` 里 `providers.antigravity.baseUrl` 写的是本地地址 `http://127.0.0.1:19877/v1`，而**本机并未运行该代理**（端口 19877 无监听）→ 连接被拒/超时。
- **正解**：反代服务器是公网地址 **`http://155.254.60.38/v1`**（与 `opencode.jsonc`、`pi models.json` 保持一致）。
- 说明：`127.0.0.1:19877` 是本机 `mitm_fix.js`（改写 `<system-conventions>`）的监听地址，**只有该脚本在跑时才有效**；不再需要它时应直接写公网地址（见 §3.1）。

### 二、处理与验证

**处理 1 — 修正 baseUrl**（`~/.omp/agent/models.yml`）
```yaml
providers:
  antigravity:
    baseUrl: http://155.254.60.38/v1
```

**处理 2 — 角色显式化 + 挂上通道降级链**（治 402 的根，配置见 §3.2）
```bash
omp config set defaultThinkingLevel medium   # 嵌套 modelRoles.* 不被支持，需手改 config.yml
```

**验证（全部实测通过）**
```bash
omp config list | grep -A3 modelRoles                                   # 4 个角色均指向可用通道
omp -p --no-session "Reply with exactly: OMP-OK"                        # 端到端
omp -p --no-session --model antigravity/gemini-3.8-flash-high "hi"      # 单模型
# 降级链：2026-09-23 实测 antigravity 全线 429 时，omp -p "..." 仍返回 FALLBACK-OK（自动落 DeepSeek）
```

### 三、三通道矩阵（当前口径）

| 通道 | 承载模型 | 配额来源 | 定位 |
|---|---|---|---|
| antigravity · **Claude/GPT 池** | `claude-sonnet-4-6`、`claude-opus-4-6-thinking`、`gpt-oss-120b-medium` | 账号的 "Claude and GPT models" 额度条 | **omp / pi / opencode 主力**（default / slow / smol） |
| antigravity · **Gemini 池** | `gemini-3.8-flash-high`、`-3.7-`、`-3-`、`-3.1-pro-low` | 账号的 "Gemini Models" 额度条（独立，额度更大） | **hermes 默认**；omp/pi/opencode Claude 池耗尽时的 **fallback 目标** |

> **两个额度条互相独立**：一条打干时另一条常仍可用（实测 Claude 430 时 Gemini 仍 200，反之亦然）。看到 429 先换**族**，别急着改配置。

**池子打干是常态，不是配置错误**：9 个 auth（见 §0）× agent 大上下文时，`429 Resource has been exhausted` / `Individual quota reached … Resets in Xh Ym` 都会周期性出现。应对优先级：
1. **等** —— 错误文本里自带重置倒计时（`Resets in …`），也可以 `curl` 一下看哪个族先回来；
2. **降级** —— `omp` 自动 fallback 至 Gemini 3.8 Flash；pi/hermes/opencode 走各自 fallback；
3. **加号** —— 唯一线性扩容（`/root/cpa/account.sh add <email> <rt>`，见 §2.6）。

### 四、一键自检

```bash
omp models | head -20                                       # 通道 / 模型目录（含内置 provider）
omp config list | grep -iE 'modelRoles|fallback|Thinking'   # 角色与降级链
curl -s http://155.254.60.38/v1/models | head -c 200        # 网关连通性
omp -p --no-session "hi"                                    # 端到端（会自动降级）
```

---

## 11. 与 X 原帖方案对照（优势 / 劣势 / 待抄）— 2026-09-27

**对照对象**：[@riba2534/status/2097574464167027121](https://x.com/riba2534/status/2097574464167027121) 的 X Article《Google Gemini 3.8 Flash 低价反代账号池搭建教程》（2026-09-09）。
**原帖方案一句话**：买成品号（35 元/个，卡密自带 RT）→ Docker 起 `CLIProxyAPI + CPA-Manager-Plus + Caddy` → WARP 混淆出口 → `sensitive-words` 零宽字符破"假 429" → Claude Code 别名。自报 **24 号 / 43,216 次请求 / 成功率 99.88% / 缓存命中 95.1% / TTFT P50 3.36s**。

### 11.1 我们更强的地方（都有本机实测支撑）

| 维度 | 我们 | 原帖 |
|---|---|---|
| **出口冗余** | 2 条独立 WARP device + haproxy 聚合（`127.0.0.1:1080`），单条抖动不影响网关 | 单出口 |
| **磁盘事故复盘** | §2.12 完整根因链（请求体转储 32 MB × 无限增长 → 4.9 G 盘 100% → ext4 abort 只读）+ 永久加固清单 + `cpa-diskguard`/`cpa-memguard` | **完全未提** |
| **账号池运维** | `account.sh`（add/list/enable/disable，8 秒热加载）+ **逐号定向验证法**（临时 `prefix` + 管理计数器归因）+ **均衡量化**（12 次 → 6:6） | 批量导入 JSON + 看面板大盘；无可编程的逐号归因/均衡验证 |
| **配额经济性因果** | 单号每分钟 token 预算、omp 单轮 103 KB≈2.5 万 token、MCP 净增 32 KB 系统提示、`reasoning_effort` low/medium/high 的 token 与耗时、**粘滞 vs 轮询的取舍**（§2.6–2.8） | 只有集群汇总指标（TPS/缓存命中），没有"客户端怎么少烧额度"的因果分析 |
| **客户端覆盖** | omp / pi / opencode 三件套完整配置 + 验收 + **降级链**（`retry.fallbackChains`）+ 绝对压缩阈值（`thresholdTokens: 200000`）+ Claude Code（§5.3） | 只有 Claude Code 别名 |
| **多协议** | 同端口 OpenAI / Anthropic / Responses 三套 API 实测 200，并指出 `ANTHROPIC_BASE_URL` **不能带 `/v1`** 的坑（§5.3） | 只写 OpenAI 风格 `/v1/*` |
| **可复现性** | §2.13 换机 + §2.14 重装重建：分阶段脚本 + md5 校验 + 验收输出 | "把这段 Prompt 甩给 Agent"——不可审计、结果不可复现 |
| **成本结构** | 反代跑在已有 VPS 上、出口用免费 WARP | 同思路（买号成本双方都一样） |

### 11.2 我们更弱的地方（建议补）

| 缺口 | 影响 | 状态 / 补法 |
|---|---|---|
| **可用号 9 个（原帖 15–24）** | 单号 5 小时窗口 → 长会话仍可能周期性 429；按原帖建议还需再加 6–11 个 | ⏳ **部分缓解**。已从 6 扩至 9（2026-10-06），目标 15+；`import-cards.sh` 就绪随时批量导入 |
| ~~无 CPA-Manager-Plus 面板~~ | 缺 OAuth 网页补录、5h 滑动额度条 / 7 天配额 / 频次可视化 | ✅ **2026-09-27 已部署**：v1.14.1 原生二进制（**无需 docker**）→ `http://155.254.60.38:18317/management.html`，已完成首配（§12） |
| ~~缺批量卡密导入~~ | 卡密 `用户名----密码----2FA密钥----RT`，20 个号手工就是苦力 | ✅ **已实现** `import-cards.sh`：解析 → 写 auth → 逐个定向验证 → 失败自动 disable → 卡密台账（600）；已用合成卡密端到端跑通（§12） |
| ~~出口自愈 watchdog 缺失~~ | 隧道死了但端口仍监听时 haproxy 照样分流 → 请求进黑洞 | ✅ **已重建并演练**：`warp-watchdog.timer` + `hap-api.py` + admin socket；演练中"假后端"被自动摘除，聚合口从 2/6 恢复到 6/6（§2.5） |
| ~~管理密钥弱~~ | 旧 `Bearer admin` + `allow-remote: true` = 外网可拉 OAuth 文件 | ✅ **已轮换**为 32 位随机密钥（`/root/cpa/mgmt.key`，旧口令实测 401）。⏳ **仍待办**：管理 API（:80）与面板（:18317）依然公网可达 → 建议只放行自己的出口 IP 或改为 SSH 隧道访问 |
| **源站地区** | 原帖在东京（回国延迟低）；我们在马来西亚 | 出口走 WARP 后源站国别只影响时延；要极致延迟再迁东京 |

### 11.3 直接抄过来的硬货

1. **账号风控三铁律**：① 买来的号**只改 2FA、绝不改密码**（异地改密极易触发风控）；② 拿到 RT 就别再逐个网页登录（登录动作本身是风控信号）；③ RT 失效的号再手工网页补录。
2. **零宽字符破"假 429"**：请求里的 `"Claude Agent SDK"` 指纹会被 Google 拦成 429 —— 我们**已配同款** `antigravity.sensitive-words: ["Claude Agent SDK"]`（§1 的 config），可当"配置正确性"对照组。
3. **面板能力清单**（值得为它装面板）：OAuth 网页补录、凭证健康度、5 小时滑动额度条、7 天配额、请求频次 —— 正好补上"两个号被验证拦住时无面板可查"的痛。
4. **Claude Code 别名**：已实测可套用（§5.3），但**别抄 1M 上下文那段**。
5. **集群指标基线**（补齐号后的对照目标）：成功率 ≥99.8%、缓存命中 ≥90%、TTFT P50 ≤3.5 s（@18.8 万 token 输入）。

### 11.4 结论

- **架构上我们是原帖的超集**（出口有冗余与判据、有磁盘/内存自愈与事故复盘、有多客户端与三套 API、有可复现重建手册与可编程账号运维，现在**连面板也补齐了**）；原帖剩下的优势只有**号多**。
- **当前账号 9 个**，目标 15+。`import-cards.sh` 已就绪（§12.1），随时批量导入。

---

## 12. 运维手册（2026-09-27 起的新工具）

### 12.1 批量导入卡密 —— `/root/cpa/import-cards.sh`

```bash
# 卡密格式（每行一张，分隔符 ---- ；用户名非邮箱时自动补 @gmail.com）
#   用户名----密码----2FA密钥----Refresh Token

bash /root/cpa/import-cards.sh cards.txt                 # 导入 + 逐个定向验证
bash /root/cpa/import-cards.sh cards.txt --no-verify     # 只导入不验证
bash /root/cpa/import-cards.sh cards.txt --keep-failed   # 验证失败也保持 enabled（默认会自动 disable）
```

| 项 | 说明 |
|---|---|
| 产物 | `/opt/cpa/auths/antigravity-<email>.json`（600，网关 8 秒热加载）+ `/root/cpa/cards.tsv`（600 台账：email / 密码 / 2FA / 导入时间） |
| 验证法 | 逐号临时加 `"prefix"` → 打 `<prefix>/gemini-3.8-flash-high` → 读管理计数器归因（不依赖日志） |
| 判定 | `OK` / `VERIFY_REQUIRED`（Google 要验证）/ `QUOTA_429` / `FAIL_HTTP_xxx`；非 OK 默认 `disabled=true` |
| 退出码 | 非 0 = 有失败项（方便串 CI/脚本） |
| 演练结果 | 合成卡密：正常号 → **OK**（计数器 0→1）；坏 token → **FAIL_HTTP_400** 且自动 disabled；台账、清理均正常 |

⚠️ 同一 Google 账号重复导入会生成**两条** auth（网关按 token 认账号，不会去重）→ 别把同一张卡导两次。

### 12.2 面板 CPA-Manager-Plus

```bash
# 入口（需 Admin Key；浏览器里输一次即可）
http://155.254.60.38:18317/management.html
cat /root/cpamp-admin.key            # 面板 Admin Key

# 首次/重新配置（把面板接到网关；正常情况下已完成）
curl -s -X POST http://127.0.0.1:18317/setup \
  -H "Authorization: Bearer $(cat /root/cpamp-admin.key)" -H 'Content-Type: application/json' \
  -d "{\"cpaBaseUrl\":\"http://127.0.0.1\",\"cpaManagementKey\":\"$(cat /root/cpa/mgmt.key)\",\"pollIntervalMs\":30000,\"ensureUsageStatisticsEnabled\":true,\"requestMonitoringEnabled\":true}"

systemctl status cpa-manager-plus ; journalctl -u cpa-manager-plus -n 50
# 数据目录 /opt/cpamp/data（含加密用的 data.key —— 备份必须一起备）
```

面板能给到：凭证健康度 / OAuth 网页补录 / **5 小时滑动额度条** / 7 天配额 / 请求历史与成本 / 账号动作建议。当前状态：`configured:true, setupRequired:false`，可读 4 个账号。

### 12.3 密钥与自愈速查

| 文件 / 单元 | 用途 | 怎么读 |
|---|---|---|
| `/root/cpa/mgmt.key` | 网关管理 API 密钥 | `bash /root/cpa/account.sh key` |
| `/root/cpamp-admin.key` | 面板 Admin Key | `cat /root/cpamp-admin.key` |
| `/root/cpa/cards.tsv` | 卡密台账（含 2FA） | `column -t /root/cpa/cards.tsv` |
| `warp-watchdog.timer` | 出口自愈（每分钟） | `journalctl -t warp-watchdog -n 30` |
| `cpa-diskguard.timer` / `cpa-memguard.timer` | 磁盘 / 内存自愈 | `journalctl -t cpa-diskguard -t cpa-memguard` |

```bash
# 日常巡检一行
for u in cli-proxy-api cpa-manager-plus haproxy warp-proxy@1 warp-proxy@2 \
         cpa-diskguard.timer cpa-memguard.timer warp-watchdog.timer; do
  printf '%-22s %s\n' "$u" "$(systemctl is-active "$u")"; done
bash /root/cpa/account.sh list
python3 /usr/local/bin/hap-api.py 'show stat' | awk -F, '$1=="warp-socks"{print $2,$18}'
```


### 12.4 Refresh Token（RT）体检与失效处置

**RT 的用法**（Google OAuth 2.0 官方机制）—— 拿 RT 去 token 端点换取新的 `access_token`：

```http
POST https://oauth2.googleapis.com/token
client_id=<签发该 RT 的 OAuth client>
client_secret=<同一 client 的密钥>
refresh_token=1//0...
grant_type=refresh_token
```

四条实测要点：

| 规则 | 说明 |
|---|---|
| **RT 绑定签发它的 OAuth client** | 用别的 client 去换 → `invalid_grant`（"RT 没坏却用不了"的头号原因） |
| **必须 `access_type=offline`** | 授权时才下发 RT |
| **刷新不轮换** | 本池实测 7 个号全部 `no_rotation` ⇒ **重复导入同一 RT 不会互相作废** |
| **可被作废** | 卖家再次登录 / 改密 / 风控拦截都会让 RT 立即失效 |

网关内置的 Antigravity OAuth client：

```
1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com
```

**一键体检**（逐个直连 Google 校验池内全部 RT，输出 live / dead）：

```bash
python3 /root/rt_audit.py
```

**失效特征**：错误文本是 `"Bad Request"`，而**不是** `"Token has been expired or revoked"` ⇒ 该 RT 已被作废或不属于此 client，**服务器侧无解**。

**处置流程**：

```bash
python3 /root/rt_audit.py                       # 1) 找出 dead 的号
bash /root/cpa/account.sh disable <email>       # 2) 先停用，避免每轮重试白撞活号
# 3) 面板 →「OAuth 登录」→ Antigravity OAuth，用浏览器登录该号（2FA 密钥贴 2fa.show 取码）
bash /root/cpa/account.sh enable <email>        # 4) 补录完成后重新启用
```

**审计结果**：

| 日期 | 池内总数 | live | dead |
|---|---|---|---|
| 2026-10-06 | 9 | 7 | 2（`katesmith3181`、`jamesthompson5969`，已 `disable`）|
| 2026-10-07 | **10** | **8** | 2（同上）|

**新增号的正确导入流程（2026-10-07 固化）**：

```bash
# 1) 先验 RT（不要直接导入！）—— 直连 Google 换取 access_token
python3 /root/rt_check.py <email> '<rt>'    # 退出码 0 = LIVE，1 = DEAD
#    → LIVE 才继续；DEAD 直接找卖家，别污染号池

# 2) 导入 + 热加载
bash /root/cpa/account.sh add <email> '<rt>'

# 3) 验证：网关已刷出新 access_token 且无 invalid_grant/404
journalctl -u cli-proxy-api --since '2 minutes ago' | grep <email-prefix>

# 4) 冒烟
curl -s -m 60 http://127.0.0.1/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"claude-sonnet-4-6","messages":[{"role":"user","content":"hi"}],"max_tokens":4}'
```

> `/root/rt_check.py` 为**只读**校验工具（不带参数会打印用法），不会修改任何配置；
> 批量体检整池用 `python3 /root/rt_audit.py`。
