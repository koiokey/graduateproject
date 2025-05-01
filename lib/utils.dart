import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// HTTP 客戶端單例，實現保持連接
class HttpClient {
  static final http.Client _client = http.Client();

  static http.Client get instance => _client;

  static void close() {
    _client.close();
  }
}

// 防抖工具類
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer(this.duration);

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
  }
}