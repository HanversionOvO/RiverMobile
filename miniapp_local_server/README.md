# River Mini App Local Server

## 1. 启动本地服务

```powershell
python .\miniapp_local_server\server.py --host 0.0.0.0 --port 8765
```

## 2. 可用接口

- Manifest: `http://127.0.0.1:8765/miniapps.json`
- Health: `http://127.0.0.1:8765/health`
- App list: `http://127.0.0.1:8765/api/miniapps/list`
- Search: `http://127.0.0.1:8765/api/miniapps/search?q=示例`
- Detail: `http://127.0.0.1:8765/api/miniapps/local.hello`
- Package: `http://127.0.0.1:8765/packages/local.hello.zip`

## 3. 目录与规范

- 规范文档：`miniapp_local_server/docs/MINIAPP_SPEC.md`
- 发布流程：`miniapp_local_server/docs/RELEASE_FLOW.md`
- 小程序源码：`miniapp_local_server/miniapps/`
- 小程序发布包：`miniapp_local_server/packages/`
- 清单文件：`miniapp_local_server/miniapps.json`

## 4. 开发/打包/校验

```powershell
python .\miniapp_local_server\tools\build_packages.py
python .\miniapp_local_server\tools\validate_manifest.py
```

## 4.1 脚手架项目一键导入（Vue/React）

从 Vue/React 脚手架项目执行构建，然后自动导入到 `miniapps/`、更新 `miniapps.json`、再打包校验：

```powershell
python .\miniapp_local_server\tools\import_scaffold_app.py `
  --project D:\code\my-vue-app `
  --app-id demo.my_vue_app `
  --name "我的 Vue 小程序" `
  --framework vue `
  --icon-file .\public\icon.png `
  --description "Vue 脚手架一键导入示例" `
  --tags Vue,工具
```

React 示例：

```powershell
python .\miniapp_local_server\tools\import_scaffold_app.py `
  --project D:\code\my-react-app `
  --app-id demo.my_react_app `
  --name "我的 React 小程序" `
  --framework react `
  --icon-file .\public\icon.png `
  --description "React 脚手架一键导入示例" `
  --tags React,工具
```

PowerShell 快捷方式：

```powershell
.\miniapp_local_server\tools\import_vue.ps1 -Project D:\code\my-vue-app -AppId demo.my_vue -Name "我的 Vue 小程序"
.\miniapp_local_server\tools\import_react.ps1 -Project D:\code\my-react-app -AppId demo.my_react -Name "我的 React 小程序"
```

常用参数：

- `--skip-build`：跳过构建，仅导入已生成产物
- `--dist-dir`：手动指定构建产物目录（默认自动识别 Vue/React）
- `--build-command`：自定义构建命令（默认自动使用 `npm|pnpm|yarn run build`）
- `--skip-package`：导入后不执行打包和校验

## 5. 一键发布流程

自动执行：清单版本递增 -> 打包 -> 校验

```powershell
python .\miniapp_local_server\tools\release_manifest.py --bump patch
```

可选参数：

- `--bump major|minor|patch`：选择版本递增级别
- `--no-bump`：不改版本，仅执行打包+校验

## 6. 示例小程序

当前内置：

- `local.hello`
- `local.vue_demo`（Vue 3）
- `local.react_demo`（React 18）

说明：

- `miniapps.json` 支持相对路径，服务端会转换成绝对 URL。
- Vue/React 示例使用 CDN 运行，便于快速联调 Bridge 能力。

## 7. 小程序脚手架命令（新增）

仓库已内置 `create-river-miniapp`（支持 html/vue/react 模板）。

首次本地启用命令：

```powershell
cd .\create-river-miniapp
npm link
```

创建项目：

```powershell
create-river-miniapp my-miniapp
create-river-miniapp my-miniapp --template vue
create-river-miniapp my-miniapp --template react
```

无交互模式：

```powershell
create-river-miniapp my-miniapp --template html --id local.my_miniapp --name "我的小程序" --yes
```
