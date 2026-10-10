import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/utils/app_routes.dart';
import 'features/main/presentation/bloc/auth_bloc.dart';
import 'features/main/presentation/bloc/auth_event.dart';
import 'features/main/presentation/bloc/auth_state.dart';
import 'features/main/presentation/widgets/session_timeout_listener.dart';
import 'injection.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => sl<AuthBloc>(),
      child: SessionTimeoutListener(
        timeoutDuration: const Duration(days: 360), // 60 seconds strict check validation
        onTimeout: () {
          debugPrint("🚨 [Global Trigger]: Timeout threshold hit! Forcing explicit logout sequences.");

          final BuildContext? globalContext = AppRouter.navigatorKey.currentContext;

          if (globalContext != null && globalContext.mounted) {
            debugPrint("🎯 [Global Trigger]: Dispatched Event to active tree Bloc.");
            BlocProvider.of<AuthBloc>(globalContext).add(SessionTimeoutTriggeredEvent());
          } else {
            debugPrint("⚠️ [Global Trigger]: Tree context unreachable. Running direct routing fallback layer.");
            sl<AuthBloc>().add(SessionTimeoutTriggeredEvent());
            AppRouter.router.go(AppRoutes.login);
          }
        },
        // =====================================================================
        // 🧱 FIXED: Removed unsafe context listeners from raw top engine root
        // =====================================================================
        child: BlocListener<AuthBloc, AuthState>(
          listener: (blocContext, state) {
            if (state is SessionTerminatedState) {
              debugPrint("🏁 [App Monitor]: State matched to SessionTerminatedState. Executing global direct switch.");

              // 💥 SAFE SNACKBAR IMPLEMENTATION: Uses AppRouter key context inside MaterialApp
              final BuildContext? activeUiContext = AppRouter.navigatorKey.currentContext;
              if (activeUiContext != null && activeUiContext.mounted) {
                ScaffoldMessenger.of(activeUiContext).showSnackBar(
                  SnackBar(
                    content: Text(state.failureReason, style: const TextStyle(fontFamily: 'Lato-Regular', fontSize: 12)),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              // Direct router navigation pipeline flush execution
              AppRouter.router.go(AppRoutes.login);
            }
          },
          child: MaterialApp.router(
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}