import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../../core/utils/secure_storage_util.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // 🌟 ENTER KEY FOCUS NODES ADDED
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose(); // 👈 Dispose Focus Nodes
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final apiClient = GetIt.I<ApiClient>();
    final String username = _usernameController.text.trim();

    const String hardcodedTenantId = 'svenska_1';

    try {
      final response = await apiClient.post('/api/v1/login', data: {
        'username': username,
        'password': _passwordController.text.trim(),
        'tenant_id': hardcodedTenantId,
      });

      debugPrint("login response ${response.data}");

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == 'SUCCESS') {
          final String token = data['token'];
          final String serverRole = data['role']?.toString() ?? 'waiter';

          if (GetIt.I.isRegistered<String>(instanceName: "currentUser")) {
            await GetIt.I.unregister<String>(instanceName: "currentUser");
          }
          GetIt.I.registerSingleton<String>(username, instanceName: "currentUser");

          if (GetIt.I.isRegistered<String>(instanceName: "role")) {
            await GetIt.I.unregister<String>(instanceName: "role");
          }
          GetIt.I.registerSingleton<String>(serverRole.toLowerCase(), instanceName: "role");

          if (GetIt.I.isRegistered<String>(instanceName: "tenant_id")) {
            await GetIt.I.unregister<String>(instanceName: "tenant_id");
          }
          GetIt.I.registerSingleton<String>(hardcodedTenantId, instanceName: 'tenant_id');

          if (GetIt.I.isRegistered<String>(instanceName: "accessToken")) {
            await GetIt.I.unregister<String>(instanceName: "accessToken");
          }
          GetIt.I.registerSingleton<String>(token, instanceName: "accessToken");

          debugPrint("✅ [SUCCESS]: Token ($token), Role ($serverRole) & Tenant ($hardcodedTenantId) registered in GetIt.");

          await SecureStorageUtil.saveToken(token);
          await SecureStorageUtil.saveUserTenant(hardcodedTenantId);

          if (mounted) {
            context.go(AppRoutes.dashboard);
          }
        } else {
          _showStatusMessage('Invalid Credentials', isError: true);
        }
      }
    } catch (e) {
      debugPrint("❌ [Login Error]: $e");
      _showStatusMessage('Login failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStatusMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Lato-Regular', fontSize: 13, color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;

    const Color bgSurface = Color(0xFF0F1115);
    const Color cardSurface = Color(0xFF161920);
    const Color accentGold = Color(0xFFE5A93C);
    const Color textMuted = Color(0xFF8A94A6);

    return Scaffold(
      backgroundColor: bgSurface,
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                Expanded(
                  flex: 11,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF12151C), bgSurface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(64),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.wine_bar_rounded, color: accentGold, size: 48),
                        const SizedBox(height: 24),
                        const Text(
                          'Svenska\nCore Operations.',
                          style: TextStyle(fontFamily: 'Lato-Black', fontSize: 44, color: Colors.white, height: 1.15, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        Container(width: 80, height: 4, decoration: BoxDecoration(color: accentGold, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 24),
                        const Text(
                          'Unified local network environment synchronization for kitchen tracking units, dynamic bar ordering nodes, inventory monitoring, and responsive waiter tables deployment modules.',
                          style: TextStyle(fontFamily: 'Proxima-Nova-Regular', fontSize: 13, color: textMuted, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                flex: 10,
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: SingleChildScrollView(
                    child: Container(
                      width: 420,
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF222733), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 15))
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isDesktop) ...[
                              const Row(
                                children: [
                                  Icon(Icons.wine_bar_rounded, color: accentGold, size: 24),
                                  SizedBox(width: 8),
                                  Text('SVENSKA POS', style: TextStyle(fontFamily: 'Lato-Bold', fontSize: 16, color: Colors.white, letterSpacing: 1.5)),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                            const Text('Terminal Login', style: TextStyle(fontFamily: 'Lato-Bold', fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('Initialize interface synchronization parameters', style: TextStyle(fontFamily: 'Proxima-Nova-Regular', fontSize: 12, color: textMuted)),
                            const SizedBox(height: 32),

                            _buildLabelText('OPERATIONAL RESOURCE USERNAME'),

                            // 🌟 USERNAME TEXT FIELD WITH ENTER ACTION
                            TextFormField(
                              controller: _usernameController,
                              focusNode: _usernameFocusNode, // 👈 Focus Node attached
                              textInputAction: TextInputAction.next, // 👈 Keyboard me 'Next' button
                              onFieldSubmitted: (_) {
                                // Enter dabane par Password focus me ayega
                                FocusScope.of(context).requestFocus(_passwordFocusNode);
                              },
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Lato-Regular'),
                              decoration: _buildInputStyle('e.g., mixologist_manager', Icons.person_outline_rounded, accentGold),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Operational resource identity parameter cannot be null.' : null,
                            ),
                            const SizedBox(height: 20),

                            _buildLabelText('CRYPTOGRAPHIC PASSKEY LAYER'),

                            // 🌟 PASSWORD TEXT FIELD WITH ENTER ACTION (TRIGGER LOGIN)
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode, // 👈 Focus Node attached
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.done, // 👈 Keyboard me 'Done/Enter'
                              onFieldSubmitted: (_) {
                                // Enter dabane par direct login execute hoga
                                if (!_isLoading) {
                                  _handleLogin();
                                }
                              },
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Lato-Regular'),
                              decoration: _buildInputStyle('••••••••••••', Icons.lock_open_rounded, accentGold).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: textMuted),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                  splashRadius: 20,
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Secure entry signature verification block is missing.' : null,
                            ),
                            const SizedBox(height: 32),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentGold,
                                foregroundColor: bgSurface,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(bgSurface)))
                                  : const Text('BOOT LOCAL ENGINE', style: TextStyle(fontFamily: 'Lato-Bold', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                            ),
                            const SizedBox(height: 24),

                            TextButton(
                              onPressed: () => context.push(AppRoutes.registerAdmin),
                              style: TextButton.styleFrom(foregroundColor: accentGold.withOpacity(0.85)),
                              child: const Text('Provision New Restaurant Domain Infrastructure', style: TextStyle(fontFamily: 'Lato-Bold', fontSize: 12, fontWeight: FontWeight.w600)),
                            ),

                            const Divider(color: Color(0xFF222733), height: 32, thickness: 1.5),

                            const Text(
                              'Notice: This hardware console maps directly to database instance. Active sync loops audit network logs across active counters, bars, and peripheral thermal equipment instantly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Proxima-Nova-Regular', fontSize: 10, color: Color(0xFF566275), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Material(
              color: const Color(0xFF161920),
              elevation: 4,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFFE5A93C), size: 22),
                tooltip: "Master Network Configuration",
                onPressed: () => context.go(AppRoutes.settings),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(fontFamily: 'Lato-Bold', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6C7A93), letterSpacing: 1.1)),
    );
  }

  InputDecoration _buildInputStyle(String hint, IconData prefix, Color activeColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF434B5A), fontSize: 13, fontFamily: 'Proxima-Nova-Regular'),
      prefixIcon: Icon(prefix, size: 18, color: const Color(0xFF566275)),
      filled: true,
      fillColor: const Color(0xFF1B1E26),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF222733), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: activeColor.withOpacity(0.6), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 2.0)),
      errorStyle: const TextStyle(fontFamily: 'Proxima-Nova-Regular', fontSize: 11, color: Colors.redAccent),
    );
  }
}