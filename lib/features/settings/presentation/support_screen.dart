import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_distribution.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/currency_formatter.dart';

/// Builds the developer-facing diagnostics block that seeds a bug report and
/// is shown on the Support screen. Kept pure for testing. English on purpose:
/// it is read by whoever triages the issue.
String buildSupportDiagnostics({
  required String appName,
  required String version,
  required String buildNumber,
  String? installerStore,
  required String os,
  required String osVersion,
  required String locale,
  required String currency,
}) {
  final lines = <String>[
    'App: $appName',
    'Version: $version ($buildNumber)',
    'Install source: ${installerStore == null || installerStore.isEmpty ? 'unknown' : installerStore}',
    'Platform: $os $osVersion',
    'Language: $locale',
    'Currency: $currency',
  ];
  return lines.join('\n');
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _diagnostics;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final info = await PackageInfo.fromPlatform();
    final locale = WidgetsBinding.instance.platformDispatcher.locale.toString();
    final diag = buildSupportDiagnostics(
      appName: info.appName.isEmpty ? AppStrings.appName : info.appName,
      version: info.version,
      buildNumber: info.buildNumber,
      installerStore: info.installerStore,
      os: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      locale: locale,
      currency: CurrencyFormatter.symbol,
    );
    if (mounted) setState(() => _diagnostics = diag);
  }

  Future<void> _openUri(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      context.showSnackBar(AppStrings.of(context).couldNotOpenLink,
          isError: true);
    }
  }

  Future<void> _openIssue({required String title, required String hint}) async {
    final s = AppStrings.of(context);
    final diag = _diagnostics ?? '';
    final body = '$hint\n\n\n\n---\n'
        '${s.diagnostics}:\n$diag';
    await _openUri(AppDistribution.newIssueUrl(title: title, body: body));
  }

  Future<void> _copyDiagnostics() async {
    final s = AppStrings.of(context);
    await Clipboard.setData(ClipboardData(text: _diagnostics ?? ''));
    if (mounted) context.showSnackBar(s.diagnosticsCopied);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final brand = context.brand;
    final hasPrivacy = AppDistribution.privacyPolicyUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(s.helpAndSupport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // FAQ
          _SectionHeader(s.faq),
          _Card(
            children: [
              for (final (q, a) in s.supportFaqs)
                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(
                    q,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        a,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact
          _SectionHeader(s.stillNeedHelp),
          _Card(
            children: [
              ListTile(
                leading: _IconBox(
                    icon: tabler.Bug.new, color: Colors.deepOrange.shade400),
                title: Text(s.reportAProblem),
                subtitle: Text(s.reportAProblemDesc),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () => _openIssue(
                  title: s.reportAProblem,
                  hint: s.describeProblemHint,
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _IconBox(
                    icon: tabler.Bulb.new, color: Colors.amber.shade700),
                title: Text(s.featureRequest),
                subtitle: Text(s.featureRequestDesc),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () => _openIssue(
                  title: s.featureRequest,
                  hint: s.featureRequestHint,
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _IconBox(
                    icon: tabler.HelpCircle.new, color: Colors.blue.shade400),
                title: Text(s.askAQuestion),
                subtitle: Text(s.askAQuestionDesc),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () => _openIssue(
                  title: s.askAQuestion,
                  hint: s.askAQuestionHint,
                ),
              ),
              if (hasPrivacy) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: _IconBox(
                      icon: tabler.ShieldLock.new, color: brand.primary),
                  title: Text(s.privacyPolicy),
                  trailing: const ThinIcon(tabler.ExternalLink.new, size: 20),
                  onTap: () =>
                      _openUri(Uri.parse(AppDistribution.privacyPolicyUrl)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Diagnostics
          _SectionHeader(s.diagnostics),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.diagnosticsDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _diagnostics ?? '…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _diagnostics == null ? null : _copyDiagnostics,
                    icon: const ThinIcon(tabler.Copy.new, size: 18),
                    label: Text(s.copy),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final ThinIconBuilder icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ThinIcon(icon, color: color, size: 20),
    );
  }
}
