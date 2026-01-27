import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/pref_keys.dart';
import 'package:expense_tracker/services/ai_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ChatbotScreen extends StatefulWidget {
  final int profileId;
  const ChatbotScreen({super.key, required this.profileId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  AIService? _aiService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isSpeaking = false;
  bool _isRecording = false;
  bool _isMuted = true;
  String defaultModelName = 'gemini-1.5-flash-latest';

  @override
  void initState() {
    super.initState();
    _initAIService();
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
      if (mounted && (state == PlayerState.completed || state == PlayerState.stopped || state == PlayerState.paused)) {
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

  Future<void> _initAIService() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(PrefKeys.geminiApiKey) ?? '';
    final modelName = prefs.getString(PrefKeys.geminiModelName) ?? defaultModelName;
    
    if (apiKey.isNotEmpty) {
      setState(() {
        _aiService = AIService(apiKey, modelName);
      });
    }
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
    final messageText = text ?? _controller.text.trim();
    if (messageText.isEmpty && audioPath == null) return;

    setState(() {
      _messages.add({
        "role": "user",
        "content": audioPath != null ? "🎤 [Voice Message]" : messageText,
      });
      _isLoading = true;
      if (text == null) _controller.clear();
    });
    _scrollToBottom();

    try {
      debugPrint("Sending message to AI: $text");
      
      if (_aiService == null) {
        await _initAIService();
      }
      
      if (_aiService == null) {
        throw Exception("AI Service could not be initialized. Please check your API key in settings.");
      }

      final List<Part> parts = [];
      if (audioPath != null) {
        final bytes = await File(audioPath).readAsBytes();
        parts.add(DataPart('audio/m4a', bytes));
      }
      
      final contextPrompt = "The current user's profile ID is ${widget.profileId}.";
      final promptText = audioPath != null ? "$contextPrompt [Listen to this audio and respond]" : "$contextPrompt $messageText";
      parts.add(TextPart(promptText));

      var response = await _aiService!.chatSession.sendMessage(Content.multi(parts)).timeout(const Duration(seconds: 30));

      while (true) {
        final functionCalls = response.candidates.first.content.parts.whereType<FunctionCall>().toList();
        if (functionCalls.isEmpty) break;

        final functionResponses = <FunctionResponse>[];
        for (final functionCall in functionCalls) {
          setState(() {
            _messages.add({
              "role": "tool",
              "content": "Calling: ${functionCall.name}\nArgs: ${functionCall.args}",
            });
          });
          _scrollToBottom();

          final result = await _aiService!.executeFunctionCall(functionCall);
          functionResponses.add(FunctionResponse(functionCall.name, result));
        }

        response = await _aiService!.chatSession.sendMessage(Content.model(functionResponses)).timeout(const Duration(seconds: 30));
      }

      final responseText = response.text ?? "No response from AI.";

      setState(() {
        _messages.add({"role": "bot", "content": responseText});
        _isLoading = false;
      });
      _scrollToBottom();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });

      // Optionally play as speech
      if (!_isMuted) {
        _speak(responseText);
      }

    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "content": "Error: $e"});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _speak(String text) async {
    if (_aiService != null) {
      final audioBytes = await _aiService!.generateSpeech(text);
      if (audioBytes != null) {
        if (_isSpeaking) {
          await _audioPlayer.stop();
        }
        setState(() {
          _isSpeaking = true;
        });
        await _audioPlayer.play(BytesSource(audioBytes));
      }
    }
  }

  void _startNewChat() {
    _stopSpeaking();
    setState(() {
      _messages.clear();
      _isMuted = true;
      _aiService?.resetChat();
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
      setState(() {
        _isRecording = false;
      });
      _focusNode.requestFocus();
      if (path != null) {
        _sendMessage(audioPath: path);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);
        
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
        title: const Text("Chat with Anila"),
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
            onPressed: _startNewChat,
            tooltip: "New Chat",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_messages.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.face_retouching_natural,
                          size: 100,
                          color: Colors.teal.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "How can I help you today?",
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).hintColor.withOpacity(0.3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                final msg = _messages[index];
                final role = msg["role"];
                final isUser = role == "user";
                final isTool = role == "tool";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser 
                          ? Colors.teal 
                          : isTool 
                              ? Colors.blueGrey[900]?.withOpacity(0.5) 
                              : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: isTool ? Border.all(color: Colors.blueGrey, width: 0.5) : null,
                    ),
                    child: isUser 
                      ? Text(
                          msg["content"]!,
                          style: const TextStyle(color: Colors.white),
                        )
                      : isTool
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.settings_suggest, size: 16, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  msg["content"]!,
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : MarkdownBody(
                            data: msg["content"]!,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(color: Colors.white),
                              strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    color: _isRecording ? Colors.red : Colors.teal,
                    onPressed: _toggleRecording,
                  )
                else
                  IconButton(
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
