import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';

class ProfilePageWidget extends StatefulWidget {
  const ProfilePageWidget({super.key});

  static const routeName = 'ProfilePage';
  static const routePath = '/profile';

  @override
  State<ProfilePageWidget> createState() => _ProfilePageWidgetState();
}

class _ProfilePageWidgetState extends State<ProfilePageWidget> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = currentUserUid;
    if (uid.isEmpty) return;
    try {
      final profile = await SupaFlow.client
          .from('profiles')
          .select('username, bio, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      _usernameController.text = (profile?['username'] as String?) ??
          currentUserEmail.split('@').first;
      _bioController.text = (profile?['bio'] as String?) ?? '';
      _avatarUrl = profile?['avatar_url'] as String?;
    } on PostgrestException catch (error) {
      if (mounted)
        _showMessage('Profil impossible à charger : ${error.message}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await SupaFlow.client.from('profiles').upsert({
        'id': currentUserUid,
        'username': _usernameController.text.trim(),
        'email': currentUserEmail,
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'avatar_url': _avatarUrl,
      });
      if (mounted) _showMessage('Profil mis à jour.');
    } on PostgrestException catch (error) {
      if (mounted)
        _showMessage('Profil impossible à mettre à jour : ${error.message}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundImage:
                        _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                    child: _avatarUrl == null
                        ? const Icon(Icons.person, size: 42)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text('E-mail', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(currentUserEmail),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom d’utilisateur',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Le nom est requis.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Parlez-nous de vos goûts cinéma...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
    );
  }
}
