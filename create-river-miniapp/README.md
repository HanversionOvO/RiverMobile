# create-river-miniapp

River 小程序脚手架，支持 `html` / `vue` / `react` 三种模板，并内置构建与打包脚本。

## 使用

```bash
npx create-river-miniapp my-miniapp
```

或指定模板：

```bash
npx create-river-miniapp my-miniapp --template vue
npx create-river-miniapp my-miniapp --template react
```

无交互模式：

```bash
npx create-river-miniapp my-miniapp --template html --id local.my_miniapp --name "我的小程序" --yes
```

## 生成项目常用命令

```bash
npm install
npm run dev
npm run build
npm run package:miniapp
```

`npm run package:miniapp` 会输出：

- `miniapp_output/packages/<app_id>.zip`
- `miniapp_output/miniapps.partial.json`

可将 `miniapps.partial.json` 的条目合并到你的 `miniapps.json` 中。
