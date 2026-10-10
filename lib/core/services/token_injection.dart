import '../../injection.dart';
import 'token_storage_service.dart';

Future<void> initTokenDI() async {

  sl.registerLazySingleton<TokenStorage>(() => TokenStorage());
  final storage = TokenStorage();
  final accessToken = await storage.getAccessToken() ?? "";

  sl.registerSingleton<String>(accessToken, instanceName: "accessToken");
}