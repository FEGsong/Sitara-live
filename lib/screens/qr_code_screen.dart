import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import 'scan_qr_screen.dart';

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final _boundaryKey = GlobalKey();

  String get _qrData => 'sitaralive://user/${AppState.instance.uid}';

  Future<Uint8List?> _captureImage() async {
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    Share.share(
      'Follow me on Sitara Live! My ID: ${AppState.instance.uid}\n$_qrData',
    );
  }

  Future<void> _save() async {
    final bytes = await _captureImage();
    if (bytes == null) return;
    try {
      await Gal.putImageBytes(bytes, name: 'sitara_live_qr_${AppState.instance.uid}');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('✅ Saved to gallery')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save — check gallery permission')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final name = state.nickname.isNotEmpty ? state.nickname : state.username;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('My QR Code')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.hot,
                      backgroundImage:
                          state.avatarUrl.isNotEmpty ? NetworkImage(state.avatarUrl) : null,
                      child: state.avatarUrl.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 20))
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: _qrData,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    const Text('Scan this QR code to view this profile',
                        style: TextStyle(color: Colors.black54, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(Icons.qr_code_scanner, 'Scan', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
                    );
                  }),
                  _actionButton(Icons.ios_share, 'Share', _share),
                  _actionButton(Icons.download, 'Save', _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
