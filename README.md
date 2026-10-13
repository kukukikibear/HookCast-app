# HookCast-app
发布HookCast新版本。

## 这个仓库放什么

只放**发布清单**。源码在私有仓库，安装包本体在同仓的 Releases 资产里（不是仓库文件，也不进 git 历史）。客户端每小时通过 `api.github.com` 的 contents 端点读取 `<清单根>/<线>/latest.json`，用随安装包发布的 `plugin-public.pem` 校验同级 `latest.sig`，通过后才按清单里的地址下载并做 SHA-256 校验。

```
releases/
  stable/            # 默认发布线，出厂配置指向这里
    latest.json      # 清单：版本、tag、文件名、大小、sha256、下载地址、发布时间、channel
    latest.sig       # 对 latest.json 原始字节做的 ECDSA P-256 签名（base64）
  gray-01/           # 客户或灰度专线：只切清单，包体可复用同一个 tag 的资产
```

## 规则

- **不要把安装包 commit 进来**：GitHub 拒绝单次 push 中超过 100 MB 的文件，git 历史还会永久占着这份体积。安装包一律传 Releases。
- **先传资产、再推清单**：清单一旦落地客户端就能看见新版本；反过来失败只会让发布线停在上一个版本，不会指向空文件。
- **清单的 `url` 写 API 资产地址**（`https://api.github.com/repos/<仓名>/releases/assets/<ID>`），不写 `browser_download_url`：`github.com:443` 在部分网络被直接拒连，装好的客户端就打不开包，而 `api.github.com` 可达并会 302 到真正发字节的 CDN。资产 `ID` 只有 Releases API 给得出，而**重传资产会换 ID**，所以每次替换包后都必须重跑发布脚本重签清单。
- 清单的字节内容就是被签名的东西，`.gitattributes` 已关掉 `*.json` 与 `*.sig` 的换行改写，别改回 `text` 属性，否则客户端一律拒收。
- 清单里的 `kind` 固定为 `app`，与官方插件清单做域隔离：签过的插件清单当不了 App 清单，反之也一样。
- 客户端不含任何访问凭据，因此这个仓库与它的 Releases 必须公开可读。

## 客户端一侧

发布线是编译进程序的常量，不在客户端的 `config.yaml` 里：`config.DefaultUpdateChannel = stable`，`config.DefaultUpdateBaseURL` 指向
`https://api.github.com/repos/kukukikibear/HookCast-app/contents/releases`。
实例侧读不到也改不动，因此给客户单独一条线要出专门的包（改常量重新发版），列 `-Channel` 只是把清单推到那个目录名上。
启动 30 秒后查一次，之后每小时一次；设置页任何时候也能手点「检查更新」。发现新版本只更新设置页那张卡片的状态，下载与安装都要用户手点，绝不静默覆盖。清单端点走 `api.github.com`，缓存是 60 秒级的私有缓存，推完清单几乎下一轮就能读到；匿名调用受 60 次/小时/IP 的限速约束，一台实例每小时两次取数远用不完，同一出口 IP 后面挂几十台时才会碰到，那种规模请切自己的专线。

## 怎么发版

在发布机（持有签名私钥的那台）上：

```powershell
.\installer\publish-release.ps1                    # 用 VERSION 里的版本号发 stable
.\installer\publish-release.ps1 -Channel gray-01   # 发到灰度线
.\installer\publish-release.ps1 -DryRun            # 只生成清单，不上传、不推送
```

脚本负责：算 SHA256 → 传资产到 Releases → 由 `cmd/publisher` 按包名从 Releases API 认回资产 `ID` 并拼出下载地址 → 验这个地址真能下到字节 → 生成并签名清单 → 提交并推送本仓。读 `ID` 与探测地址都在 `cmd/publisher` 的 Go 代码里完成，所以只有负责上传资产的 `installer\publish-release.ps1` 需要机器上有 `gh`；`publish-line.bat` 不上传任何东西，只用 `go` 和 `git`。

`publish-line.bat` 不在本仓，本仓只收清单：那个双击入口归源码仓的 `tools\publish-line.bat`。它按上一级关系找源码仓（不一致时设 `HC_SOURCE_ROOT`），把参数转给 `installer\publish-release.ps1 -SkipUpload`，并约定分发仓克隆放在源码仓的 `tools\HookCast-app\`，缺失时自己 `git clone` 本仓。整目录被源码仓 `.gitignore` 排除是硬性前提：带 `.git` 的目录父仓根本不收录（`git add -f` 会静默成功而什么都不记），所以入口与本克隆不能同处一个路径。前置检查、清单签名与提交推送都只有那份 ps1 一处实现，入口里不再重复一套（版本号也只认源码仓根的 `VERSION`，清单点名要 `release\HookCast-setup-<VERSION>.exe`）。签名私钥的存放位置与缺失时的提示口径见源码仓 README 的「发布新版本（发布机）」。用法：`publish-line.bat`（stable）、`publish-line.bat beta`、`publish-line.bat stable dry`（只出清单不提交）。
