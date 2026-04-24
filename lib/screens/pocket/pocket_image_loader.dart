import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dexcurator/core/app_constants.dart' show kUserAgent;

// ─── Cache de bytes de imagem (escopo de sessão) ──────────────────

final _imgBytesCache = <String, Uint8List>{};
final _imgPending    = <String, Future<Uint8List?>>{};

const _kImgHeaders = {
  'User-Agent':      kUserAgent,
  'Accept':          'image/webp,image/*,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
};

Future<Uint8List?> fetchPocketImg(String url) {
  if (_imgBytesCache.containsKey(url)) return Future.value(_imgBytesCache[url]);
  if (_imgPending.containsKey(url))    return _imgPending[url]!;

  Future<Uint8List?> doFetch() async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: _kImgHeaders)
          .timeout(const Duration(seconds: 20));
      final ct = res.headers['content-type'] ?? '';
      final isImage = ct.contains('image') ||
          ct.contains('webp') ||
          ct.contains('octet-stream');
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && isImage) {
        return _imgBytesCache[url] = res.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _imgPending.remove(url);
    }
  }

  return _imgPending[url] = doFetch();
}

class PocketNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final int?   cacheWidth;
  final Widget loading;
  final Widget error;
  const PocketNetworkImage({
    super.key,
    required this.url, required this.fit,
    this.cacheWidth, required this.loading, required this.error,
  });
  @override
  State<PocketNetworkImage> createState() => _PocketNetworkImageState();
}

class _PocketNetworkImageState extends State<PocketNetworkImage> {
  late Future<Uint8List?> _future;
  @override
  void initState() { super.initState(); _future = fetchPocketImg(widget.url); }
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _future,
    builder: (_, snap) {
      if (snap.connectionState != ConnectionState.done) return widget.loading;
      final bytes = snap.data;
      if (bytes == null) return widget.error;
      final provider = widget.cacheWidth != null
          ? ResizeImage(MemoryImage(bytes), width: widget.cacheWidth!)
          : MemoryImage(bytes) as ImageProvider;
      return Image(
        image: provider,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.error,
      );
    },
  );
}
