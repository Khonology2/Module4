import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_signature.dart';
import '../services/signature_service.dart';
import '../services/api_client.dart';

class SignatureCaptureWidget extends StatefulWidget {
  final Function(String? signatureData)? onSignatureCaptured;
  final String? existingSignature; // Base64 encoded signature image
  final bool allowSignatureReuse;
  final bool showAuditInfo;
  final String? reportId; // For audit tracking

  const SignatureCaptureWidget({
    super.key,
    this.onSignatureCaptured,
    this.existingSignature,
    this.allowSignatureReuse = true,
    this.showAuditInfo = true,
    this.reportId,
  });

  @override
  State<SignatureCaptureWidget> createState() => _SignatureCaptureWidgetState();
}

// Export the state class for external access
abstract class SignatureCaptureWidgetState
    extends State<SignatureCaptureWidget> {
  Future<String?> getSignature();
  Future<void> saveSignatureLocally(
      String signatureData, String signatureType, String signatureName);
}

// Make the private state class extend the abstract one
class _SignatureCaptureWidgetState extends SignatureCaptureWidgetState {
  final GlobalKey _signatureKey = GlobalKey();
  List<Offset?> _points = <Offset?>[];
  bool _hasSignature = false;
  bool _showSavedSignatures = false;
  List<UserSignature> _savedSignatures = [];
  UserSignature? _selectedSignature;
  late final SignatureService _signatureService;
  String? _currentSignatureData;
  DateTime? _signatureTime;
  bool _isDrawing = false;
  Offset? _lastPoint;
  double _currentPenPressure = 1.0;

  @override
  void initState() {
    super.initState();
    _signatureService = SignatureService(ApiClient());
    _hasSignature = widget.existingSignature != null;
    debugPrint('🚀 SignatureCaptureWidget initialized');
    debugPrint('📊 Initial local signatures count: ${_localSignatures.length}');
    if (widget.allowSignatureReuse) {
      _loadSavedSignatures();
    }
  }

  Future<void> _loadSavedSignatures() async {
    debugPrint('🚀 _loadSavedSignatures() called');
    try {
      debugPrint('🔍 Loading saved signatures...');
      final signatures = await _signatureService.getUserSignatures();
      debugPrint('📋 Loaded ${signatures.length} saved signatures');

      // If API returns no signatures, try local storage as fallback
      if (signatures.isEmpty) {
        debugPrint(
            '🔄 API returned no signatures, trying local storage fallback...');
        final localSignatures = await _loadLocalSignatures();
        if (mounted) {
          setState(() {
            _savedSignatures = localSignatures;
          });
          debugPrint(
              '✅ Loaded ${localSignatures.length} signatures from local storage');
        }
      } else {
        debugPrint(
            '📊 API returned ${signatures.length} signatures, using API results');
        if (mounted) {
          setState(() {
            _savedSignatures = signatures;
          });
          debugPrint('✅ Updated UI with ${signatures.length} signatures');
        }
      }
    } catch (e) {
      debugPrint('❌ API Error loading saved signatures: $e');
      debugPrint('🔄 Trying local storage fallback...');

      // Fallback to local storage
      try {
        final localSignatures = await _loadLocalSignatures();
        if (mounted) {
          setState(() {
            _savedSignatures = localSignatures;
          });
          debugPrint(
              '✅ Loaded ${localSignatures.length} signatures from local storage');
        }
      } catch (localError) {
        debugPrint('❌ Local storage also failed: $localError');
      }
    }
  }

  @override
  Future<void> saveSignatureLocally(
      String signatureData, String signatureType, String signatureName) async {
    // Check if signature with same name exists and remove it (override logic)
    final existingSignatureIndex = _localSignatures.indexWhere(
      (sig) => sig.userName?.toLowerCase() == signatureName.toLowerCase(),
    );

    if (existingSignatureIndex != -1) {
      final oldSignature = _localSignatures[existingSignatureIndex];
      _localSignatures.removeAt(existingSignatureIndex);
      debugPrint(
          '🔄 Removed existing signature: ${oldSignature.userName} (${oldSignature.id})');
    }

    // Create a new signature with required parameters
    final now = DateTime.now();
    final newSignature = UserSignature(
      id: now.millisecondsSinceEpoch.toString(),
      userId: 'local_user', // Placeholder for local storage
      signatureData: signatureData,
      signatureType: signatureType,
      isDefault: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      userName: signatureName, // Use signatureName as userName
    );

    // Add to local storage
    _localSignatures.add(newSignature);
    await _saveToPersistentStorage(); // Save to persistent storage
    debugPrint(
        '💾 Saved signature locally: ${newSignature.userName} (${newSignature.id})');
    debugPrint('📊 Total local signatures now: ${_localSignatures.length}');
  }

