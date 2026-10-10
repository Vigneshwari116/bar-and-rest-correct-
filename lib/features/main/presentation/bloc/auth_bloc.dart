import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/password_hash_util.dart';
import '../../../../data/database/daos/auth_dao.dart';
import '../../../../core/network/api_client.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthDao? authDao;
  final ApiClient apiClient;

  AuthBloc({this.authDao, required this.apiClient}) : super(AuthInitialState()) {

    // ==========================================================================
    // 1. TENANT SETUP (Maps to /api/v1/tenant/setup)
    // ==========================================================================
    on<SetupRestaurantAndAdminEvent>((event, emit) async {
      emit(AuthLoadingState());
      try {
        final String safePasswordHash = hashPassword(event.password);

        if (authDao != null) {
          await authDao!.registerTenantWithAdmin(
            tenantId: event.tenantId.trim(),
            tenantName: event.tenantName.trim(),
            username: event.username.trim(),
            passwordHash: safePasswordHash,
          );
        } else {
          await apiClient.post('/api/v1/tenant/setup', data: {
            'tenant_id': event.tenantId.trim(),
            'tenant_name': event.tenantName.trim(),
            'username': event.username.trim(),
            'password': safePasswordHash,
          }, isPublic: true);
        }
        emit(TenantSetupSuccessState());
      } catch (e) {
        emit(AuthErrorState(e.toString()));
      }
    });

    // ==========================================================================
    // 2. EMPLOYEE REGISTRATION (Maps to /api/v1/users/create)
    // ==========================================================================
    on<RegisterEmployeeEvent>((event, emit) async {
      emit(AuthLoadingState());
      try {
        final String safePasswordHash = hashPassword(event.password);

        if (authDao != null) {
          await authDao!.insertEmployee(
            tenantId: event.tenantId,
            username: event.username,
            passwordHash: safePasswordHash,
            role: event.role,
          );
        } else {
          await apiClient.post('/api/v1/users/create', data: {
            'tenant_id': event.tenantId,
            'username': event.username,
            'password': safePasswordHash,
            'role': event.role,
          });
        }
        emit(EmployeeCreatedSuccessState());
      } catch (e) {
        emit(AuthErrorState(e.toString()));
      }
    });

    // ==========================================================================
    // 3. REMOTE SESSION KILL (Maps to /api/v1/users/kill-session)
    // ==========================================================================
    on<ForceLogoutDeviceEvent>((event, emit) async {
      try {
        if (authDao != null) {
          await authDao!.executeForceLogout(event.targetSessionToken);
        } else {
          await apiClient.post('/api/v1/users/kill-session', data: {
            'user_id': event.targetSessionToken,
          });
        }
      } catch (e) {
        emit(AuthErrorState("Failed to revoke session: $e"));
      }
    });

    // ==========================================================================
    // 4. TELEMETRY ACTIVITY (Maps to /api/v1/users/telemetry)
    // ==========================================================================
    on<TrackActivityEvent>((event, emit) async {
      try {
        if (authDao != null) {
          final session = await authDao!.getActiveSession(event.sessionToken);
          if (session != null && session['is_forcefully_logged_out'] == 1) {
            emit(SessionTerminatedState("Your active access profile was killed forcefully by admin."));
          } else {
            await authDao!.updateSessionActivity(event.sessionToken);
          }
        } else {
          final response = await apiClient.post('/api/v1/users/telemetry', data: {
            'sessionToken': event.sessionToken,
          });

          if (response.data != null && response.data['is_forcefully_logged_out'] == 1) {
            emit(SessionTerminatedState("Your active access profile was killed forcefully by admin."));
          }
        }
      } catch (e) {
        debugPrint("Telemetry Error: $e");
      }
    });

    // ==========================================================================
    // 5. AUTO INACTIVITY TIMEOUT LOGOUT (Maps to /api/v1/session/timeout)
    // ==========================================================================
    on<SessionTimeoutTriggeredEvent>((event, emit) async {
      try {
        debugPrint("🔄 [AuthBloc Interceptor]: Processing background timeout.");

        if (authDao != null) {
          await authDao!.clearAllSessionsOnTimeout();
        } else {
          await apiClient.post('/api/v1/session/timeout', data: {});
        }

        debugPrint("🎯 [AuthBloc Interceptor]: Storage wiped successfully.");
        emit(SessionTerminatedState("System auto-logged out due to inactivity threshold exceeded."));

      } catch (e) {
        debugPrint("❌ [AuthBloc Critical Failure]: Failed to clean session records: $e");
        emit(SessionTerminatedState("System auto-logged out due to 15 minutes inactivity."));
      }
    });
  }
}