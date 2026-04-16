import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';

class RecommendationPayload {
  final List<Recipe> dishes;
  final List<Recipe> staples;
  final List<Recipe> legacyRecipes;
  final String agentNotes;
  final String recommendationMode;
  final String occasion;
  final int peopleCount;
  final String preferences;

  const RecommendationPayload({
    this.dishes = const [],
    this.staples = const [],
    this.legacyRecipes = const [],
    this.agentNotes = '',
    this.recommendationMode = 'hardcoded',
    this.occasion = '日常',
    this.peopleCount = 2,
    this.preferences = '',
  });

  Map<String, dynamic> toJson() => {
        'dishes': dishes.map((r) => r.toJson()).toList(),
        'staples': staples.map((r) => r.toJson()).toList(),
        'legacyRecipes': legacyRecipes.map((r) => r.toJson()).toList(),
        'agentNotes': agentNotes,
        'recommendationMode': recommendationMode,
        'occasion': occasion,
        'peopleCount': peopleCount,
        'preferences': preferences,
      };

  factory RecommendationPayload.fromJson(Map<String, dynamic> j) =>
      RecommendationPayload(
        dishes: (j['dishes'] as List? ?? [])
            .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        staples: (j['staples'] as List? ?? [])
            .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        legacyRecipes: (j['legacyRecipes'] as List? ?? [])
            .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        agentNotes: j['agentNotes'] as String? ?? '',
        recommendationMode: j['recommendationMode'] as String? ?? 'hardcoded',
        occasion: j['occasion'] as String? ?? '日常',
        peopleCount: j['peopleCount'] as int? ?? 2,
        preferences: j['preferences'] as String? ?? '',
      );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<Map<String, dynamic>> toolCalls;
  final RecommendationPayload? recommendation;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.toolCalls = const [],
    this.recommendation,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'toolCalls': toolCalls,
        if (recommendation != null) 'recommendation': recommendation!.toJson(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String? ?? '',
        isUser: j['isUser'] as bool? ?? false,
        toolCalls: (j['toolCalls'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        recommendation: j['recommendation'] == null
            ? null
            : RecommendationPayload.fromJson(
                Map<String, dynamic>.from(j['recommendation']),
              ),
      );
}

class ChatSession {
  String id;
  String name;
  List<ChatMessage> messages;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.name,
    required this.messages,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String,
        name: j['name'] as String,
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  static ChatSession newSession() => ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '新会话',
        messages: [
          const ChatMessage(
            text: '您好，我是您的私人饮食管家。您可以直接问我问题，也可以点“菜单推荐”让我帮您安排一餐。',
            isUser: false,
          ),
        ],
        updatedAt: DateTime.now(),
      );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _sending = false;
  String _sendingLabel = '管家正在思考...';
  bool _chatAgentMode = false;
  bool _showHistory = false;

  ChatSession _current = ChatSession.newSession();
  List<ChatSession> _sessions = [];

  static const _storageKey = 'chat_sessions';
  static final Map<String, List<dynamic>> _stepsCache = {};

  @override
  void initState() {
    super.initState();
    _sessions = [_current];
    _loadSessions();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final list = (jsonDecode(raw) as List)
          .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (!mounted) return;
      setState(() {
        _sessions = list.isEmpty ? [ChatSession.newSession()] : list;
        _current = _sessions.first;
      });
    } catch (_) {}
  }

  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_sessions.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }

  void _newSession() {
    final session = ChatSession.newSession();
    setState(() {
      _sessions.insert(0, session);
      _current = session;
      _showHistory = false;
    });
    _saveSessions();
    _scrollToBottom();
  }

  void _switchSession(ChatSession session) {
    setState(() {
      _current = session;
      _showHistory = false;
    });
    _scrollToBottom();
  }

  void _deleteSession(ChatSession session) {
    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
      if (_sessions.isEmpty) {
        _current = ChatSession.newSession();
        _sessions = [_current];
      } else if (_current.id == session.id) {
        _current = _sessions.first;
      }
    });
    _saveSessions();
  }

  Future<void> _renameSession(ChatSession session) async {
    final ctrl = TextEditingController(text: session.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (result == null || result.isEmpty) return;
    setState(() => session.name = result);
    _saveSessions();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    if (_current.messages.length == 1 && _current.name == '新会话') {
      setState(() {
        _current.name = text.length > 15 ? '${text.substring(0, 15)}…' : text;
      });
    }

    setState(() {
      _current.messages.add(ChatMessage(text: text, isUser: true));
      _current.updatedAt = DateTime.now();
      _sending = true;
      _sendingLabel = '管家正在思考...';
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final history = _current.messages
          .take(_current.messages.length - 1)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      if (_chatAgentMode) {
        if (apiKey == null || apiKey.isEmpty) {
          _appendAssistantMessage(
            const ChatMessage(
              text: '请先在设置页填写 API Key，才能使用 Agent 对话。',
              isUser: false,
            ),
          );
          return;
        }

        final weatherApiKey = await ApiConfig.getWeatherApiKey();
        final serperApiKey = await ApiConfig.getSerperApiKey();
        final data = await ApiService.post('/agent/chat', {
          'message': text,
          'history': history,
          'api_key': apiKey,
          if (aiBaseUrl != null && aiBaseUrl.isNotEmpty)
            'ai_base_url': aiBaseUrl,
          if (weatherApiKey != null && weatherApiKey.isNotEmpty)
            'weather_api_key': weatherApiKey,
          if (serperApiKey != null && serperApiKey.isNotEmpty)
            'serper_api_key': serperApiKey,
        });

        _appendAssistantMessage(
          ChatMessage(
            text: data['reply'] as String? ?? '抱歉，我暂时无法回答。',
            isUser: false,
            toolCalls: (data['tool_calls'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
          ),
        );
      } else {
        final data = await ApiService.post('/ai/chat', {
          'message': text,
          'history': history,
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
          if (aiBaseUrl != null && aiBaseUrl.isNotEmpty)
            'ai_base_url': aiBaseUrl,
        });

        _appendAssistantMessage(
          ChatMessage(
            text: data['reply'] as String? ?? '抱歉，我暂时无法回答。',
            isUser: false,
          ),
        );
      }
    } catch (e) {
      _appendAssistantMessage(ChatMessage(text: '出错了：$e', isUser: false));
    }
  }

  Future<void> _openRecommendSheet({
    RecommendationPayload? preset,
    bool withFeedback = false,
  }) async {
    String occasion = preset?.occasion ?? '日常';
    int people = preset?.peopleCount ?? 2;
    String mode = preset?.recommendationMode ?? 'hardcoded';
    final prefCtrl = TextEditingController(text: preset?.preferences ?? '');
    final feedbackCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                withFeedback ? '调整推荐条件' : '菜单推荐',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              mode == 'agent' ? 'Agent 模式' : '普通模式',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          withFeedback
                              ? '填写想调整的地方后重新推荐。'
                              : '按场景、人数和口味生成菜单。',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ChoicePill(
                              label: '普通模式',
                              selected: mode == 'hardcoded',
                              onTap: () => setSheetState(() => mode = 'hardcoded'),
                            ),
                            _ChoicePill(
                              label: 'Agent 模式',
                              selected: mode == 'agent',
                              onTap: () => setSheetState(() => mode = 'agent'),
                            ),
                            _ChoicePill(
                              label: '日常',
                              selected: occasion == '日常',
                              onTap: () => setSheetState(() => occasion = '日常'),
                            ),
                            _ChoicePill(
                              label: '外食',
                              selected: occasion == '外食',
                              onTap: () => setSheetState(() => occasion = '外食'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '用餐人数',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _CountButton(
                              icon: Icons.remove,
                              onTap: people > 1
                                  ? () => setSheetState(() => people--)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '$people',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _CountButton(
                              icon: Icons.add,
                              onTap: () => setSheetState(() => people++),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: prefCtrl,
                          decoration: const InputDecoration(
                            labelText: '偏好或限制',
                            hintText: '比如想吃牛肉、少油、控制热量',
                          ),
                          maxLines: 2,
                        ),
                        if (withFeedback) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: feedbackCtrl,
                            decoration: const InputDecoration(
                              labelText: '反馈',
                              hintText: '比如不要重复、想更清淡、主食换一下',
                            ),
                            maxLines: 3,
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: Icon(
                              withFeedback ? Icons.send_outlined : Icons.auto_awesome,
                            ),
                            label: Text(withFeedback ? '提交反馈并重新推荐' : '开始推荐'),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _requestRecommendation(
                                occasion: occasion,
                                peopleCount: people,
                                preferences: prefCtrl.text.trim(),
                                requestedMode: mode,
                                feedback: feedbackCtrl.text.trim(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    prefCtrl.dispose();
    feedbackCtrl.dispose();
  }

  Future<void> _requestRecommendation({
    required String occasion,
    required int peopleCount,
    required String preferences,
    required String requestedMode,
    String feedback = '',
  }) async {
    if (_sending) return;

    if (_current.messages.length == 1 && _current.name == '新会话') {
      setState(() => _current.name = '菜单推荐');
    }

    setState(() {
      _sending = true;
      _sendingLabel = '管家正在准备菜单...';
      _current.updatedAt = DateTime.now();
    });
    _scrollToBottom();

    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final imageApiKey = await ApiConfig.getImageApiKey();
      final imageBaseUrl = await ApiConfig.getImageBaseUrl();
      final weatherApiKey = await ApiConfig.getWeatherApiKey();
      final serperApiKey = await ApiConfig.getSerperApiKey();

      final canUseAgent =
          requestedMode == 'agent' && apiKey != null && apiKey.isNotEmpty;
      final usedMode = canUseAgent ? 'agent' : 'hardcoded';

      Map<String, dynamic> data;
      List<Map<String, dynamic>> toolCalls = [];
      String agentNotes = '';

      if (canUseAgent) {
        data = await ApiService.post('/agent/recommend', {
          'occasion': occasion,
          'people_count': peopleCount,
          'preferences': preferences,
          'api_key': apiKey,
          if (aiBaseUrl != null && aiBaseUrl.isNotEmpty)
            'ai_base_url': aiBaseUrl,
          if (imageApiKey != null && imageApiKey.isNotEmpty)
            'image_api_key': imageApiKey,
          if (imageBaseUrl != null && imageBaseUrl.isNotEmpty)
            'image_base_url': imageBaseUrl,
          if (weatherApiKey != null && weatherApiKey.isNotEmpty)
            'weather_api_key': weatherApiKey,
          if (serperApiKey != null && serperApiKey.isNotEmpty)
            'serper_api_key': serperApiKey,
        });
        toolCalls = (data['tool_calls'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        agentNotes = data['agent_notes'] as String? ?? '';
      } else {
        String nutritionAdvice = '';
        if (apiKey != null && apiKey.isNotEmpty) {
          try {
            final today = DateTime.now().toIso8601String().substring(0, 10);
            final profile = await ApiService.get('/user/profile');
            final adviceData = await ApiService.post('/ai/diet-advice', {
              'date': today,
              'cycle_days': profile['cycle_days'] ?? 7,
              'api_key': apiKey,
              if (aiBaseUrl != null && aiBaseUrl.isNotEmpty)
                'ai_base_url': aiBaseUrl,
            });
            nutritionAdvice = adviceData['advice'] as String? ?? '';
          } catch (_) {}
        }

        data = await ApiService.post('/recipes/recommend', {
          'occasion': occasion,
          'people_count': peopleCount,
          'preferences': preferences,
          'use_fridge': true,
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
          if (aiBaseUrl != null && aiBaseUrl.isNotEmpty)
            'ai_base_url': aiBaseUrl,
          if (imageApiKey != null && imageApiKey.isNotEmpty)
            'image_api_key': imageApiKey,
          if (imageBaseUrl != null && imageBaseUrl.isNotEmpty)
            'image_base_url': imageBaseUrl,
          'model': (apiKey != null && apiKey.isNotEmpty) ? 'claude' : 'mock',
          'feedback': feedback,
          'nutrition_advice': nutritionAdvice,
        });
      }

      final dishes = (data['dishes'] as List? ?? [])
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final staples = (data['staples'] as List? ?? [])
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final legacyRecipes = (data['recipes'] as List? ?? [])
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (dishes.isEmpty && staples.isEmpty && legacyRecipes.isEmpty) {
        throw Exception('没有拿到有效的推荐结果');
      }

      final recommendation = RecommendationPayload(
        dishes: dishes,
        staples: staples,
        legacyRecipes: legacyRecipes,
        agentNotes: agentNotes,
        recommendationMode: usedMode,
        occasion: occasion,
        peopleCount: peopleCount,
        preferences: preferences,
      );

      _appendAssistantMessage(
        ChatMessage(
          text: _buildRecommendationText(
            dishes: dishes,
            staples: staples,
            legacyRecipes: legacyRecipes,
            requestedMode: requestedMode,
            usedMode: usedMode,
          ),
          isUser: false,
          toolCalls: toolCalls,
          recommendation: recommendation,
        ),
      );
    } catch (e) {
      _appendAssistantMessage(ChatMessage(text: '推荐失败：$e', isUser: false));
    }
  }

  String _buildRecommendationText({
    required List<Recipe> dishes,
    required List<Recipe> staples,
    required List<Recipe> legacyRecipes,
    required String requestedMode,
    required String usedMode,
  }) {
    final parts = <String>[];
    if (dishes.isNotEmpty) parts.add('${dishes.length}道菜');
    if (staples.isNotEmpty) parts.add('${staples.length}个主食');
    if (legacyRecipes.isNotEmpty) parts.add('${legacyRecipes.length}道推荐');

    final modeText = usedMode == 'agent' ? 'Agent' : '普通';
    final modeFallback = requestedMode == 'agent' && usedMode != 'agent'
        ? '，当前按普通模式处理'
        : '';
    return '我为你整理了${parts.join('、')}。点菜品可查看图文步骤，点右上角加号可记入餐次。$modeText 模式已完成推荐$modeFallback。';
  }

  void _appendAssistantMessage(ChatMessage message) {
    if (!mounted) return;
    setState(() {
      _current.messages.add(message);
      _current.updatedAt = DateTime.now();
      _sending = false;
    });
    _saveSessions();
    _scrollToBottom();
  }

  Future<void> _openRecipeDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          stepsCache: _stepsCache,
        ),
      ),
    );
  }

  Future<void> _showLogRecipeDialog(Recipe recipe) async {
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealLabels = ['早餐', '午餐', '晚餐', '零食'];
    String mealType = 'lunch';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('记录这道菜'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mealType,
                decoration: const InputDecoration(
                  labelText: '餐次',
                  isDense: true,
                ),
                items: List.generate(
                  mealTypes.length,
                  (i) => DropdownMenuItem(
                    value: mealTypes[i],
                    child: Text(mealLabels[i]),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => mealType = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _logRecipeToMeal(recipe, mealType, today);
              },
              child: const Text('确认记录'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logRecipeToMeal(
    Recipe recipe,
    String mealType,
    String date,
  ) async {
    try {
      await ApiService.post('/nutrition/', {
        'date': date,
        'meal_type': mealType,
        'recipe_name': recipe.name,
        'calories': _nutritionValue(recipe.nutrition, 'calories'),
        'protein': _nutritionValue(recipe.nutrition, 'protein'),
        'carbs': _nutritionValue(recipe.nutrition, 'carbs'),
        'fat': _nutritionValue(recipe.nutrition, 'fat'),
        'fiber': _nutritionValue(recipe.nutrition, 'fiber'),
      });

      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      await ApiService.post('/ingredients/deduct', {
        'recipe_name': recipe.name,
        'ingredients': recipe.ingredients,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (aiBaseUrl != null && aiBaseUrl.isNotEmpty)
          'ai_base_url': aiBaseUrl,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已记录到${_mealLabel(mealType)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('记录失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _mealLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '零食';
      default:
        return mealType;
    }
  }

  double _nutritionValue(Map<String, dynamic> nutrition, String key) {
    final value = nutrition[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intro = _current.messages.length <= 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(_showHistory ? '历史会话' : '饮食管家'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _chatAgentMode ? '切换到普通模式' : '切换到 Agent 模式',
            onPressed: () => setState(() => _chatAgentMode = !_chatAgentMode),
            icon: Icon(
              _chatAgentMode
                  ? Icons.psychology_alt_outlined
                  : Icons.chat_bubble_outline,
            ),
          ),
          IconButton(
            tooltip: '新会话',
            onPressed: _newSession,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _showHistory = !_showHistory),
                          icon: Icon(
                            _showHistory ? Icons.chat_outlined : Icons.history,
                          ),
                          label: Text(_showHistory ? '回到聊天' : '历史会话'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _sending ? null : () => _openRecommendSheet(),
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('菜单推荐'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _chatAgentMode
                              ? Icons.auto_awesome
                              : Icons.forum_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _showHistory
                                ? '当前会话：${_current.name}'
                                : (_chatAgentMode
                                    ? '当前为 Agent 对话模式'
                                    : '当前为普通对话模式'),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _showHistory ? _buildHistoryPanel() : _buildChat(intro, theme),
            ),
            _ComposerBar(
              controller: _inputCtrl,
              sending: _sending,
              sendingLabel: _sendingLabel,
              onMenuTap: _sending ? null : () => _openRecommendSheet(),
              onSend: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPanel() {
    final sorted = [..._sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (sorted.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有历史会话'),
            ),
          )
        else
          ...sorted.map((session) {
            final isActive = session.id == _current.id;
            return _SessionCard(
              session: session,
              isActive: isActive,
              dateText: _formatDate(session.updatedAt),
              onTap: () => _switchSession(session),
              onRename: () => _renameSession(session),
              onDelete: () => _deleteSession(session),
            );
          }),
      ],
    );
  }

  Widget _buildChat(bool intro, ThemeData theme) {
    return Column(
      children: [
        if (intro)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '可以这样和我说',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text('• 帮我推荐一份适合晚餐的两人菜单'),
                    SizedBox(height: 4),
                    Text('• 今天吃得有点多，晚餐怎么安排轻一点？'),
                    SizedBox(height: 4),
                    Text('• 冰箱里有鸡蛋和番茄，能做什么？'),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _current.messages.length,
            itemBuilder: (_, index) => _Bubble(
              msg: _current.messages[index],
              onOpenRecipe: _openRecipeDetail,
              onLogRecipe: _showLogRecipeDialog,
              onRetryRecommendation: (recommendation) => _requestRecommendation(
                occasion: recommendation.occasion,
                peopleCount: recommendation.peopleCount,
                preferences: recommendation.preferences,
                requestedMode: recommendation.recommendationMode,
              ),
              onFeedbackRecommendation: (recommendation) => _openRecommendSheet(
                preset: recommendation,
                withFeedback: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatefulWidget {
  final ChatMessage msg;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<Recipe> onLogRecipe;
  final ValueChanged<RecommendationPayload> onRetryRecommendation;
  final ValueChanged<RecommendationPayload> onFeedbackRecommendation;

  const _Bubble({
    required this.msg,
    required this.onOpenRecipe,
    required this.onLogRecipe,
    required this.onRetryRecommendation,
    required this.onFeedbackRecommendation,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool _showTools = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.msg.isUser;
    final toolCalls = widget.msg.toolCalls;
    final recommendation = widget.msg.recommendation;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.84,
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.spa_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '饮食管家',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            if (!isUser && toolCalls.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _showTools = !_showTools),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.84),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 15,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '这一轮调用了 ${toolCalls.length} 个工具',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Icon(
                            _showTools ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (_showTools) ...[
                        const SizedBox(height: 8),
                        ...toolCalls.map((tc) => _ToolCallTile(tc: tc)),
                      ],
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primaryContainer.withOpacity(0.92)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(26),
                  topRight: const Radius.circular(26),
                  bottomLeft: Radius.circular(isUser ? 26 : 10),
                  bottomRight: Radius.circular(isUser ? 10 : 26),
                ),
                border: Border.all(
                  color: isUser
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.msg.text,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      height: 1.55,
                      fontSize: 14,
                    ),
                  ),
                  if (recommendation != null) ...[
                    const SizedBox(height: 12),
                    _RecommendationContent(
                      recommendation: recommendation,
                      onOpenRecipe: widget.onOpenRecipe,
                      onLogRecipe: widget.onLogRecipe,
                      onRetry: () => widget.onRetryRecommendation(recommendation),
                      onFeedback: () =>
                          widget.onFeedbackRecommendation(recommendation),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationContent extends StatelessWidget {
  final RecommendationPayload recommendation;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<Recipe> onLogRecipe;
  final VoidCallback onRetry;
  final VoidCallback onFeedback;

  const _RecommendationContent({
    required this.recommendation,
    required this.onOpenRecipe,
    required this.onLogRecipe,
    required this.onRetry,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final recipes = recommendation.legacyRecipes.isNotEmpty
        ? recommendation.legacyRecipes
        : [...recommendation.dishes, ...recommendation.staples];
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recommendation.agentNotes.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.55),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              recommendation.agentNotes,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        if (recommendation.dishes.isNotEmpty)
          _RecipeSection(
            title: '推荐菜品',
            recipes: recommendation.dishes,
            onOpenRecipe: onOpenRecipe,
            onLogRecipe: onLogRecipe,
          ),
        if (recommendation.staples.isNotEmpty) ...[
          const SizedBox(height: 10),
          _RecipeSection(
            title: '推荐主食',
            recipes: recommendation.staples,
            onOpenRecipe: onOpenRecipe,
            onLogRecipe: onLogRecipe,
          ),
        ],
        if (recommendation.legacyRecipes.isNotEmpty)
          _RecipeSection(
            title: '推荐结果',
            recipes: recipes,
            onOpenRecipe: onOpenRecipe,
            onLogRecipe: onLogRecipe,
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重新推荐'),
            ),
            OutlinedButton.icon(
              onPressed: onFeedback,
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text('告诉管家怎么改'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecipeSection extends StatelessWidget {
  final String title;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<Recipe> onLogRecipe;

  const _RecipeSection({
    required this.title,
    required this.recipes,
    required this.onOpenRecipe,
    required this.onLogRecipe,
  });

  double _nutritionValue(Map<String, dynamic> nutrition, String key) {
    final value = nutrition[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...recipes.map(
          (recipe) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onOpenRecipe(recipe),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RecipePreviewImage(recipe: recipe),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _InfoBadge(
                                          text:
                                              '${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal',
                                          icon: Icons.local_fire_department_outlined,
                                        ),
                                        _InfoBadge(
                                          text: '${recipe.timeMinutes} 分钟',
                                          icon: Icons.schedule_outlined,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '加入餐次',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onLogRecipe(recipe),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                          if (recipe.ingredients.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              recipe.ingredients.take(4).join('、'),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '点击查看图文步骤',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecipePreviewImage extends StatefulWidget {
  final Recipe recipe;

  const _RecipePreviewImage({required this.recipe});

  @override
  State<_RecipePreviewImage> createState() => _RecipePreviewImageState();
}

class _RecipePreviewImageState extends State<_RecipePreviewImage> {
  String? _proxyUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final imageUrl = widget.recipe.previewImageUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _setProxyUrl(imageUrl);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setProxyUrl(String originalUrl) async {
    final base = await ApiConfig.getBaseUrl();
    final encoded = Uri.encodeComponent(originalUrl);
    if (mounted) {
      setState(() => _proxyUrl = '$base/ai/image-proxy?url=$encoded');
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: 96,
        height: 96,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _proxyUrl != null
            ? Image.network(
                _proxyUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(context),
              )
            : _loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.restaurant,
          size: 24,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(height: 6),
        Text(
          '成品图',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ToolCallTile extends StatelessWidget {
  final Map<String, dynamic> tc;
  const _ToolCallTile({required this.tc});

  static const _toolIcons = {
    'get_fridge_contents': Icons.kitchen_outlined,
    'get_nutrition_history': Icons.bar_chart_outlined,
    'get_user_memory': Icons.psychology_outlined,
    'update_user_preference': Icons.edit_outlined,
    'log_meal': Icons.add_circle_outline,
    'calculate_nutrition': Icons.calculate_outlined,
    'explain_recommendation': Icons.lightbulb_outline,
    'detect_conflict': Icons.warning_amber_outlined,
  };

  static const _toolNames = {
    'get_fridge_contents': '查冰箱',
    'get_nutrition_history': '查营养历史',
    'get_user_memory': '读取记忆',
    'update_user_preference': '更新偏好',
    'log_meal': '记录餐食',
    'calculate_nutrition': '估算营养',
    'explain_recommendation': '解释推荐',
    'detect_conflict': '检测冲突',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = tc['tool'] as String? ?? '';
    final result = tc['result'] is Map<String, dynamic>
        ? tc['result'] as Map<String, dynamic>
        : <String, dynamic>{};
    final icon = _toolIcons[name] ?? Icons.build_outlined;
    final label = _toolNames[name] ?? name;

    String summary = '';
    if (name == 'get_fridge_contents') {
      summary = '${result['count'] ?? 0} 种食材';
    } else if (name == 'get_nutrition_history') {
      final avg = (result['avg_calories_per_day'] as num?)?.toDouble() ?? 0;
      summary =
          '${result['total_days_recorded'] ?? 0} 天记录，日均 ${avg.toStringAsFixed(0)} kcal';
    } else if (name == 'get_user_memory') {
      final weights = (result['taste_weights'] as Map?)?.length ?? 0;
      summary = '$weights 个口味标签，${result['feedback_count'] ?? 0} 条反馈';
    } else if (name == 'update_user_preference') {
      final changes = result['changes'] as List? ?? [];
      summary = changes.isNotEmpty ? changes.first.toString() : '已更新';
    } else if (name == 'log_meal') {
      summary = '已记录 ${result['logged'] ?? ''}';
    } else if (name == 'calculate_nutrition') {
      summary = '${result['calories'] ?? 0} kcal';
    } else if (name == 'detect_conflict') {
      summary = result['has_conflict'] == true
          ? '发现 ${(result['conflicts'] as List?)?.length ?? 0} 个冲突'
          : '无冲突';
    } else if (name == 'explain_recommendation') {
      summary = result['dish'] as String? ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '→ $summary',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final String dateText;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.isActive,
    required this.dateText,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isActive ? Icons.chat : Icons.chat_bubble_outline,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          session.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${session.messages.length - 1}条消息 · $dateText'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') onRename();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('重命名')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final String sendingLabel;
  final VoidCallback? onMenuTap;
  final VoidCallback? onSend;

  const _ComposerBar({
    required this.controller,
    required this.sending,
    required this.sendingLabel,
    required this.onMenuTap,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sendingLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onMenuTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '问我任何饮食问题...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend?.call(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onSend,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoBadge({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withOpacity(0.22)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CountButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Icon(icon, size: 18, color: theme.colorScheme.primary),
      ),
    );
  }
}
