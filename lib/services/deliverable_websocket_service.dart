import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../models/deliverable.dart';
import '../config/environment.dart';

class DeliverableWebSocketService {
  static final DeliverableWebSocketService _instance = DeliverableWebSocketService._internal();
  factory DeliverableWebSocketService() => _instance;
  DeliverableWebSocketService._internal();

  io.Socket? _socket;
  final StreamController<Deliverable> _deliverableCreatedController = StreamController<Deliverable>.broadcast();
  final StreamController<Deliverable> _deliverableUpdatedController = StreamController<Deliverable>.broadcast();
  final StreamController<Map<String, dynamic>> _deliverableDeletedController = StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<Deliverable> get deliverableCreatedStream => _deliverableCreatedController.stream;
  Stream<Deliverable> get deliverableUpdatedStream => _deliverableUpdatedController.stream;
  Stream<Map<String, dynamic>> get deliverableDeletedStream => _deliverableDeletedController.stream;

  bool _isConnected = false;
  bool _isConnecting = false;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    
    _isConnecting = true;
    try {
      debugPrint('🔌 Connecting to WebSocket for deliverable updates...');
      
      _socket = io.io(
        Environment.apiBaseUrl.replaceAll('/api/v1', ''),
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
        },
      );

      // Set up event listeners
      _setupEventListeners();

      // Connect to the server
      _socket!.connect();
      
      debugPrint('✅ WebSocket connected for deliverable updates');
      _isConnected = true;
      
    } catch (e) {
      debugPrint('❌ Failed to connect to WebSocket: $e');
      _isConnected = false;
    } finally {
      _isConnecting = false;
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('🔌 WebSocket connected');
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 WebSocket disconnected');
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ WebSocket connection error: $error');
      _isConnected = false;
    });

    // Deliverable events
    _socket!.on('deliverable:created', (data) {
      debugPrint('📦 New deliverable created: ${data['deliverable']['title']}');
      
      try {
        final deliverable = Deliverable.fromJson(Map<String, dynamic>.from(data['deliverable']));
        _deliverableCreatedController.add(deliverable);
      } catch (e) {
        debugPrint('❌ Error parsing deliverable from WebSocket: $e');
      }
    });

    _socket!.on('deliverable:updated', (data) {
      debugPrint('📦 Deliverable updated: ${data['deliverableId']}');
      
      try {
        if (data['deliverable'] != null) {
          final deliverable = Deliverable.fromJson(Map<String, dynamic>.from(data['deliverable']));
          _deliverableUpdatedController.add(deliverable);
        }
      } catch (e) {
        debugPrint('❌ Error parsing deliverable update from WebSocket: $e');
      }
    });

    _socket!.on('deliverable:deleted', (data) {
      debugPrint('🗑️ Deliverable deleted: ${data['deliverableId']}');
      _deliverableDeletedController.add(data);
    });
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      debugPrint('🔌 WebSocket disconnected');
    }
  }

  bool get isConnected => _isConnected;

  void dispose() {
    disconnect();
    _deliverableCreatedController.close();
    _deliverableUpdatedController.close();
    _deliverableDeletedController.close();
  }
}