  Future<void> _deleteSignature(UserSignature signature) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Signature'),
          content:
              Text('Are you sure you want to delete "${signature.userName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        _localSignatures.removeWhere((sig) => sig.id == signature.id);
        await _saveToPersistentStorage(); // Save to persistent storage
        if (mounted) {
          setState(() {
            _savedSignatures = List.from(_localSignatures);
          });
        }
        debugPrint(
            '🗑️ Deleted signature: ${signature.userName} (${signature.id})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signature deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting signature: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting signature'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Persistent storage for signatures
  static const String _signaturesKey = 'saved_signatures';
  List<UserSignature> _localSignatures = [];

  Future<List<UserSignature>> _loadLocalSignatures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signaturesJson = prefs.getString(_signaturesKey);

      if (signaturesJson != null && signaturesJson.isNotEmpty) {
        final List<dynamic> signaturesList = json.decode(signaturesJson);
        _localSignatures =
            signaturesList.map((json) => UserSignature.fromJson(json)).toList();
        debugPrint(
            '📦 Loaded ${_localSignatures.length} signatures from persistent storage');
        for (var sig in _localSignatures) {
          debugPrint('📝 Found signature: ${sig.userName} (${sig.id})');
        }
      } else {
        debugPrint('📦 No saved signatures found in persistent storage');
        _localSignatures = [];
      }
      return _localSignatures;
    } catch (e) {
      debugPrint('❌ Error loading from persistent storage: $e');
      return [];
    }
  }

