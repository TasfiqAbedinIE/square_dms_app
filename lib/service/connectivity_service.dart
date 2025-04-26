import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((results) {
      _controller.sink.add(_checkStatus(results));
    });
  }

  bool _checkStatus(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Stream<bool> get connectivityStream => _controller.stream;

  void dispose() => _controller.close();
}
