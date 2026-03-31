import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _torchOn = false;
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR / Barcode'),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              if (_scanned) return;
              final value = capture.barcodes
                  .map((b) => b.rawValue)
                  .firstWhere((v) => v != null, orElse: () => null);
              if (value != null) {
                _scanned = true;
                Navigator.of(context).pop(value);
              }
            },
          ),
          // Scanning frame overlay
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                    color: theme.colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner brackets
                  ..._corners(theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point the camera at a QR code or barcode',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const size = 24.0;
    const thickness = 4.0;
    return [
      Positioned(top: 0, left: 0,
          child: _Corner(color: color, size: size, t: thickness,
              top: true, left: true)),
      Positioned(top: 0, right: 0,
          child: _Corner(color: color, size: size, t: thickness,
              top: true, left: false)),
      Positioned(bottom: 0, left: 0,
          child: _Corner(color: color, size: size, t: thickness,
              top: false, left: true)),
      Positioned(bottom: 0, right: 0,
          child: _Corner(color: color, size: size, t: thickness,
              top: false, left: false)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final double size, t;
  final bool top, left;

  const _Corner(
      {required this.color,
      required this.size,
      required this.t,
      required this.top,
      required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            color: color, t: t, top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double t;
  final bool top, left;

  _CornerPainter(
      {required this.color,
      required this.t,
      required this.top,
      required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = t
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
