# MiniApp 开发与发布流程

## 开发

1. 在 `miniapps/<your_app>/` 开发页面。
2. 使用桥接口（`window.RiverMiniApp.call`）调试能力。
3. 本地启动服务：
   - `python server.py --host 0.0.0.0 --port 8765`

### 脚手架项目导入（Vue/React）

如果是独立 Vue/React 脚手架项目，推荐用一键导入：

```powershell
python .\tools\import_scaffold_app.py --project D:\code\my-vue --app-id demo.my_vue --name "Vue 示例"
```

导入脚本会自动执行：

- 构建脚手架产物
- 拷贝到 `miniapps/<target>`
- 更新 `miniapps.json`
- 调用打包与校验脚本

## 打包

运行：

```powershell
python .\tools\build_packages.py
```

作用：

- 自动将 `miniapps/<app_dir>` 打成 `packages/<app_id>.zip`
- 自动更新 `package_url`、`package_sha256`
- 更新时间戳 `updated_at`

## 校验

运行：

```powershell
python .\tools\validate_manifest.py
```

校验：

- 字段完整性
- SemVer 版本
- ID 唯一性
- 本地资源存在性
- 包内容与 SHA256

## 发布

1. 提交 `miniapps.json`
2. 提交 `packages/*.zip`
3. 更新服务端
4. 客户端刷新清单后可安装/升级

## 一键流水线

```powershell
python .\tools\release_manifest.py --bump patch
```

- 自动递增 `miniapps.json.version`
- 自动打包全部小程序
- 自动校验清单和包完整性
