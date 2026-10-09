# HookCast-app
发布HookCast新版本。

## 这个仓库放什么

只放**发布清单**。源码在私有仓库，安装包本体在同仓的 Releases 资产里（不是仓库文件，也不进 git 历史）。客户端每小时读取 `<本仓 raw 根>/<线>/latest.json`，用随安装包发布的 `plugin-public.pem` 校验同级 `latest.sig`，通过后才按清单里的地址下载并做 SHA-256 校验。

```
releases/
  stable/            # 默认发布线，出厂配置指向这里
    latest.json      # 清单：版本、tag、文件名、大小、sha256、下载地址、发布时间、channel
    latest.sig       # 对 latest.json 原始字节做的 ECDSA P-256 签名（base64）
  gray-01/           # 客户或灰度专线：只切清单，包体可复用同一个 tag 的资产
```

## 规则

- **不要把安装包 commit 进来**：GitHub 拒绝单次 push 中超过 100 MB 的文件，raw 同样有 100 MB 上限，而 git 历史会永久占着这份体积。安装包一律传 Releases。
- **先传资产、再推清单**：清单一旦落地客户端就能看见新版本；反过来失败只会让发布线停在上一个版本，不会指向空文件。
- 清单的字节内容就是被签名的东西，`.gitattributes` 已关掉 `*.json` 与 `*.sig` 的换行改写，别改回 `text` 属性，否则客户端一律拒收。
- 清单里的 `kind` 固定为 `app`，与官方插件清单做域隔离：签过的插件清单当不了 App 清单，反之也一样。
- 客户端不含任何访问凭据，因此这个仓库与它的 Releases 必须公开可读。

## 客户端一侧

出厂配置 `update.channel = stable`，`update.base_url` 指向
`https://raw.githubusercontent.com/kukukikibear/HookCast-app/HEAD/releases`。
启动 30 秒后查一次，之后每小时一次；设置页任何时候也能手点「检查更新」。发现新版本只更新设置页那张卡片的状态，下载与安装都要用户手点，绝不静默覆盖。`raw.githubusercontent.com` 有缓存，推完清单客户端可能要等一个缓存周期才看到。

## 怎么发版

在发布机（持有签名私钥的那台）上：

```powershell
.\installer\publish-release.ps1                    # 用 VERSION 里的版本号发 stable
.\installer\publish-release.ps1 -Channel gray-01   # 发到灰度线
.\installer\publish-release.ps1 -DryRun            # 只生成清单，不上传、不推送
```

脚本负责：算 SHA256 → 传资产到 Releases → 验下载地址已通 → 生成并签名清单 → 提交并推送本仓。