  Future<void> _saveToPersistentStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signaturesJson = json.encode(
        _localSignatures.map((sig) => sig.toJson()).toList(),
      );
      await prefs.setString(_signaturesKey, signaturesJson);
      debugPrint(
          '💾 Saved ${_localSignatures.length} signatures to persistent storage');
    } catch (e) {
      debugPrint('❌ Error saving to persistent storage: $e');
    }
  }

  @override
  Future<String?> getSignature() async {
    if (_hasSignature) {
      if (_currentSignatureData != null) {
        return _currentSignatureData;
      }
      return await _captureSignature();
    }
    return widget.existingSignature;
  }

  void _addPoint(Offset? point) {
    if (point == null) {
      setState(() {
        _points = List.from(_points)..add(null);
        _isDrawing = false;
        _lastPoint = null;
      });
      return;
    }

    // Constrain points to canvas bounds
    final constrainedPoint = _constrainPointToCanvas(point);
    if (constrainedPoint != null) {
      setState(() {
        _points = List.from(_points)..add(constrainedPoint);
        _hasSignature = true;
        _signatureTime = DateTime.now();
        _currentSignatureData =
            null; // Clear saved signature when drawing new one
        _isDrawing = true;
        _lastPoint = constrainedPoint;
        widget.onSignatureCaptured?.call(null); // Notify signature started
      });
    }
  }

  /// Constrain drawing points to stay within canvas boundaries
  Offset? _constrainPointToCanvas(Offset point) {
    const canvasWidth = 400.0; // Approximate canvas width
    const canvasHeight = 150.0; // Canvas height from Container
    const padding = 2.0; // Small padding from edges

    final constrainedX = point.dx.clamp(padding, canvasWidth - padding);
    final constrainedY = point.dy.clamp(padding, canvasHeight - padding);

    return Offset(constrainedX, constrainedY);
  }

  /// Interpolate points for smoother drawing
  List<Offset> _interpolatePoints(Offset start, Offset end) {
    final distance = (end - start).distance;
    final steps =
        (distance / 2).ceil().clamp(1, 8); // Limit interpolation steps

    if (steps <= 1) return [end];

    final List<Offset> interpolatedPoints = [];
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final point = Offset.lerp(start, end, t)!;
      interpolatedPoints.add(point);
    }
    return interpolatedPoints;
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
      _hasSignature = false;
      _currentSignatureData = null;
      _signatureTime = null;
      _selectedSignature = null;
      _isDrawing = false;
      _lastPoint = null;
      _currentPenPressure = 1.0;
      widget.onSignatureCaptured?.call(null);
    });
  }

  Future<void> _saveSignatureForReuse() async {
    if (!_hasSignature || _currentSignatureData == null) return;

    try {
      await _signatureService.saveSignature(
        _currentSignatureData!,
        'drawn',
        false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signature saved for future use'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload saved signatures
      await _loadSavedSignatures();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _useSavedSignature(UserSignature signature) {
    setState(() {
      _selectedSignature = signature;
      _currentSignatureData = signature.signatureData;
      _hasSignature = true;
      _signatureTime = DateTime.now();
      _points.clear(); // Clear drawn points
      widget.onSignatureCaptured?.call(signature.signatureData);
    });
  }

  Future<String?> _captureSignature() async {
    try {
      final RenderRepaintBoundary boundary = _signatureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      final String base64Image = base64Encode(pngBytes);

      setState(() {
        _currentSignatureData = base64Image;
      });

      widget.onSignatureCaptured?.call(base64Image);
      return base64Image;
    } catch (e) {
      debugPrint('Error capturing signature: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔍 Building SignatureCaptureWidget - allowReuse=${widget.allowSignatureReuse}, savedCount=${_savedSignatures.length}');

    final shouldShowSavedSignatures = widget.allowSignatureReuse;
    if (shouldShowSavedSignatures) {
      debugPrint(
          '✅ Showing saved signatures UI (always visible when allowReuse=true)');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Digital Signature',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.showAuditInfo && widget.reportId != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.verified,
                size: 16,
                color: Colors.green[400],
              ),
              const SizedBox(width: 4),
              Text(
                'Audit Trail Enabled',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign your name in the box below to approve this report',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        if (shouldShowSavedSignatures) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_savedSignatures.isEmpty) {
                      // Show validation message when no signatures exist
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No saved signatures found. Please draw a signature and check "Save this signature for future use" first.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    } else {
                      setState(() {
                        _showSavedSignatures = !_showSavedSignatures;
                      });
                    }
                  },
                  icon: Icon(
                    _showSavedSignatures
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                  ),
                  label: Text(
                    _savedSignatures.isEmpty
                        ? 'Use Saved Signature (0 saved)'
                        : _showSavedSignatures
                            ? 'Hide Saved Signatures'
                            : 'Use Saved Signature (${_savedSignatures.length} saved)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              if (_hasSignature && _currentSignatureData != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _saveSignatureForReuse,
                  icon: const Icon(Icons.save, size: 16),
                  tooltip: 'Save signature for future use',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
        if (_showSavedSignatures && _savedSignatures.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: _savedSignatures.length,
              itemBuilder: (context, index) {
                final signature = _savedSignatures[index];
                final isSelected = _selectedSignature?.id == signature.id;
                return GestureDetector(
                  onTap: () => _useSavedSignature(signature),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[700] : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isSelected ? Colors.blue[400]! : Colors.grey[400]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              base64Decode(
                                  signature.signatureData.split(',').last),
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(height: 60);
                              },
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                          ),
                        // Delete button
                        Positioned(
                          top: 2,
                          left: 2,
                          child: GestureDetector(
                            onTap: () => _deleteSignature(signature),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _isDrawing
                  ? Colors.blue[600]!
                  : _hasSignature
                      ? Colors.green[600]!
                      : Colors.grey,
              width: _isDrawing
                  ? 4
                  : _hasSignature
                      ? 3
                      : 2,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _isDrawing
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: _isDrawing ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRect(
            child: GestureDetector(
              onPanStart: (DragStartDetails details) {
                final RenderBox? renderBox =
                    context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final Offset localPosition =
                      renderBox.globalToLocal(details.globalPosition);
                  _addPoint(localPosition);
                }
              },
              onPanUpdate: (DragUpdateDetails details) {
                final RenderBox? renderBox =
                    context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final Offset localPosition =
                      renderBox.globalToLocal(details.globalPosition);

                  // Calculate smooth drawing with interpolation
                  if (_lastPoint != null && _isDrawing) {
                    final interpolatedPoints =
                        _interpolatePoints(_lastPoint!, localPosition);
                    for (final point in interpolatedPoints) {
                      _addPoint(point);
                    }
                  } else {
                    _addPoint(localPosition);
                  }
                }
              },
              onPanEnd: (DragEndDetails details) {
                _addPoint(null);
              },
              child: RepaintBoundary(
                key: _signatureKey,
                child: Stack(
                  children: [
                    // Grid pattern for better visual guidance
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(),
                      ),
                    ),
                    // Render existing or selected signature
                    if (_currentSignatureData != null)
                      Positioned.fill(
                        child: _buildSignatureImage(_currentSignatureData!),
                      ),
                    if (widget.existingSignature != null &&
                        _currentSignatureData == null)
                      Positioned.fill(
                        child: _buildExistingSignature(),
                      ),
                    // Draw signature canvas with enhanced visibility
                    if (_points.isNotEmpty && _selectedSignature == null)
                      CustomPaint(
                        painter: SignaturePainter(
                          _points,
                          isDrawing: _isDrawing,
                          currentPenPressure: _currentPenPressure,
                        ),
                        child: const SizedBox.shrink(),
                      ),
                    // Enhanced placeholder with drawing instructions
                    if (!_hasSignature &&
                        widget.existingSignature == null &&
                        _selectedSignature == null)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.create,
                              size: 32,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Sign here',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Use your finger or stylus to draw your signature',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Drawing will be constrained to this area',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _hasSignature ? _clearSignature : null,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            if (_hasSignature)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Signature captured',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_signatureTime != null && widget.showAuditInfo)
                              Text(
                                'Signed: ${_signatureTime!.toString().substring(0, 19)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                ),
                              ),
                            if (_selectedSignature != null)
                              Text(
                                'Using saved signature: ${_selectedSignature!.signatureTypeDisplay}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Build signature image from base64 data
  Widget _buildSignatureImage(String base64Data) {
    try {
      final Uint8List imageBytes = base64Decode(
          base64Data.contains(',') ? base64Data.split(',').last : base64Data);

      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Text('Failed to load signature'),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Text('Invalid signature format'),
        ),
      );
    }
  }

  /// Build existing signature with error handling
  Widget _buildExistingSignature() {
    try {
      // Check if existingSignature looks like JSON
      final trimmedData = widget.existingSignature!.trim();
      if (trimmedData.startsWith('{') ||
          trimmedData.startsWith('[') ||
          trimmedData.startsWith('"success"') ||
          trimmedData.startsWith('"error"')) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Text('Invalid signature data'),
          ),
        );
      }

      final Uint8List imageBytes = base64Decode(
          widget.existingSignature!.contains(',')
              ? widget.existingSignature!.split(',').last
              : widget.existingSignature!);

      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Text('Failed to load signature'),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Text('Invalid signature format'),
        ),
      );
    }
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final bool isDrawing;
  final double currentPenPressure;

  SignaturePainter(this.points,
      {this.isDrawing = false, this.currentPenPressure = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw with enhanced visibility
    final Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0 * currentPenPressure
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Draw signature with smooth lines and enhanced visibility
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        // Add smooth line drawing with slight thickness variation
        final start = points[i]!;
        final end = points[i + 1]!;

        // Main stroke
        canvas.drawLine(start, end, paint);

        // Add subtle shadow for depth when drawing
        if (isDrawing) {
          final shadowPaint = Paint()
            ..color = Colors.black.withValues(alpha: 0.1)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 4.0 * currentPenPressure
            ..style = PaintingStyle.stroke
            ..isAntiAlias = true
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

          canvas.drawLine(
            start + const Offset(1, 1),
            end + const Offset(1, 1),
            shadowPaint,
          );
        }
      }
    }

    // Draw current position indicator when actively drawing
    if (isDrawing && points.isNotEmpty && points.last != null) {
      final currentPoint = points.last!;
      final indicatorPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.3)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      // Draw small circle at current position
      canvas.drawCircle(currentPoint, 2.0, indicatorPaint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.isDrawing != isDrawing ||
      oldDelegate.currentPenPressure != currentPenPressure;
}

/// Grid painter for signature canvas background
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;

    const gridSize = 20.0;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}
