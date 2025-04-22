import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  ConnectivityService() {
    Connectivity().onConnectivityChanged.listen((result) {
      _controller.sink.add(result != ConnectivityResult.none);
    });

    _checkInitialConnection();
  }

  void _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    _controller.sink.add(result != ConnectivityResult.none);
  }

  Stream<bool> get connectivityStream => _controller.stream;

  void dispose() {
    _controller.close();
  }
}
