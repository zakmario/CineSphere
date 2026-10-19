import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/auth_service.dart';

class AuthPageWidget extends StatefulWidget {
  const AuthPageWidget({super.key});

  static const routeName = 'AuthPage';
  static const routePath = '/auth';

  @override
  State<AuthPageWidget> createState() => _AuthPageWidgetState();
}

class _AuthPageWidgetState extends State<AuthPageWidget> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isRegistering = false;
  bool _isResetting = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isResetting) {
        await AuthService.sendPasswordResetEmail(_emailController.text.trim());
        if (!mounted) return;
        _showMessage('Un e-mail de réinitialisation a été envoyé.');
        setState(() => _isResetting = false);
      } else if (_isRegistering) {
        await AuthService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
        );
        if (!mounted) return;
        _showMessage(
          'Compte créé. Vérifiez votre e-mail si la confirmation est activée.',
        );
      } else {
        await AuthService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        context.go('/');
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _isResetting
        ? 'Réinitialiser le mot de passe'
        : _isRegistering
            ? 'Créer un compte'
            : 'Se connecter';

    return Scaffold(
      appBar: AppBar(title: const Text('CineSphere')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.movie_filter, size: 64),
                    const SizedBox(height: 16),
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    if (!AuthService.isConfigured) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Supabase n’est pas configuré. Lancez l’application avec '
                        'SUPABASE_URL et SUPABASE_ANON_KEY.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_isRegistering) ...[
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration:
                            const InputDecoration(labelText: 'Nom utilisateur'),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Saisissez un nom utilisateur.'
                            : null,
                      ),
                    ],
                    if (!_isResetting) const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (value) => value == null || !value.contains('@')
                          ? 'Saisissez un e-mail valide.'
                          : null,
                    ),
                    if (!_isResetting) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: 'Mot de passe'),
                        validator: (value) => value == null || value.length < 6
                            ? 'Le mot de passe doit contenir au moins 6 caractères.'
                            : null,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading || !AuthService.isConfigured
                          ? null
                          : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text(_isResetting
                              ? 'Envoyer l’e-mail'
                              : _isRegistering
                                  ? 'S’inscrire'
                                  : 'Se connecter'),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _isResetting = false;
                                _isRegistering = !_isRegistering;
                                _errorMessage = null;
                              }),
                      child: Text(_isRegistering
                          ? 'J’ai déjà un compte'
                          : 'Créer un compte'),
                    ),
                    if (!_isRegistering)
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _isResetting = !_isResetting;
                                  _errorMessage = null;
                                }),
                        child: Text(_isResetting
                            ? 'Retour à la connexion'
                            : 'Mot de passe oublié ?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
