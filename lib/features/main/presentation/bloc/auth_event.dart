abstract class AuthEvent {}

class SetupRestaurantAndAdminEvent extends AuthEvent {
  final String tenantId;
  final String tenantName;
  final String username;
  final String password;
  SetupRestaurantAndAdminEvent({required this.tenantId, required this.tenantName, required this.username, required this.password});
}

class RegisterEmployeeEvent extends AuthEvent {
  final String tenantId;
  final String username;
  final String password;
  final String role;
  RegisterEmployeeEvent({required this.tenantId, required this.username, required this.password, required this.role});
}

class ForceLogoutDeviceEvent extends AuthEvent {
  final String targetSessionToken;
  ForceLogoutDeviceEvent(this.targetSessionToken);
}

class TrackActivityEvent extends AuthEvent {
  final String sessionToken;
  TrackActivityEvent(this.sessionToken);
}

class SessionTimeoutTriggeredEvent extends AuthEvent {}