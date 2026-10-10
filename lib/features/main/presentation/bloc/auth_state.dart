abstract class AuthState {}

class AuthInitialState extends AuthState {}
class AuthLoadingState extends AuthState {}
class TenantSetupSuccessState extends AuthState {}
class EmployeeCreatedSuccessState extends AuthState {}
class SessionTerminatedState extends AuthState {
  final String failureReason;
  SessionTerminatedState(this.failureReason);
}
class AuthErrorState extends AuthState {
  final String errorMessage;
  AuthErrorState(this.errorMessage);
}