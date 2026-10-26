// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '/custom_code/actions/firebase_service.dart';

/// Photo de profil du membre connecté (membre 1). Un appui ouvre la
/// galerie ; l'image, réduite à 256 px, est enregistrée en base64 dans
/// `users/{uid}.avatarData` (le forfait gratuit de Firebase n'inclut pas
/// Storage).
///
/// [avatarUrl] accepte une URL http(s) ou l'image en base64 (avatarData).
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    this.width,
    this.height,
    this.avatarUrl,
    this.onChanged,
  });

  final double? width;
  final double? height;
  final String? avatarUrl;
  /// Reçoit la nouvelle image en base64.
  final Future Function(String avatarUrl)? onChanged;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _url;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _url = widget.avatarUrl;
  }

  @override
  void didUpdateWidget(covariant AvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _url = widget.avatarUrl;
    }
  }

  /// Image base64 -> octets (vide si la chaîne est invalide).
  static Uint8List _decode(String data) {
    try {
      return base64Decode(data);
    } on FormatException {
      return Uint8List(0);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 75,
      );
    } catch (_) {
      _message('Impossible d’ouvrir la galerie.');
      return;
    }
    if (file == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > kMaxAvatarBytes) {
        throw const CineFailure(CineFailureKind.invalid,
            'Image trop lourde : choisissez-en une autre.');
      }
      await CineFirebaseService.instance.uploadAvatar(bytes);
      final data = base64Encode(bytes);
      if (!mounted) {
        return;
      }
      setState(() => _url = data);
      _message('Photo de profil mise à jour');
      await widget.onChanged?.call(data);
    } on CineFailure catch (e) {
      if (mounted) {
        _message(e.message);
      }
    } catch (_) {
      if (mounted) {
        _message('L’envoi de la photo a échoué.');
      }
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.width ?? widget.height ?? 100;
    final inner = size - 8;
    final url = _url;
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5B841), Color(0xFF7C5CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded,
          color: const Color(0xFF14110A), size: inner * 0.52),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF5B841), width: 2),
            ),
            alignment: Alignment.center,
            child: Semantics(
              button: true,
              label: 'Changer la photo de profil',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _busy ? null : _pick,
                child: ClipOval(
                  child: SizedBox(
                    width: inner,
                    height: inner,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (url == null || url.isEmpty)
                          placeholder
                        else if (url.startsWith('http'))
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => placeholder,
                            errorWidget: (_, __, ___) => placeholder,
                          )
                        else
                          Image.memory(
                            _decode(url),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => placeholder,
                          ),
                        if (_busy)
                          const ColoredBox(
                            color: Colors.black45,
                            child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5B841),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF15151F), width: 2),
                ),
                child: Icon(Icons.photo_camera_rounded,
                    color: const Color(0xFF14110A), size: size * 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
