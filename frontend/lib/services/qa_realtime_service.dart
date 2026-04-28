import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/environment.dart';
import '../models/sprint_metrics.dart';
import 'auth_service.dart';

class QARealtimeService {
  final AuthService _authService;
  io.Socket? _socket;
  final StreamController<SprintMetrics> _metricsController = StreamController<SprintMetrics>.broadcast();
  final StreamController<Map<String, dynamic>> _defectsController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<double> _testCoverageController = StreamController<double>.broadcast();
  
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  
  QARealtimeService(this._authService);
  
  Stream<SprintMetrics> get metricsStream => _metricsController.stream;
  Stream<Map<String, dynamic>> get defectsStream => _defectsController.stream;
  Stream<double> get testCoverageStream => _testCoverageController.stream;
  
  bool get isConnected => _isConnected;
  
  Future<void> connect() async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        throw Exception('No authentication token available');
      }
      final baseHost = Environment.apiBaseUrl.replaceAll('/api/v1', '');
      _socket?.disconnect();
      _socket?.dispose();
      _socket = io.io(
        baseHost,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );
      _setupSocketEvents();
      _socket!.connect();
    } catch (e) {
      _scheduleReconnect();
    }
  }
  
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _reconnectTimer?.cancel();
  }
  
  void _setupSocketEvents() {
    _socket!
      ..onConnect((_) {
        _isConnected = true;
        _reconnectAttempts = 0;
      })
      ..onDisconnect((_) {
        _isConnected = false;
        _scheduleReconnect();
      })
      ..on('connect_error', (err) {
        _handleError(err);
      })
      ..on('error', (err) {
        _handleError(err);
      })
      ..on('qa_metrics_update', (data) {
        _handleMetricsUpdate(data);
      })
      ..on('qa_defects_update', (data) {
        _handleDefectsUpdate(data);
      })
      ..on('qa_coverage_update', (data) {
        _handleTestCoverageUpdate(data);
      })
      ..on('sprint_progress_updated', (data) {
        _handleMetricsUpdate(data);
      });
  }
  
  void _handleMetricsUpdate(dynamic data) {
    try {
      final metrics = SprintMetrics.fromJson(Map<String, dynamic>.from(data));
      _metricsController.add(metrics);
    } catch (e) {
      // Error parsing metrics - silently ignore
    }
  }
  
  void _handleDefectsUpdate(dynamic data) {
    try {
      final defects = Map<String, dynamic>.from(data);
      _defectsController.add(defects);
    } catch (e) {
      // Error parsing defects - silently ignore
    }
  }
  
  void _handleTestCoverageUpdate(dynamic data) {
    try {
      final coverage = (data as num).toDouble();
      _testCoverageController.add(coverage);
    } catch (e) {
      // Error parsing test coverage - silently ignore
    }
  }
  
  void _handleError(dynamic error) {
    _handleDisconnect();
  }
  
  void _handleDisconnect() {
    _isConnected = false;
    _reconnectAttempts = _reconnectAttempts + 1;
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final int seconds = () {
      const base = 5;
      const maxDelay = 60;
      final calc = base * (1 << (_reconnectAttempts > 6 ? 6 : _reconnectAttempts));
      return calc > maxDelay ? maxDelay : calc;
    }();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_isConnected) {
        connect();
      }
    });
  }
  
  Future<void> sendCommand(String command, Map<String, dynamic> data) async {
    if (_socket == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }
    final message = {
      'type': 'command',
      'command': command,
      'data': data,
    };
    _socket!.emit('qa_command', message);
  }
  
  void dispose() {
    disconnect();
    _metricsController.close();
    _defectsController.close();
    _testCoverageController.close();
    _reconnectTimer?.cancel();
  }
}

// Provider for QA realtime service
class QARealtimeProvider with ChangeNotifier {
  final QARealtimeService _service;
  SprintMetrics? _currentMetrics;
  Map<String, dynamic>? _currentDefects;
  double? _currentTestCoverage;
  bool _isLoading = true;
  String? _error;
  
  QARealtimeProvider(this._service) {
    _initialize();
  }
  
  SprintMetrics? get metrics => _currentMetrics;
  Map<String, dynamic>? get defects => _currentDefects;
  double? get testCoverage => _currentTestCoverage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _service.isConnected;
  
  void _initialize() async {
    try {
      await _service.connect();
      
      // Listen to metrics stream
      _service.metricsStream.listen((metrics) {
        _currentMetrics = metrics;
        _isLoading = false;
        _error = null;
        notifyListeners();
      });
      
      // Listen to defects stream
      _service.defectsStream.listen((defects) {
        _currentDefects = defects;
        notifyListeners();
      });
      
      // Listen to test coverage stream
      _service.testCoverageStream.listen((coverage) {
        _currentTestCoverage = coverage;
        notifyListeners();
      });
      
    } catch (e) {
      _error = 'Failed to initialize real-time QA service: \$e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      if (!_service.isConnected) {
        await _service.connect();
      }
      
      // Send refresh command
      await _service.sendCommand('refresh', {});
      
    } catch (e) {
      _error = 'Refresh failed: \$e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
