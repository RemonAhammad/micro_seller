import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/services/pos_printer_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class PosPrinterScreen extends StatefulWidget {
  const PosPrinterScreen({super.key});

  @override
  State<PosPrinterScreen> createState() => _PosPrinterScreenState();
}

class _PosPrinterScreenState extends State<PosPrinterScreen> {
  final _service = PosPrinterService.instance;
  List<SavedPrinter> _savedPrinters = [];
  String? _defaultAddress;
  int _paperWidth = 80;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final printers = await _service.loadSavedPrinters();
    final defaultAddr = await _service.loadDefaultPrinterAddress();
    final width = await _service.loadPaperWidth();
    if (!mounted) return;
    setState(() {
      _savedPrinters = printers;
      _defaultAddress = defaultAddr;
      _paperWidth = width;
      _loading = false;
    });
  }

  Future<void> _showAddPrinterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddPrinterSheet(
        onAdded: (printer) {
          setState(() {
            _savedPrinters.removeWhere((p) => p.address == printer.address);
            _savedPrinters.add(printer);
            _defaultAddress ??= printer.address;
          });
          _service.savePrinters(_savedPrinters);
          _service.saveDefaultPrinterAddress(_defaultAddress);
        },
      ),
    );
  }

  Future<void> _deletePrinter(SavedPrinter printer) async {
    final s = AppStrings.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: s.tr('deletePrinter'),
      message: '${printer.name}\n${printer.address}',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _savedPrinters.remove(printer);
      if (_defaultAddress == printer.address) {
        _defaultAddress =
            _savedPrinters.isNotEmpty ? _savedPrinters.first.address : null;
      }
    });
    _service.savePrinters(_savedPrinters);
    _service.saveDefaultPrinterAddress(_defaultAddress);
  }

  void _setDefault(SavedPrinter printer) {
    setState(() => _defaultAddress = printer.address);
    _service.saveDefaultPrinterAddress(printer.address);
  }

  Future<void> _connectAndTest(SavedPrinter saved) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final target = Printer(
      name: saved.name,
      address: saved.address,
      connectionType: switch (saved.type) {
        'usb' => ConnectionType.USB,
        'network' => ConnectionType.NETWORK,
        _ => ConnectionType.BLE,
      },
    );
    final connected = await _service.connectTo(target);
    if (!connected) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(s.tr('posPrintFailed')),
            backgroundColor: Colors.red),
      );
      return;
    }
    final ok = await _service.printTest(paperWidth: _paperWidth, printer: target);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? s.tr('testPrintSent') : s.tr('posPrintFailed')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('posPrinter'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.tr('paperWidth'),
                          style: theme.textTheme.titleSmall),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 58, label: Text('58mm')),
                        ButtonSegment(value: 80, label: Text('80mm')),
                      ],
                      selected: {_paperWidth},
                      onSelectionChanged: (v) {
                        setState(() => _paperWidth = v.first);
                        _service.savePaperWidth(_paperWidth);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(s.tr('savedPrinters'),
                          style: theme.textTheme.titleSmall),
                    ),
                    FilledButton.icon(
                      onPressed: _showAddPrinterSheet,
                      icon: const ThinIcon(tabler.Plus.new, size: 18),
                      label: Text(s.tr('addPrinter')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_savedPrinters.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          ThinIcon(tabler.Printer.new,
                              size: 48,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(s.tr('noPrintersFound'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              )),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_savedPrinters.length, (i) {
                    final p = _savedPrinters[i];
                    final isDefault = p.address == _defaultAddress;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name,
                                          style: theme.textTheme.titleSmall),
                                      const SizedBox(height: 2),
                                      Text(p.address,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          )),
                                    ],
                                  ),
                                ),
                                _TypeBadge(type: p.type),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (isDefault)
                                  Chip(
                                    avatar: const ThinIcon(tabler.Star.new,
                                        size: 16),
                                    label: Text(s.tr('defaultPrinter')),
                                    visualDensity: VisualDensity.compact,
                                  )
                                else
                                  ActionChip(
                                    label: Text(s.tr('setAsDefault')),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _setDefault(p),
                                  ),
                                ActionChip(
                                  avatar: const ThinIcon(tabler.TestPipe.new,
                                      size: 16),
                                  label: Text(s.tr('printTest')),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _connectAndTest(p),
                                ),
                                ActionChip(
                                  avatar: const ThinIcon(tabler.Trash.new,
                                      size: 16, color: Colors.red),
                                  label: Text(s.delete,
                                      style:
                                          const TextStyle(color: Colors.red)),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _deletePrinter(p),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'usb' => 'USB',
      'network' => 'NET',
      _ => 'BT',
    };
    final color = switch (type) {
      'usb' => Colors.orange,
      'network' => Colors.teal,
      _ => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _AddPrinterSheet extends StatefulWidget {
  final ValueChanged<SavedPrinter> onAdded;
  const _AddPrinterSheet({required this.onAdded});

  @override
  State<_AddPrinterSheet> createState() => _AddPrinterSheetState();
}

class _AddPrinterSheetState extends State<_AddPrinterSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _service = PosPrinterService.instance;

  List<Printer> _discoveredPrinters = [];
  bool _scanning = false;
  StreamSubscription<List<Printer>>? _scanSub;

  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  final _networkNameController = TextEditingController();

  @override
  void dispose() {
    _scanSub?.cancel();
    _tab.dispose();
    _ipController.dispose();
    _portController.dispose();
    _networkNameController.dispose();
    super.dispose();
  }

  Future<void> _scanBluetooth() async {
    setState(() {
      _scanning = true;
      _discoveredPrinters = [];
    });
    _scanSub?.cancel();
    _scanSub = _service.devicesStream.listen((list) {
      if (mounted) setState(() => _discoveredPrinters = list);
    });
    await _service.startScan(types: [ConnectionType.BLE]);
    await Future<void>.delayed(const Duration(seconds: 5));
    await _service.stopScan();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _scanUsb() async {
    setState(() {
      _scanning = true;
      _discoveredPrinters = [];
    });
    _scanSub?.cancel();
    _scanSub = _service.devicesStream.listen((list) {
      if (mounted) setState(() => _discoveredPrinters = list);
    });
    await _service.startScan(types: [ConnectionType.USB]);
    await Future<void>.delayed(const Duration(seconds: 3));
    await _service.stopScan();
    if (mounted) setState(() => _scanning = false);
  }

  void _addDiscovered(Printer printer, String type) {
    widget.onAdded(SavedPrinter(
      name: printer.name ?? printer.address ?? 'Printer',
      address: printer.address ?? '',
      type: type,
    ));
    Navigator.pop(context);
  }

  void _addNetwork() {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    final name = _networkNameController.text.trim();
    if (ip.isEmpty) return;
    widget.onAdded(SavedPrinter(
      name: name.isEmpty ? ip : name,
      address: '$ip:${port.isEmpty ? '9100' : port}',
      type: 'network',
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s.tr('addPrinter'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            TabBar(
              controller: _tab,
              tabs: [
                Tab(text: s.tr('bluetoothPrinter')),
                Tab(text: s.tr('usbPrinter')),
                Tab(text: s.tr('networkPrinter')),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildScanTab(
                    type: 'bluetooth',
                    onScan: _scanBluetooth,
                    scrollCtrl: scrollCtrl,
                  ),
                  _buildScanTab(
                    type: 'usb',
                    onScan: _scanUsb,
                    scrollCtrl: scrollCtrl,
                  ),
                  _buildNetworkTab(scrollCtrl),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScanTab({
    required String type,
    required VoidCallback onScan,
    required ScrollController scrollCtrl,
  }) {
    final s = AppStrings.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scanning ? null : onScan,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const ThinIcon(tabler.Radar2.new, size: 18),
              label: Text(s.tr('scanPrinters')),
            ),
          ),
        ),
        Expanded(
          child: _discoveredPrinters.isEmpty
              ? Center(
                  child: Text(s.tr('noPrintersFound'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          )),
                )
              : ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _discoveredPrinters.length,
                  itemBuilder: (_, i) {
                    final p = _discoveredPrinters[i];
                    return ListTile(
                      leading: const ThinIcon(tabler.Printer.new, size: 20),
                      title: Text(p.name ?? 'Unknown'),
                      subtitle: Text(p.address ?? ''),
                      trailing: FilledButton(
                        onPressed: () => _addDiscovered(p, type),
                        child: Text(s.add),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNetworkTab(ScrollController scrollCtrl) {
    final s = AppStrings.of(context);
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        AppTextField(
          controller: _networkNameController,
          label: s.tr('printerName'),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _ipController,
          label: s.tr('enterIpAddress'),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _portController,
          label: s.tr('port'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: s.add,
          onPressed: _addNetwork,
        ),
      ],
    );
  }
}
