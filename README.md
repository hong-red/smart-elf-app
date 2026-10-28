# 妙文 App（Flutter 原生安卓客户端）

面向小白的公众号文章生成器移动端。原生 Flutter 界面，配合托管版后端
[`Article-Agent-App`](https://github.com/hong-red/Article-Agent-App)（FastAPI）使用。

> **妙文系列** · 一套由 DeepSeek 驱动的「公众号文章生成器」，由三个仓库协作组成：
> [**🌐 网页版 `Article-Agent`**](https://github.com/hong-red/Article-Agent)（自托管后端 + 网页）
> · [**☁️ 托管版 `Article-Agent-App`**](https://github.com/hong-red/Article-Agent-App)（多用户后端 + PWA）
> · [**📱 安卓客户端 `smart-elf-app`**](https://github.com/hong-red/smart-elf-app)（Flutter 原生 App）

| 仓库 | 定位 | 面向 | 部署 | 鉴权 | 数据 |
| --- | --- | --- | --- | --- | --- |
| **网页版** [`Article-Agent`](https://github.com/hong-red/Article-Agent) | 自托管网页工具 | 技术用户 | 用户自己一键部署 | 访问口令 | 本地 |
| **托管版** [`Article-Agent-App`](https://github.com/hong-red/Article-Agent-App) | 多用户后端 + PWA | 小白用户 | 托管方部署 | 账号 + 邀请码 | 服务端（加密，按用户隔离） |
| **安卓客户端** [`smart-elf-app`](https://github.com/hong-red/smart-elf-app) | Flutter 原生 App | 手机用户 | 安装 APK | 账号 + 邀请码 | 复用托管版后端 |

> **一句话关系**：**网页版是能力母体**（四步生成 + 推送的完整实现）；**托管版**在其之上增加
> 登录 / 邀请码 / 密钥加密 / 多用户隔离 / 数据导出，把同一套接口做成多人服务；
> **安卓客户端**则是连接托管版后端的 Flutter 原生外壳。

---

## 功能

- **登录 / 注册**（邀请码制，注册需有效邀请码）
- **四步生成**：选题 → 成文 → 选图（本地上传 + 全网搜索）→ 排版（配色/语气/导语/金句/引导关注）
- **本地库**：保存 / 载入 / 删除文章
- **设置**：DeepSeek Key、公众号 AppID/AppSecret（加密存后端）
- **导出数据**：一键复制全部文章为 JSON

## 使用说明

1. **注册**：打开 App → 切到「注册」→ 填用户名、密码（≥6 位）、邀请码 → 注册 → 登录。
2. **设置**：右上角「设置」填 DeepSeek API Key（必填）、公众号 AppID/AppSecret（推送草稿箱才需要）、后端地址（默认 `http://81.70.191.44:8001`）。
3. **选题**：输入主题 → 选写作模板 / 风格 / 补充说明 / 数量 → 生成题目 → 选一个。
4. **成文**：生成正文，可反复「按意见重写」。
5. **选图**：本地上传 或 全网搜索，选中配图。
6. **排版**：配色 / 语气 / 导语 / 金句 / 引导关注 → 格式优化 → 保存或推送到草稿箱。

## 推送草稿箱前的准备（重要）

- 公众号需是**认证公众号**，且已配置 AppID / AppSecret。
- 把**后端服务器的公网 IP** 加入公众号「IP 白名单」：`mp.weixin.qq.com` → 设置与开发 → 基本配置 → IP 白名单。
- 推送需要一张封面图（可不上传，用默认封面）。

## 免费期

免费期至 **2026-12**（占位，改后端 `config.py` 的 `FREE_UNTIL`）。到期后可「导出数据」自行迁移。

## 构建 APK

```bash
# 需 Flutter 3.x + JDK 17 + Android SDK
flutter pub get
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

## 后端

本 App 的后端是 [`Article-Agent-App`](https://github.com/hong-red/Article-Agent-App)（FastAPI 多用户版），
默认地址 `http://81.70.191.44:8001`（App 设置里可改）。该后端的生成能力来源于网页版
[`Article-Agent`](https://github.com/hong-red/Article-Agent)。

## 相关仓库

- **[`Article-Agent-App`](https://github.com/hong-red/Article-Agent-App)**：托管版后端 + PWA（本 App 默认连接的服务端）。
- **[`Article-Agent`](https://github.com/hong-red/Article-Agent)**：网页版（自托管，能力母体）。
