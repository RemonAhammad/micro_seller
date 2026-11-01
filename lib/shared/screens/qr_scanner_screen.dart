import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_strings.dart';
import '../../data/services/device_channel.dart';
import '../widgets/scanner_camera.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {

  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  late final CameraSession _session;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _session = CameraSession(_controller, ref.read(deviceChannelProvider));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _session.setVisible(TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _session.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;

    final value = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (value == null) return;
    _scanned = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(AppStrings.of(context).scanQrBarcode),
        actions: [TorchButton(controller: _controller)],
      ),

      body: ScannerPreview(
        session: _session,
        onDetect: _onDetect,
        overlay: Stack(
          children: [

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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppStrings.of(context).pointCameraAtCode,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
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
