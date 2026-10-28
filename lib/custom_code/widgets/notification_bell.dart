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

import 'dart:async';

import '/custom_code/actions/cine_notification_service.dart';

/// Cloche avec le nombre de notifications non lues (badge), à placer dans
/// l'App Bar. Le compte suit Firestore en temps réel et inclut les rappels
/// dès leur heure de remise. Prépare aussi les notifications locales (sans
/// demander la permission) pour qu'un tap sur une notification ouvre la
/// fiche du titre.
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.width,
    this.height,
    this.iconColor,
    this.onTap,
  });

  final double? width;
  final double? height;
  final Color? iconColor;

  /// Brancher *Navigate To → Notifications*.
  final Future Function()? onTap;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  StreamSubscription<List<NotificationEntry>>? _subscription;
  Timer? _clock;
  List<NotificationEntry> _unread = const [];

  CineNotificationService get _service => CineNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _service.init();
    _subscription = _service.store.watchUnread().listen(
      (unread) {
        if (mounted) {
          setState(() => _unread = unread);
        }
      },
      onError: (Object e) => debugPrint('NotificationBell : $e'),
    );
    // Un rappel programmé devient « remis » à son heure : on recompte.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final now = _service.now();
    final count = _unread.where((n) => n.isDue(now)).length;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: IconButton(
        tooltip: count == 0
            ? 'Notifications'
            : 'Notifications, $count non lue${count > 1 ? 's' : ''}',
        onPressed: widget.onTap == null ? null : () => widget.onTap!(),
        icon: Badge(
          isLabelVisible: count > 0,
          backgroundColor: theme.tertiary,
          // Le nombre « saute » quand il change.
          label: AnimatedSwitcher(
            duration: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(count > 9 ? '9+' : '$count', key: ValueKey(count)),
          ),
          child: Icon(
            count > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: widget.iconColor ?? theme.primaryText,
          ),
        ),
      ),
    );
  }
}
