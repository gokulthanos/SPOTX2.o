import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class QRScannerPage extends StatefulWidget {
  final String? role; // 'officer' or 'driver'

  const QRScannerPage({super.key, this.role = 'officer'});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  String? _lastScanned;
  Map<String, dynamic>? _ticketResult;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    if (code == _lastScanned) return;
    _lastScanned = code;

    setState(() => _isProcessing = true);
    _verifyTicket(code);
  }

  Future<void> _verifyTicket(String ticketNumber) async {
    try {
      final ticket = await ApiService.verifyTicket(ticketNumber);
      if (mounted) {
        setState(() {
          _ticketResult = ticket != null
              ? {
                  'ticketNumber': ticket.ticketId,
                  'fromStop': ticket.fromStop,
                  'toStop': ticket.toStop,
                  'fare': ticket.fare,
                  'status': ticket.status,
                  'passengers': ticket.passengerCount,
                }
              : null;
          _showResult = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ticketResult = null;
          _showResult = true;
          _isProcessing = false;
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _showResult = false;
      _ticketResult = null;
      _lastScanned = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay with scanning frame
          _buildScannerOverlay(),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan Ticket QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text('Point camera at QR code', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _scannerController?.toggleTorch(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _scannerController!,
                          builder: (context, state, _) {
                            return Icon(
                              state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                              size: 20,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    SizedBox(height: 16),
                    Text('Verifying ticket...', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // Result overlay
          if (_showResult) _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(
      painter: ScannerOverlayPainter(),
      size: Size.infinite,
    );
  }

  Widget _buildResultOverlay() {
    final isValid = _ticketResult != null && _ticketResult!['status'] != 'expired';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Status icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: (isValid ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isValid ? AppTheme.success : AppTheme.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              isValid ? 'VALID TICKET' : (_ticketResult != null ? 'INVALID TICKET' : 'TICKET NOT FOUND'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isValid ? AppTheme.success : AppTheme.error,
                letterSpacing: 1,
              ),
            ),

            if (_ticketResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _resultRow('Ticket #', _ticketResult!['ticketNumber'] ?? ''),
                    _resultRow('Route', '${_ticketResult!['fromStop'] ?? ''} → ${_ticketResult!['toStop'] ?? ''}'),
                    _resultRow('Fare', '₹${_ticketResult!['fare'] ?? 0}'),
                    _resultRow('Status', _ticketResult!['status'] ?? ''),
                    _resultRow('Passengers', '${_ticketResult!['passengers'] ?? 0}'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _resetScanner,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('SCAN AGAIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('CLOSE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    // Draw overlay
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(20))),
      ),
      paint,
    );

    // Draw scan frame border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(20)),
      borderPaint,
    );

    // Corner markers
    final cornerPaint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;
    final corners = [
      [scanArea.topLeft, const Offset(1, 1), const Offset(1, 0), const Offset(0, 1)],
      [scanArea.topRight, const Offset(-1, 1), const Offset(-1, 0), const Offset(0, 1)],
      [scanArea.bottomLeft, const Offset(1, -1), const Offset(1, 0), const Offset(0, -1)],
      [scanArea.bottomRight, const Offset(-1, -1), const Offset(-1, 0), const Offset(0, -1)],
    ];

    for (final corner in corners) {
      final point = corner[0];
      final dir = corner[1];
      final hDir = corner[2];
      final vDir = corner[3];

      canvas.drawLine(
        point,
        point + Offset(hDir.dx * cornerLength, hDir.dy * cornerLength),
        cornerPaint,
      );
      canvas.drawLine(
        point,
        point + Offset(vDir.dx * cornerLength, vDir.dy * cornerLength),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
