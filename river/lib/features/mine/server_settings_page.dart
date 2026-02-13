import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/config/server_config.dart';
import 'package:river/core/update/app_update_checker.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';

class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({
    super.key,
    required this.settingsController,
    required this.updateChecker,
  });

  final AppSettingsController settingsController;
  final AppUpdateChecker updateChecker;

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _updateUrlController;

  bool _savingBaseUrl = false;
  bool _savingUpdateUrl = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.settingsController.riverSideBaseUrl,
    );
    _updateUrlController = TextEditingController(
      text: widget.settingsController.updateManifestUrl,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _updateUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl() async {
    if (_savingBaseUrl) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _savingBaseUrl = true);
    try {
      final normalized = RiverServerConfig.normalizeBaseUrl(
        _baseUrlController.text,
      );
      await _validateForumBaseUrl(normalized);
      widget.settingsController.updateRiverSideBaseUrl(normalized);
      _baseUrlController.text = normalized;
      _showMessage('主域名已更新');
    } catch (error) {
      _showMessage('主域名校验失败：$error');
    } finally {
      if (mounted) {
        setState(() => _savingBaseUrl = false);
      }
    }
  }

  Future<void> _saveUpdateUrl() async {
    if (_savingUpdateUrl) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _savingUpdateUrl = true);
    try {
      final normalized = RiverServerConfig.normalizeUrl(
        _updateUrlController.text,
      );
      await _validateUpdaterUrl(normalized);
      widget.settingsController.updateUpdateManifestUrl(normalized);
      _updateUrlController.text = normalized;
      await widget.updateChecker.checkForUpdates(force: true);
      _showMessage('更新源已更新');
    } catch (error) {
      _showMessage('更新源校验失败：$error');
    } finally {
      if (mounted) {
        setState(() => _savingUpdateUrl = false);
      }
    }
  }

  Future<void> _restoreDefaultBaseUrl() async {
    _baseUrlController.text = RiverServerConfig.defaultBaseUrl;
    await _saveBaseUrl();
  }

  Future<void> _restoreDefaultUpdateUrl() async {
    _updateUrlController.text = RiverServerConfig.defaultUpdateManifestUrl;
    await _saveUpdateUrl();
  }

  Future<void> _validateForumBaseUrl(String baseUrl) async {
    final uri = Uri.parse('$baseUrl/about.json');
    final response = await http
        .get(uri, headers: const <String, String>{'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('返回格式异常');
    }
    if (decoded['about'] == null && decoded['stats'] == null) {
      throw const FormatException('不是有效的 Discourse 站点');
    }
  }

  Future<void> _validateUpdaterUrl(String updateUrl) async {
    final response = await http
        .get(
          Uri.parse(updateUrl),
          headers: const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('返回格式异常');
    }
    final version = (decoded['version'] ?? '').toString().trim();
    if (version.isEmpty) {
      throw const FormatException('缺少 version 字段');
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const MineSettingsAppBar(
        title: '服务器设置',
        subtitle: '主域名与更新源',
        icon: Icons.dns_outlined,
        heroTagPrefix: 'mine_settings_server',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SettingsSection(
            title: 'RiverSide 主域名',
            subtitle: '保存前会请求 /about.json 校验站点可用性',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '主域名',
                    hintText: 'https://river-side.cc',
                    prefixIcon: Icon(Icons.public_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _savingBaseUrl ? null : _restoreDefaultBaseUrl,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('恢复默认'),
                    ),
                    FilledButton.icon(
                      onPressed: _savingBaseUrl ? null : _saveBaseUrl,
                      icon: _savingBaseUrl
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: const Text('验证并保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: '版本更新链接',
            subtitle: '保存前会校验 updater.json 是否可用',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _updateUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: '更新链接',
                    hintText:
                        'https://gitee.com/hanversion/river-mobile-update/raw/master/updater.json',
                    prefixIcon: Icon(Icons.system_update_alt_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _savingUpdateUrl
                          ? null
                          : _restoreDefaultUpdateUrl,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('恢复默认'),
                    ),
                    FilledButton.icon(
                      onPressed: _savingUpdateUrl ? null : _saveUpdateUrl,
                      icon: _savingUpdateUrl
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: const Text('验证并保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: widget.settingsController,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前生效配置',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '主域名：${widget.settingsController.riverSideBaseUrl}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '更新源：${widget.settingsController.updateManifestUrl}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
