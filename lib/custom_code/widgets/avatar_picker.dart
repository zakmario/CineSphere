// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '/custom_code/actions/supabase_service.dart';

/// Photo de profil du membre connecté (membre 1). Un appui ouvre la
/// galerie ; l'image, réduite à 512 px, est envoyée dans le bucket
/// `avatars` puis enregistrée dans `profiles.avatar_url`.
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
  final Future Function(String avatarUrl)? onChanged;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

/// Taille maximale acceptée par le bucket `avatars` (2 Mo).
const _kMaxAvatarBytes = 2 * 1024 * 1024;

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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
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
      if (bytes.length > _kMaxAvatarBytes) {
        throw const CineFailure(
            CineFailureKind.invalid, 'L’image dépasse 2 Mo.');
      }
      final name = file.mimeType ?? file.name;
      final extension = name.contains('png')
          ? 'png'
          : name.contains('webp')
              ? 'webp'
              : 'jpg';
      final url = await SupabaseService.instance
          .uploadAvatar(bytes, extension: extension);
      if (!mounted) {
        return;
      }
      setState(() => _url = url);
      _message('Photo de profil mise à jour');
      await widget.onChanged?.call(url);
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
                        else
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => placeholder,
                            errorWidget: (_, __, ___) => placeholder,
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
