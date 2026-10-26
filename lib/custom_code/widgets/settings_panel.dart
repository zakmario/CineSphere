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

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

/// Paramètres : notifications (permission, test, rappels programmés),
/// genres préférés, relance du walkthrough et déconnexion.
/// [onReplayOnboarding] : naviguer vers la page Onboarding.
/// [onSignOut] : action FlutterFlow "Log Out" puis navigation vers Login.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    this.width,
    this.height,
    this.onReplayOnboarding,
    this.onSignOut,
  });

  final double? width;
  final double? height;
  final Future Function()? onReplayOnboarding;
  final Future Function()? onSignOut;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _notificationsEnabled = false;
  int _reminderCount = 0;
  List<String> _genres = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = await getScheduledReminders();
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationsEnabled = prefs.getBool('cs_notifications_enabled') ?? false;
      _reminderCount = reminders.length;
      _genres = prefs.getStringList('cs_favorite_genres') ?? [];
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    var enabled = value;
    if (value) {
      enabled = await initLocalNotifications();
      if (!enabled) {
        _snack('Permission refusée : autorisez les notifications dans les '
            'réglages du téléphone ou du navigateur.');
      }
    } else {
      for (final key in await getScheduledReminders()) {
        await cancelReleaseNotification(key);
      }
    }
    await prefs.setBool('cs_notifications_enabled', enabled);
    await _load();
  }

  Future<void> _testNotification() async {
    final ok = await showInstantNotification(
      'CineSphere',
      'Les notifications fonctionnent 🎬',
    );
    if (!ok) {
      _snack('Impossible d’afficher la notification (permission refusée ?)');
    }
  }

  Future<void> _clearReminders() async {
    for (final key in await getScheduledReminders()) {
      await cancelReleaseNotification(key);
    }
    await _load();
    _snack('Tous les rappels ont été supprimés');
  }

  Future<void> _replayOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cs_onboarding_done');
    await widget.onReplayOnboarding?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final email = fb.FirebaseAuth.instance.currentUser?.email;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(text.toUpperCase(),
              style: theme.labelMedium.copyWith(
                  color: theme.primary, fontWeight: FontWeight.w700)),
        );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ListView(
        children: [
          if (email != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.primary,
                child: Text(email[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white)),
              ),
              title: Text(email, style: theme.bodyMedium),
              subtitle: const Text('Connecté'),
            ),
          header('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Rappels de sorties'),
            subtitle: const Text(
                'Être prévenu avant la sortie d’un film ou d’un épisode'),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Tester une notification'),
            onTap: _testNotification,
          ),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: Text('$_reminderCount rappel'
                '${_reminderCount > 1 ? 's' : ''} programmé'
                '${_reminderCount > 1 ? 's' : ''}'),
            trailing: _reminderCount == 0
                ? null
                : TextButton(
                    onPressed: _clearReminders,
                    child: const Text('Tout supprimer'),
                  ),
          ),
          header('Préférences'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Genres préférés'),
            subtitle: Text(
                _genres.isEmpty ? 'Aucun genre choisi' : _genres.join(', ')),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Revoir la présentation de l’app'),
            subtitle: const Text('Et modifier vos genres préférés'),
            onTap: _replayOnboarding,
          ),
          if (widget.onSignOut != null) ...[
            header('Compte'),
            ListTile(
              leading: Icon(Icons.logout, color: theme.error),
              title: Text('Se déconnecter',
                  style: TextStyle(color: theme.error)),
              onTap: () => widget.onSignOut!(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
