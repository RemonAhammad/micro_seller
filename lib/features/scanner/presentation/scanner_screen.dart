import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

/// Scanner screen lives as a sidebar branch. The user scans a QR/barcode and
/// the screen looks up the matching product (by qrCode or sku). If found the
/// match card offers "View product"; otherwise it offers "Add as new product"
/// which jumps to the product form with the code pre-filled.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> with WidgetsBindingObserver {
  // Started/stopped by hand: the branch stays mounted offstage after a visit.
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, autoStart: false);

  String? _scannedCode;
  Product? _matchedProduct;
  bool _searching = false;
  bool _torchOn = false;
  bool _paused = false;

  bool _tabActive = false;
  bool _appResumed = true;
  bool _cameraDenied = false;
  Future<void> _cameraOp = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while another branch is shown or a route covers this one.
    final active = TickerMode.valuesOf(context).enabled;
    if (active == _tabActive) return;
    _tabActive = active;
    // Opening the tab is the only time a refused camera is asked for again.
    _syncCamera(retryDenied: active);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  /// Serialized because start() throws while a start is in flight; each op applies the latest wanted state.
  void _syncCamera({bool retryDenied = false}) {
    _cameraOp = _cameraOp.then((_) async {
      if (!mounted) return;
      final want = _tabActive && _appResumed;
      // Android re-prompts on every start() and the prompt pauses/resumes the app — a resume loop.
      if (want && _cameraDenied && !retryDenied) return;
      try {
        if (want) {
          await _controller.start();
          _cameraDenied = _controller.value.error?.errorCode == MobileScannerErrorCode.permissionDenied;
        } else {
          await _controller.stop();
        }
      } catch (_) {
        // A failed start shows in the preview.
      }
      if (!want && _torchOn && mounted) setState(() => _torchOn = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_paused || _searching) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (value == null) return;
    if (value == _scannedCode) return; // ignore duplicate

    setState(() {
      _scannedCode = value;
      _matchedProduct = null;
      _searching = true;
      _paused = true;
    });

    try {
      final isar = await ref.read(isarProvider.future);
      // Match against qrCode OR sku — sellers may print either as a label.
      final product = await isar.products.filter().qrCodeEqualTo(value).or().skuEqualTo(value).findFirst();
      if (!mounted) return;
      setState(() {
        _matchedProduct = product;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _resetAndScanAgain() {
    setState(() {
      _scannedCode = null;
      _matchedProduct = null;
      _searching = false;
      _paused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(s.scanQrBarcode),
        actions: [
          IconButton(
            icon: ThinIcon(
              _torchOn ? tabler.Bolt.new : tabler.BoltOff.new,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera view with overlay
          Expanded(
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Text(s.pointCameraAtCode, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Result panel
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _scannedCode == null
                ? const SizedBox.shrink()
                : _ResultPanel(
                    code: _scannedCode!,
                    product: _matchedProduct,
                    searching: _searching,
                    onScanAgain: _resetAndScanAgain,
                    onView: () {
                      final p = _matchedProduct;
                      if (p == null) return;
                      context.push('/products/${p.id}');
                    },
                    onAdd: () {
                      // Push directly so we leave the scanner branch.
                      context.push('/products/add', extra: ScannerPrefill(qrCode: _scannedCode!));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final String code;
  final Product? product;
  final bool searching;
  final VoidCallback onScanAgain;
  final VoidCallback onView;
  final VoidCallback onAdd;

  const _ResultPanel({
    required this.code,
    required this.product,
    required this.searching,
    required this.onScanAgain,
    required this.onView,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final found = product != null;
    final accent = searching
        ? cs.primary
        : found
        ? Colors.green
        : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ThinIcon(
                    searching
                        ? tabler.Search.new
                        : found
                        ? tabler.CircleCheck.new
                        : tabler.HelpCircle.new,
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        searching
                            ? '...'
                            : found
                            ? s.productMatched
                            : s.noProductMatched,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: accent),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.scannedCode}: $code',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (found) ...[const SizedBox(height: 14), _ProductPreview(product: product!)],
            const SizedBox(height: 14),
            // IntrinsicHeight + stretch keeps both buttons the same height
            // even when one wraps to multiple lines (e.g. "Add as new
            // product" wraps to 3 lines on narrow phones while "Scan again"
            // fits in one). Without this they'd render at their own
            // intrinsic heights and look mismatched.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onScanAgain,
                      icon: const ThinIcon(tabler.Refresh.new, size: 18),
                      label: Text(s.scanAgain, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: searching
                        ? const Center(
                            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                          )
                        : found
                        ? FilledButton.icon(
                            onPressed: onView,
                            icon: const ThinIcon(tabler.Eye.new, size: 18),
                            label: Text(s.viewProduct, textAlign: TextAlign.center),
                          )
                        : FilledButton.icon(
                            onPressed: onAdd,
                            icon: const ThinIcon(tabler.Plus.new, size: 18),
                            label: Text(s.addAsNewProduct, textAlign: TextAlign.center),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  final Product product;
  const _ProductPreview({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ThinIcon(tabler.Package.new, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.sku.isNotEmpty)
                  Text(
                    'SKU: ${product.sku}',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
          Text(
            '${product.totalStock}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: product.isOutOfStock
                  ? Colors.red
                  : product.isLowStock
                  ? Colors.orange
                  : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Public payload type the router uses to forward pre-fill data to the
/// product form. Defined alongside the screen so both producer and consumer
/// share one definition.
class ScannerPrefill {
  final String qrCode;
  final String? sku;
  const ScannerPrefill({required this.qrCode, this.sku});
}
