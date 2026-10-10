import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../../data/database/daos/auth_dao.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class AdminRegisterPage extends StatefulWidget {
  const AdminRegisterPage({super.key});

  @override
  State<AdminRegisterPage> createState() => _AdminRegisterPageState();
}

class _AdminRegisterPageState extends State<AdminRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _tenantIdController = TextEditingController();
  final _tenantNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkSystemInitialization();
  }

  Future<void> _checkSystemInitialization() async {
    // Assuming you use GetIt for dependency injection
    final authDao = GetIt.I<AuthDao>();
    final bool alreadyInitialized = await authDao.isAnyAdminRegistered();

    if (alreadyInitialized && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("System already provisioned. Master account locked."),
          backgroundColor: Colors.orange,
        ),
      );
      // Redirect to login or home
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _tenantIdController.dispose();
    _tenantNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;

    // Harmonized Slate Noir & Ember Palette
    const Color bgSurface = Color(0xFF0F1115);
    const Color cardSurface = Color(0xFF161920);
    const Color accentGold = Color(0xFFE5A93C);
    const Color textMuted = Color(0xFF8A94A6);

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
      ),
      extendBodyBehindAppBar: true,
      body: Row(
        children: [
          // ================= DESKTOP BRANDING COLLATERAL PANEL =================
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
                    const Icon(Icons.admin_panel_settings_rounded, color: accentGold, size: 48),
                    const SizedBox(height: 24),
                    const Text(
                      'System Infrastructure\nProvisioning Core.',
                      style: TextStyle(fontFamily: 'Lato-Black', fontSize: 44, color: Colors.white, height: 1.15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    Container(width: 80, height: 4, decoration: BoxDecoration(color: accentGold, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 24),
                    const Text(
                      'Initialize your restaurant cluster domain profile instance. Establishing this container cluster deploys the standalone master admin controller, locking relational schemas to prevent unauthorized multi-tenant duplication leaks across hardware nodes.',
                      style: TextStyle(fontFamily: 'Proxima-Nova-Regular', fontSize: 13, color: textMuted, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),

          // ================= REGISTRATION INPUT INTERFACE CONTAINER =================
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
                  child: BlocConsumer<AuthBloc, AuthState>(
                    listener: (context, state) {
                      if (state is TenantSetupSuccessState) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Master Admin profile deployed successfully! Proceeding to node login.', style: TextStyle(fontFamily: 'Lato-Regular', fontSize: 13)),
                            backgroundColor: Colors.teal,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                        Navigator.pop(context);
                      } else if (state is AuthErrorState) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.errorMessage, style: const TextStyle(fontFamily: 'Lato-Regular', fontSize: 13)),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      final bool isLoading = state is AuthLoadingState;

                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isDesktop) ...[
                              const Row(
                                children: [
                                  Icon(Icons.admin_panel_settings_rounded, color: accentGold, size: 24),
                                  SizedBox(width: 8),
                                  Text('SVENSKA PROVISION', style: TextStyle(fontFamily: 'Lato-Bold', fontSize: 14, color: Colors.white, letterSpacing: 1.2)),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                            const Text('Provision Admin', style: TextStyle(fontFamily: 'Lato-Bold', fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('Setup core cluster instance metrics below', style: TextStyle(fontFamily: 'Proxima-Nova-Regular', fontSize: 12, color: textMuted)),
                            const SizedBox(height: 32),

                            // Input: Unique Tenant Code Allocation
                            _buildLabelText('INITIALIZE UNIQUE RESTAURANT ID'),
                            TextFormField(
                              controller: _tenantIdController,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Lato-Regular'),
                              decoration: _buildInputStyle('e.g., svenska_hq_01', Icons.token_outlined, accentGold),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'System tracking cluster target ID cannot be null.' : null,
                            ),
                            const SizedBox(height: 18),

                            // Input: Restaurant Clean Title
                            _buildLabelText('RESTAURANT HARDWARE DISPLAY NAME'),
                            TextFormField(
                              controller: _tenantNameController,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Lato-Regular'),
                              decoration: _buildInputStyle('e.g., Svenska Bistro & Bar', Icons.storefront_rounded, accentGold),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Display nomenclature entry label is mandatory.' : null,
                            ),
                            const SizedBox(height: 18),

                            // Input: Root Identity Node
                            _buildLabelText('MASTER ADMIN ACCOUNT USERNAME'),
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Lato-Regular'),
                              decoration: _buildInputStyle('e.g., root_admin', Icons.badge_outlined, accentGold),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Root node administrator identity handles are required.' : null,
                            ),
                            const SizedBox(height: 18),

                            // Input: Root Crypt Signature
                            _buildLabelText('SECURE ADMINISTRATIVE ENCRYPT SIGNATURE'),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Lato-Regular'),
                              decoration: _buildInputStyle('••••••••••••', Icons.gpp_good_outlined, accentGold).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: textMuted),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                  splashRadius: 20,
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Root crypt structural parameters must be filled.' : null,
                            ),
                            const SizedBox(height: 32),

                            // Interactive Deployment Trigger
                            ElevatedButton(
                              onPressed: isLoading ? null : () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(SetupRestaurantAndAdminEvent(
                                    tenantId: _tenantIdController.text,
                                    tenantName: _tenantNameController.text,
                                    username: _usernameController.text,
                                    password: _passwordController.text,
                                  ));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentGold,
                                foregroundColor: bgSurface,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(bgSurface)))
                                  : const Text('DEPLOY OVERALL ENGINE', style: TextStyle(fontFamily: 'Lato-Bold', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                            ),
                            const SizedBox(height: 24),

                            // Footnotes Micro Context info
                            const Text(
                              'Warning: Executing deployment structures spawns isolated local instance schemas. Multi-admin accounts per terminal stack are bounded strictly to 1 under structural POS guard controls.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Proxima-Nova-Regular', fontSize: 10, color: Color(0xFF566275), height: 1.4),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
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
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Lato-Bold', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6C7A93), letterSpacing: 1.1),
      ),
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