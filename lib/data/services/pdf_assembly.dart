import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Pixel size of a page image, e.g. `(width: 1588, height: 2246)`.
typedef PagePixels = ({int width, int height});

/// Builds an A4 PDF with one page per captured page image: zero margin,
/// scaled to the page width, top-aligned.
///
/// The document is built and saved on a background isolate. `pw.MemoryImage`
/// over a PNG decodes it in pure Dart inside `save()` (~0.5–1.5 s per page on
/// a low-end phone, plus ~14 MB of raw pixels per page) — on the UI isolate
/// that froze the progress spinner for the whole export.
///
/// [jpegPages]: pages whose PNG is exactly this many pixels are re-encoded as
/// JPEG (quality 90, same size) first. The `pdf` package embeds JPEG bytes
/// as-is (`/DCTDecode`: no Dart decode, no re-compression). Pass the full
/// page size of a layout whose root paints opaque white edge to edge — JPEG
/// has no alpha, and a capture of any other size (sized to its content) can
/// have part-transparent edge pixels, so it stays PNG. Where the encoder is
/// unavailable (Linux / Windows) pages also stay PNG.
Future<Uint8List> assemblePdf(
  List<Uint8List> pages, {
  PagePixels? jpegPages,
}) async {
  final encoded = <Uint8List>[];
  for (final png in pages) {
    final size = jpegPages == null ? null : _pngPixels(png);
    encoded.add(size != null && size == jpegPages
        ? await _pngToJpeg(png, size)
        : png);
  }
  // A top-level job, so the isolate message is just the page bytes.
  return compute(_buildPdf, encoded, debugLabel: 'assemblePdf');
}

Future<Uint8List> _buildPdf(List<Uint8List> pages) {
  final pdf = pw.Document();
  for (final bytes in pages) {
    final image = pw.MemoryImage(bytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(
          image,
          fit: pw.BoxFit.fitWidth,
          alignment: pw.Alignment.topCenter,
        ),
      ),
    );
  }
  return pdf.save();
}

/// Width × height from a PNG's IHDR chunk, or null if [bytes] isn't a PNG.
PagePixels? _pngPixels(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  final data = ByteData.sublistView(bytes);
  return (width: data.getUint32(16), height: data.getUint32(20));
}

/// Native JPEG encode (off the UI thread). `minWidth` / `minHeight` are the
/// real size, so the plugin never scales the page (its defaults would let it
/// shrink tall pages). Falls back to the PNG on any failure.
Future<Uint8List> _pngToJpeg(Uint8List png, PagePixels size) async {
  try {
    final jpeg = await FlutterImageCompress.compressWithList(
      png,
      format: CompressFormat.jpeg,
      quality: 90,
      minWidth: size.width,
      minHeight: size.height,
      autoCorrectionAngle: false,
      keepExif: false,
    );
    if (jpeg.length > 2 && jpeg[0] == 0xFF && jpeg[1] == 0xD8) return jpeg;
  } catch (e, st) {
    developer.log('JPEG page encode failed; keeping PNG',
        name: 'assemblePdf', error: e, stackTrace: st);
  }
  return png;
}
