import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final serviceUrl = Uri.https('provider.example', '/api/v1/chat/completions');

  AIService service() => AIService(
    provider: 'openai',
    apiKey: 'test-key',
    modelName: 'test-model',
    baseUrl: serviceUrl.toString(),
  );

  test('OpenAI speech failure stays with the configured provider', () async {
    final requests = <http.Request>[];
    final audio = await http.runWithClient(
      () => service().generateSpeech('Test reply'),
      () => MockClient((request) async {
        requests.add(request);
        return http.Response('Speech unavailable', 404);
      }),
    );

    expect(audio, isNull);
    final request = requests.single;
    expect(request.url, Uri.https(serviceUrl.host, '/api/v1/audio/speech'));
    expect(request.headers['authorization'], 'Bearer test-key');
    expect(jsonDecode(request.body)['input'], 'Test reply');
  });

  test('an old response cannot write into history after a reset', () async {
    final inFlight = Completer<http.Response>();
    final requestStarted = Completer<void>();
    final requestHistories = <List<dynamic>>[];

    await http.runWithClient(
      () async {
        final chat = service();
        final oldResponse = chat.sendMessage('original');
        await requestStarted.future;

        chat.resetChat();
        await chat.sendMessage('retry');
        inFlight.complete(_reply('late reply'));
        await oldResponse;
        await chat.sendMessage('follow-up');
      },
      () => MockClient((request) async {
        final messages = jsonDecode(request.body)['messages'] as List<dynamic>;
        requestHistories.add(messages);
        if (requestHistories.length == 1) {
          requestStarted.complete();
          return inFlight.future;
        }
        return _reply('current reply');
      }),
    );

    final retryHistory = requestHistories[1].skip(1);
    expect(retryHistory.map((message) => message['content']), ['retry']);
    final followUpHistory = requestHistories[2].skip(1);
    expect(followUpHistory.map((message) => message['content']), [
      'retry',
      'current reply',
      'follow-up',
    ]);
  });
}

http.Response _reply(String text) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'role': 'assistant', 'content': text},
      },
    ],
  }),
  200,
);
