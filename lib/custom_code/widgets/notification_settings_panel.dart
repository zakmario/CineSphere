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

import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/cine_notification_service.dart';

/// Réglages des notifications (section 6.9), à placer dans la page
/// Parametres : activer / désactiver, sorties de films, séries favorites,
/// heure du rappel (18 h par défaut), la veille ou le jour J, plateformes
/// suivies, notification de test. Chaque changement est enregistré (profil
/// Firestore + appareil) puis les rappels sont reprogrammés.
class NotificationSettingsPanel extends StatefulWidget {
  const NotificationSettingsPanel({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<NotificationSettingsPanel> createState() =>
      _NotificationSettingsPanelState();
}

/// Délai avant l'enregistrement : plusieurs changements rapprochés font
/// une seule écriture et une seule reprogrammation.
const Duration kSettingsSaveDelay = Duration(milliseconds: 600);

class _NotificationSettingsPanelState extends State<NotificationSettingsPanel> {
  NotificationSettings? _settings;
  List<Platform> _platforms = const [];
  Timer? _saveTimer;
  int? _scheduled;

  CineNotificationService get _service => CineNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    final pending = _saveTimer?.isActive ?? false;
    _saveTimer?.cancel();
    if (pending && _settings != null) {
      // Page quittée avant le délai : on enregistre quand même.
      _service.saveSettings(_settings!);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _service.loadSettings();
    List<Platform> platforms = const [];
    try {
      platforms = await _service.remote.fetchPlatforms();
    } catch (e) {
      debugPrint('plateformes : $e');
    }
    if (mounted) {
      setState(() {
        _settings = settings;
        _platforms = platforms;
      });
    }
  }

  /// [change] part des réglages courants : deux taps avant le rebuild
  /// ne s'écrasent pas.
  void _update(NotificationSettings Function(NotificationSettings) change) {
    final settings = change(_settings!);
    setState(() => _settings = settings);
    _saveTimer?.cancel();
    _saveTimer = Timer(kSettingsSaveDelay, () async {
      final count = await _service.saveSettings(settings);
      if (mounted) {
        setState(() => _scheduled = count);
      }
    });
  }

  Future<void> _toggleEnabled(bool enabled) async {
    if (enabled && !await _service.init(requestPermission: true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Autorisez les notifications de CinéSphère dans '
                'les réglages du téléphone.')));
      }
      return;
    }
    _update((s) => s.copyWith(enabled: enabled));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _settings!.time,
      helpText: 'Heure du rappel',
    );
    if (picked != null) {
      _update((s) => s.copyWith(time: picked));
    }
  }

  Future<void> _test() async {
    final ok = await _service.showNow(
        'CinéSphère', 'Les notifications fonctionnent sur cet appareil.');
    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notification impossible (permission refusée ?)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final settings = _settings;
    if (settings == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height ?? 120,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final on = settings.enabled;
    final time = notificationTimeLabel(
        DateTime(2000, 1, 1, settings.time.hour, settings.time.minute));

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: Text(on
                ? 'Rappels et nouvelles sorties activés'
                : 'Aucune notification ne sera envoyée'),
            value: on,
            onChanged: _toggleEnabled,
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: on ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !on,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: const Text('Sorties de films'),
                    subtitle: const Text(
                        'Films de vos favoris et de vos plateformes'),
                    value: settings.releases,
                    onChanged: (v) => _update((s) => s.copyWith(releases: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Séries favorites'),
                    subtitle: const Text('Nouveaux épisodes'),
                    value: settings.favoriteSeries,
                    onChanged: (v) =>
                        _update((s) => s.copyWith(favoriteSeries: v)),
                  ),
                  ListTile(
                    title: const Text('Heure du rappel'),
                    trailing: TextButton(
                      onPressed: _pickTime,
                      child: Text(time, style: theme.titleMedium),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('La veille')),
                        ButtonSegment(value: false, label: Text('Le jour J')),
                      ],
                      selected: {settings.dayBefore},
                      onSelectionChanged: (s) => _update(
                          (current) => current.copyWith(dayBefore: s.first)),
                    ),
                  ),
                  if (_platforms.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child:
                          Text('Plateformes suivies', style: theme.titleSmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final platform in _platforms)
                            FilterChip(
                              label: Text(platform.name),
                              selected:
                                  settings.platforms.contains(platform.name),
                              onSelected: (selected) =>
                                  _update((s) => s.copyWith(platforms: [
                                        for (final p in s.platforms)
                                          if (p != platform.name) p,
                                        if (selected) platform.name,
                                      ])),
                            ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _test,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Tester une notification'),
                        ),
                        const Spacer(),
                        if (_scheduled != null)
                          Text(
                            '$_scheduled programmée${_scheduled! > 1 ? 's' : ''}',
                            style: theme.bodySmall
                                .copyWith(color: theme.secondaryText),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
