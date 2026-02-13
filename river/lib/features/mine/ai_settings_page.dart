import 'package:flutter/material.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/ai/river_ai_service.dart';
import 'package:river/core/config/server_config.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _systemPromptController;

  late AppAiProvider _provider;
  late double _temperature;
  bool _obscureApiKey = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.settingsController;
    _provider = settings.aiProvider;
    _temperature = settings.aiTemperature;
    _baseUrlController = TextEditingController(text: settings.aiBaseUrl);
    _modelController = TextEditingController(text: settings.aiModel);
    _apiKeyController = TextEditingController(text: settings.aiApiKey);
    _systemPromptController = TextEditingController(text: settings.aiSystemPrompt);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final baseUrl = RiverServerConfig.normalizeUrl(_baseUrlController.text);
      final model = _modelController.text.trim();
      final apiKey = _apiKeyController.text.trim();
      final systemPrompt = _systemPromptController.text.trim();
      if (model.isEmpty) {
        throw const FormatException('模型不能为空');
      }
      widget.settingsController.updateAiProvider(_provider);
      widget.settingsController.updateAiBaseUrl(baseUrl);
      widget.settingsController.updateAiModel(model);
      widget.settingsController.updateAiApiKey(apiKey);
      widget.settingsController.updateAiSystemPrompt(systemPrompt);
      widget.settingsController.updateAiTemperature(_temperature);
      _showSnack('AI 设置已保存');
    } catch (error) {
      _showSnack('保存失败：$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (_testing) {
      return;
    }
    await _save();
    if (!mounted) {
      return;
    }
    setState(() => _testing = true);
    try {
      final service = RiverAiService(widget.settingsController);
      final result = await service.generate(
        instruction: '请只输出“连接成功”四个字',
        currentText: '',
      );
      if (!mounted) {
        return;
      }
      final display = result.length > 28
          ? '${result.substring(0, 28)}...'
          : result;
      _showSnack('连接成功：$display');
    } catch (error) {
      _showSnack('连接失败：$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  void _applyProviderPreset(AppAiProvider provider) {
    setState(() {
      _provider = provider;
      if (provider == AppAiProvider.deepseek) {
        _baseUrlController.text = AppSettingsController.defaultAiBaseUrl;
        _modelController.text = AppSettingsController.defaultAiModel;
      }
    });
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MineSettingsAppBar(
        title: 'AI设置',
        subtitle: '服务商与模型配置',
        icon: Icons.auto_awesome_rounded,
        heroTagPrefix: 'mine_settings_ai',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SettingsSection(
            title: '服务配置',
            subtitle: '支持 DeepSeek 与 OpenAI-Compatible 网关',
            child: Column(
              children: [
                DropdownButtonFormField<AppAiProvider>(
                  initialValue: _provider,
                  decoration: const InputDecoration(
                    labelText: '服务商',
                    prefixIcon: Icon(Icons.hub_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AppAiProvider.deepseek,
                      child: Text('DeepSeek'),
                    ),
                    DropdownMenuItem(
                      value: AppAiProvider.openAiCompatible,
                      child: Text('OpenAI Compatible'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _applyProviderPreset(value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '接口地址',
                    hintText: 'https://api.deepseek.com/v1/chat/completions',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    hintText: 'deepseek-chat',
                    prefixIcon: Icon(Icons.memory_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      tooltip: _obscureApiKey ? '显示' : '隐藏',
                      onPressed: () {
                        setState(() => _obscureApiKey = !_obscureApiKey);
                      },
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: '生成参数',
            subtitle: '系统提示词与生成温度',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _systemPromptController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '系统提示词',
                    prefixIcon: Icon(Icons.psychology_alt_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '温度 ${_temperature.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _temperature,
                  min: 0,
                  max: 2,
                  divisions: 40,
                  label: _temperature.toStringAsFixed(2),
                  onChanged: (value) => setState(() => _temperature = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('保存配置'),
                ),
              ),
            ],
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
