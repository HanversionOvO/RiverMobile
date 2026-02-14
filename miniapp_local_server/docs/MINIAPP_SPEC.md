# River MiniApp 规范（v1）

## 1. 目录约定

- 小程序源码：`miniapps/<app_folder>/`
- 发布包：`packages/<app_id>.zip`
- 清单：`miniapps.json`

建议每个小程序目录至少包含：

- `index.html`（入口）
- `icon.(png|jpg|webp)`（图标）

## 2. 清单字段规范

`miniapps.json` 顶层：

- `version`：清单版本（SemVer）
- `updated_at`：UTC 时间（ISO8601）
- `apps`：小程序列表

`apps[]` 推荐字段：

- `id`：唯一标识，建议 `org.name` 形式
- `name`：显示名称
- `version`：小程序版本（SemVer）
- `url`：入口 URL（推荐相对路径）
- `icon`：图标 URL（推荐相对路径）
- `package_url`：安装包 URL（推荐相对路径）
- `package_sha256`：安装包 SHA256（可选但强烈建议）
- `description`：描述
- `requires_auth`：是否需要登录态
- `enabled`：是否启用
- `order`：排序权重（越小越靠前）
- `bridge_version`：桥版本
- `tags`：标签数组

## 3. 版本策略

- 修复类改动：`PATCH`（x.y.Z）
- 兼容功能新增：`MINOR`（x.Y.0）
- 不兼容改动：`MAJOR`（X.0.0）

每次发布建议：

1. 升级 `apps[i].version`
2. 重新打包 zip
3. 计算并更新 `package_sha256`
4. 更新 `updated_at`

## 4. 更新策略

- 客户端读取清单后，比较本地安装版本与清单版本。
- 若版本更高且 `package_sha256` 变化，触发更新下载。
- 下载后先校验 SHA256，再替换本地安装目录。
- 安装失败保留旧版本，避免“白屏更新”。

## 5. 安全建议

- 仅允许白名单域名清单源。
- 强制 HTTPS（开发环境可放开）。
- 安装包必须校验 `package_sha256`。
- 建议后续引入签名字段（如 `signature`）做二次校验。

