import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:expense_tracker/services/ai_service.dart';
import 'package:expense_tracker/services/chatbot_tools.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/screens/subscriptions/subscriptions_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:expense_tracker/utils/currency_symbol.dart';

class ChatbotScreen extends StatefulWidget {
  final int profileId;
  final VoidCallback onDataChanged;
  final bool isVisible;

  const ChatbotScreen({
    super.key,
    required this.profileId,
    required this.onDataChanged,
    required this.isVisible,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> _chatMessages = <Map<String, dynamic>>[];
  final Set<int> _expandedToolMessages = {};
  bool _isLoading = false;
  AIService? _aiService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isSpeaking = false;
  bool _isRecording = false;
  bool _isMuted = true;
  bool _providerApproved = false;
  bool _reviewOpen = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      debugPrint("Audio Player: Playback Complete");
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint("Audio Player State: $state");
      if (mounted &&
          (state == PlayerState.completed ||
              state == PlayerState.stopped ||
              state == PlayerState.paused)) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text, String? audioPath}) async {
    final message = text ?? _controller.text.trim();
    if (_isLoading || (message.isEmpty && audioPath == null)) return;

    setState(() => _isLoading = true);
    final profileId = widget.profileId;
    bool isCurrent() => mounted && widget.profileId == profileId;
    var failure = 'Unable to complete the chat request. Please try again.';
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = _aiService ?? await AIService.fromPrefs(prefs);
      if (!isCurrent()) return;
      if (!service.isConfigured) {
        failure = 'Configure your AI provider in AI Settings to use chat.';
        throw StateError('AI provider is unconfigured');
      }
      _aiService = service;
      if (!_providerApproved) {
        final usesGemini = service.provider == 'gemini';
        final provider = usesGemini
            ? 'Gemini'
            : 'your OpenAI-compatible provider';
        final approved = await _confirm(
          title: 'Share data with $provider?',
          message: usesGemini
              ? 'Gemini receives your messages, voice recordings, and financial data used to answer your requests. If you unmute chat, Google Cloud Text-to-Speech receives the replies for playback.'
              : 'Your provider receives your messages and financial data used to answer your requests. If you unmute chat, the same provider receives the replies for playback.',
          action: 'Continue',
        );
        if (!isCurrent() || !approved) return;
        _providerApproved = true;
      }
      if ((prefs.getInt(PrefKeys.profileId) ?? 0) != profileId) return;

      setState(() {
        _chatMessages.add({
          'role': 'user',
          'content': audioPath == null ? message : 'Voice message',
        });
        if (text == null && audioPath == null) _controller.clear();
      });
      _scrollToBottom();

      final offeredReviews = <SubscriptionReview>{};
      final tools = ChatbotTools(
        profileId: profileId,
        prefs: prefs,
        isCurrent: isCurrent,
        confirmExpense: _confirmExpense,
        offerSubscriptionReview: (review) {
          if (offeredReviews.add(review)) {
            setState(
              () => _chatMessages.add({
                'role': 'subscriptionReview',
                'review': review,
              }),
            );
            _scrollToBottom();
          }
        },
        onExpenseSaved: widget.onDataChanged,
      );
      final currency =
          prefs.getString('${PrefKeys.selectedCurrency}-$profileId') ?? 'Rupee';
      final input = audioPath == null
          ? message
          : 'Listen to this recording and respond.';
      final prompt =
          'Profile currency: ${CurrencySymbol().getLabel(currency)}. $input';
      const timeout = Duration(seconds: 30);
      var response = await service
          .sendMessage(prompt, audioPath: audioPath)
          .timeout(timeout);

      for (var round = 0; round < 8 && response.hasFunctionCalls; round++) {
        if (!isCurrent()) return;
        final calls = response.functionCalls;
        if (calls.length > 12) throw StateError('Too many tool calls');
        setState(
          () => _chatMessages.add({
            'role': 'tool',
            'content': calls.map((call) => call.name).join('\n'),
          }),
        );
        _scrollToBottom();

        final results = <AIFunctionResponse>[];
        for (final call in calls) {
          if (!isCurrent()) return;
          final result = await tools.execute(call);
          results.add(
            AIFunctionResponse(id: call.id, name: call.name, response: result),
          );
        }
        if (!isCurrent() ||
            (prefs.getInt(PrefKeys.profileId) ?? 0) != profileId) {
          return;
        }
        response = await service
            .sendFunctionResponses(results)
            .timeout(timeout);
      }
      if (!isCurrent() ||
          (prefs.getInt(PrefKeys.profileId) ?? 0) != profileId) {
        return;
      }
      if (response.hasFunctionCalls) throw StateError('Too many tool rounds');

      final responseText = response.text ?? 'No response from AI.';
      setState(
        () => _chatMessages.add({'role': 'bot', 'content': responseText}),
      );
      _scrollToBottom();
      if (audioPath == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isCurrent() && widget.isVisible && !_isLoading) {
            _focusNode.requestFocus();
          }
        });
      }
      if (!_isMuted) unawaited(_speak(responseText));
    } catch (_) {
      if (!isCurrent()) return;
      // Start a fresh provider session if an unfinished tool turn left it out of sync.
      _aiService?.resetChat();
      setState(() => _chatMessages.add({'role': 'bot', 'content': failure}));
      _scrollToBottom();
    } finally {
      if (isCurrent()) setState(() => _isLoading = false);
      if (audioPath != null) {
        try {
          await File(audioPath).delete();
        } on FileSystemException {
          // The temporary recording may already have been removed.
        }
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmExpense(Expense expense, String currency) async {
    if (!widget.isVisible) return false;
    return _confirm(
      title: 'Save expense?',
      message:
          '$currency ${expense.amount.toStringAsFixed(2)} · ${expense.category}\n'
          '${expense.expenseDate.toIso8601String().substring(0, 10)}\n'
          '${expense.remarks}',
      action: 'Save',
    );
  }

  Future<void> _openSubscriptionReview(
    SubscriptionReview review,
    Map<String, dynamic> message,
  ) async {
    if (_reviewOpen || _isLoading) return;
    setState(() => _reviewOpen = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted ||
          (prefs.getInt(PrefKeys.profileId) ?? 0) != widget.profileId) {
        return;
      }
      final currency =
          prefs.getString('${PrefKeys.selectedCurrency}-${widget.profileId}') ??
          'Rupee';
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => SubscriptionsScreen(
            profileId: widget.profileId,
            currencySymbol: CurrencySymbol().getSymbol(currency),
            review: review,
          ),
        ),
      );
      if (changed == true && mounted) {
        widget.onDataChanged();
        setState(() => message['reviewed'] = true);
      }
    } finally {
      if (mounted) setState(() => _reviewOpen = false);
    }
  }

  Future<void> _speak(String text) async {
    final service = _aiService;
    if (service != null) {
      // Remove markdown characters before sending to TTS
      String cleanText = text
          // 1. Remove Links but keep the display text: [Click here](url) -> Click here
          .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
          // 2. Remove Headers (e.g., ### Title)
          .replaceAll(RegExp(r'#+\s*'), '')
          // 3. Remove Bold, Italics, and Strikethrough (**, __, *, _, ~~)
          .replaceAll(RegExp(r'(\*\*|__|\*|_|~~)'), '')
          // 4. Remove Inline Code and Code Blocks
          .replaceAll(RegExp(r'`+'), '')
          // 5. Remove Blockquotes (starting with >)
          .replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '')
          // 6. Remove Horizontal Rules (---, ***, ___)
          .replaceAll(RegExp(r'^\s*([-*_]){3,}\s*$', multiLine: true), '')
          // 7. Remove Bullet points (-, *, +)
          .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
          // 8. Remove Numbered lists (1. , 2. )
          .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
          // 9. Final cleanup: Collapse multiple newlines/spaces into single ones
          .replaceAll(RegExp(r'\n{2,}'), '\n')
          .trim();

      final audioBytes = await service.generateSpeech(cleanText);
      bool canPlay() => mounted && !_isMuted && identical(_aiService, service);
      if (canPlay() && audioBytes != null) {
        if (_isSpeaking) {
          await _audioPlayer.stop();
        }
        if (!canPlay()) return;
        setState(() {
          _isSpeaking = true;
        });
        await _audioPlayer.play(BytesSource(audioBytes));
      }
    }
  }

  void _startNewChat() {
    if (_isLoading) return;
    _stopSpeaking();
    setState(() {
      _chatMessages.clear();
      _expandedToolMessages.clear();
      _providerApproved = false;
      _isMuted = true;
      _aiService = null;
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _stopSpeaking();
      }
    });
  }

  Future<void> _stopSpeaking() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      _focusNode.requestFocus();
      if (path != null) {
        _sendMessage(audioPath: path);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        if (!mounted) return;
        final directory = await getTemporaryDirectory();
        if (!mounted) return;
        final path =
            '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);
        if (!mounted) return;

        setState(() {
          _isRecording = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ask Chatbot AI"),
        actions: [
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.teal, size: 28),
              onPressed: _stopSpeaking,
              tooltip: "Stop Speaking",
            )
          else
            IconButton(
              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
              onPressed: _toggleMute,
              tooltip: _isMuted ? "Unmute" : "Mute",
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _isLoading ? null : _startNewChat,
            tooltip: "New Chat",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_chatMessages.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.face_retouching_natural,
                          size: 100,
                          color: Colors.teal.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "How can I help you today?",
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(
                              context,
                            ).hintColor.withValues(alpha: 0.3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    final role = msg["role"];
                    final isUser = role == "user";
                    final isTool = role == "tool";

                    if (role == 'subscriptionReview') {
                      final review = msg['review'] as SubscriptionReview;
                      final reviewed = msg['reviewed'] == true;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: reviewed || _reviewOpen || _isLoading
                              ? null
                              : () => _openSubscriptionReview(review, msg),
                          child: Text(
                            reviewed
                                ? 'Action completed'
                                : [
                                    review.action.label,
                                    if (review.title != null) review.title,
                                  ].join(' · '),
                          ),
                        ),
                      );
                    }

                    if (isTool) {
                      final isExpanded = _expandedToolMessages.contains(index);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedToolMessages.remove(index);
                              } else {
                                _expandedToolMessages.add(index);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[900]?.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blueGrey.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isExpanded
                                          ? Icons.unfold_less
                                          : Icons.settings_suggest,
                                      size: 16,
                                      color: Colors.blueAccent.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isExpanded
                                          ? "Hide tool details"
                                          : "Tool used",
                                      style: TextStyle(
                                        color: Colors.blueAccent.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (!isExpanded) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        size: 16,
                                        color: Colors.blueAccent.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (isExpanded) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    msg["content"]!,
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.teal : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isUser
                            ? Text(
                                msg["content"]!,
                                style: const TextStyle(color: Colors.white),
                              )
                            : MarkdownBody(
                                data: msg["content"]!,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(color: Colors.white),
                                  strong: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !_isLoading && !_isRecording,
                    decoration: const InputDecoration(
                      hintText: "Ask about your expenses...",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                if (_controller.text.trim().isEmpty)
                  IconButton(
                    tooltip: _isRecording ? "Stop recording" : "Record message",
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    color: _isRecording ? Colors.red : Colors.teal,
                    onPressed: _isLoading ? null : _toggleRecording,
                  )
                else
                  IconButton(
                    tooltip: "Send message",
                    icon: const Icon(Icons.send),
                    onPressed: () => _sendMessage(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
