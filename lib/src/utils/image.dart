import 'dart:async';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:material_color_utilities/material_color_utilities.dart';

typedef ImageColors = ({
  int primaryContainer,
  int onPrimaryContainer,
  int error,
});

/// A worker that calculates the `primaryContainer` color of a remote image.
///
/// The worker is created by calling [ImageColorWorker.spawn], and the computation
/// is run in a separate isolate.
class ImageColorWorker {
  final SendPort _commands;
  final ReceivePort _responses;
  final Map<int, Completer<ImageColors?>> _activeRequests = {};
  int _idCounter = 0;
  bool _closed = false;

  bool get closed => _closed;

  Future<ImageColors?> getImageColors(String url) async {
    if (_closed) throw StateError('Closed');
    final completer = Completer<ImageColors?>.sync();
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send((id, url));
    return await completer.future;
  }

  static Future<ImageColorWorker> spawn() async {
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (dynamic initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete(
        (
          ReceivePort.fromRawReceivePort(initPort),
          commandPort,
        ),
      );
    };

    try {
      await Isolate.spawn(_startRemoteIsolate, initPort.sendPort);
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    return ImageColorWorker._(receivePort, sendPort);
  }

  ImageColorWorker._(this._responses, this._commands) {
    _responses.listen(_handleResponsesFromIsolate);
  }

  void _handleResponsesFromIsolate(dynamic message) {
    final (int id, Object response) = message as (int, Object);
    final completer = _activeRequests.remove(id)!;

    if (response is RemoteError) {
      completer.completeError(response);
    } else {
      completer.complete(response as ImageColors);
    }

    if (_closed && _activeRequests.isEmpty) _responses.close();
  }

  static void _handleCommandsToIsolate(
    ReceivePort receivePort,
    SendPort sendPort,
  ) {
    receivePort.listen((message) async {
      if (message == 'shutdown') {
        receivePort.close();
        return;
      }
      final (int id, String url) = message as (int, String);
      try {
        final bytes = await http.readBytes(Uri.parse(url));
        final image = img.decodeImage(bytes);
        final resized = img.copyResize(image!, width: 112);
        final QuantizerResult quantizerResult =
            await QuantizerCelebi().quantize(
          resized.buffer.asUint32List(),
          32,
        );
        final Map<int, int> colorToCount = quantizerResult.colorToCount.map(
          (int key, int value) =>
              MapEntry<int, int>(_getArgbFromAbgr(key), value),
        );
        // Score colors for color scheme suitability.
        final List<int> scoredResults = Score.score(
          colorToCount,
          desired: 1,
          fallbackColorARGB: 0xFFEEEEEE,
          filter: false,
        );
        final Hct sourceColor = Hct.fromInt(scoredResults.first);
        final scheme = SchemeFidelity(
          sourceColorHct: sourceColor,
          isDark: false,
          contrastLevel: 0.0,
        );
        final colors = (
          primaryContainer: scheme.primaryContainer,
          onPrimaryContainer: scheme.onPrimaryContainer,
          error: scheme.error,
        );
        sendPort.send((id, colors));
      } catch (e) {
        sendPort.send((id, RemoteError(e.toString(), '')));
      }
    });
  }

  static void _startRemoteIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    _handleCommandsToIsolate(receivePort, sendPort);
  }

  void close() {
    if (!_closed) {
      _closed = true;
      _commands.send('shutdown');
      if (_activeRequests.isEmpty) _responses.close();
    }
  }
}

// Converts AABBGGRR color int to AARRGGBB format.
int _getArgbFromAbgr(int abgr) {
  const int exceptRMask = 0xFF00FFFF;
  const int onlyRMask = ~exceptRMask;
  const int exceptBMask = 0xFFFFFF00;
  const int onlyBMask = ~exceptBMask;
  final int r = (abgr & onlyRMask) >> 16;
  final int b = abgr & onlyBMask;
  return (abgr & exceptRMask & exceptBMask) | (b << 16) | r;
}
