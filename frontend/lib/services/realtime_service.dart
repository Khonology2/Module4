// ignore_for_file: avoid_print

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:developer' as developer;
import '../config/environment.dart';
import 'auth_service.dart';
import 'dart:async';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  final Map<String, List<Function>> _eventListeners = {};
  final Map<String, List<Function>> _onceListeners = {};
  final Set<String> _boundEvents = {};

  // Connection state stream
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  // Reconnect timer
  Timer? _reconnectTimer;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  /// Initialize the real-time service connection
  Future<void> initialize({String? authToken}) async {
    if (_socket != null && _isConnected) {
      return;
    }

    String? token = authToken;
    if (token == null) {
      try {
        final auth = AuthService();
        await auth.initialize();
        token = auth.accessToken;
      } catch (_) {}
    }
    if (token == null) {
      developer.log('No authentication token provided');
      return;
    }

    try {
      // Disconnect existing socket if any
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _isConnected = false;

      final baseHost = Environment.apiBaseUrl.replaceAll('/api/v1', '');
      
      // Create socket with better configuration
      _socket = io.io(
        baseHost,
        io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io/')
          .disableAutoConnect() // Don't auto-connect, we'll connect manually
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setTimeout(20000) // 20 second timeout
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
      );

      _setupSocketEvents();
      
      // Connect manually after setting up events
      await Future.delayed(const Duration(milliseconds: 100));
      _socket!.connect();

    } catch (e) {
      developer.log('Failed to initialize real-time service: $e');
      _scheduleReconnect();
    }
  }

  /// Set up socket event handlers
  void _setupSocketEvents() {
    _socket!
      ..onConnect((_) {
        developer.log('✅ Connected to real-time server');
        _isConnected = true;
        _reconnectAttempts = 0;
        _connectionController.add(true);
        _authenticate();
      })
      ..onDisconnect((_) {
        developer.log('❌ Disconnected from real-time server');
        _isConnected = false;
        _connectionController.add(false);
        _scheduleReconnect();
      })
      ..onError((data) {
        developer.log('⚠️ Socket error: $data');
        _isConnected = false;
        _connectionController.add(false);
      })
      ..on('connect_error', (data) {
        developer.log('⚠️ Connection error: $data');
        _isConnected = false;
        _connectionController.add(false);
      })
      ..on('connected', (data) {
        developer.log('✅ Socket connection confirmed: $data');
        _joinUserRooms();
      });

    // Setup real-time data event handlers
    _setupDataEventHandlers();
  }

  /// Authenticate the socket connection
  /// Note: Authentication is handled automatically during connection handshake
  /// via the auth object provided in the socket configuration
  void _authenticate() {
    // Authentication is handled automatically via the auth object
    // No need to emit a separate authenticate event
    developer.log('✅ Socket authentication handled automatically during connection');
  }

  /// Join user-specific rooms
  void _joinUserRooms() {
    // User ID and role are handled automatically by the backend upon connection
    // based on the JWT token. No manual join needed here.
  }

  /// Set up data event handlers for real-time updates
  void _setupDataEventHandlers() {
    // Data event handlers can be added here as needed
    // For example:
    // _socket!.on('custom_event', (data) => _handleCustomEvent(data));
  }


  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      developer.log('Attempting to reconnect (attempt $_reconnectAttempts/$_maxReconnectAttempts)...');
      initialize();
    });
  }

  /// Add event listener
  void on(String eventName, Function(dynamic) listener) {
    if (!_eventListeners.containsKey(eventName)) {
      _eventListeners[eventName] = [];
    }
    _eventListeners[eventName]!.add(listener);

    if (!_boundEvents.contains(eventName)) {
      _socket?.on(eventName, (data) {
        final listeners = _eventListeners[eventName];
        if (listeners != null) {
          for (final l in List<Function>.from(listeners)) {
            l(data);
          }
        }
        final once = _onceListeners[eventName];
        if (once != null) {
          for (final l in List<Function>.from(once)) {
            l(data);
          }
          _onceListeners.remove(eventName);
        }
      });
      _boundEvents.add(eventName);
    }
  }

  /// Add one-time event listener
  void once(String eventName, Function(dynamic) listener) {
    if (!_onceListeners.containsKey(eventName)) {
      _onceListeners[eventName] = [];
    }
    _onceListeners[eventName]!.add(listener);
  }

  /// Remove event listener
  void off(String eventName, Function(dynamic) listener) {
    _eventListeners[eventName]?.remove(listener);
    _onceListeners[eventName]?.remove(listener);
    if ((_eventListeners[eventName]?.isEmpty ?? true) && (_onceListeners[eventName]?.isEmpty ?? true)) {
      _socket?.off(eventName);
      _boundEvents.remove(eventName);
    }
  }

  /// Remove all listeners for an event
  void offAll(String eventName) {
    _eventListeners.remove(eventName);
    _onceListeners.remove(eventName);
    _socket?.off(eventName);
    _boundEvents.remove(eventName);
  }

  /// Remove all event listeners
  void clearAllListeners() {
    for (final eventName in List<String>.from(_eventListeners.keys)) {
      _eventListeners.remove(eventName);
      _onceListeners.remove(eventName);
      _socket?.off(eventName);
      _boundEvents.remove(eventName);
    }
    for (final eventName in List<String>.from(_onceListeners.keys)) {
      _eventListeners.remove(eventName);
      _onceListeners.remove(eventName);
      _socket?.off(eventName);
      _boundEvents.remove(eventName);
    }
    _eventListeners.clear();
    _onceListeners.clear();
    _boundEvents.clear();
  }

  /// Emit custom event to server
  void emit(String eventName, dynamic data) {
    _socket?.emit(eventName, data);
  }

  /// Emit event locally
  void emitLocal(String eventName, dynamic data) {
    final listeners = _eventListeners[eventName];
    if (listeners != null) {
      for (final l in List<Function>.from(listeners)) {
        l(data);
      }
    }
  }

  /// Disconnect from server
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Get connection status
  bool get isConnected => _isConnected;

  /// Clean up resources
  void dispose() {
    disconnect();
    _connectionController.close();
    clearAllListeners();
  }
}
