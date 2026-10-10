import 'package:get_it/get_it.dart';
import 'package:svenska/core/utils/secure_storage_util.dart';

class AppConfig {

  static Future<String> getActiveTenantId() async {
    if (GetIt.I.isRegistered<String>(instanceName: 'tenant_id')) {
      return GetIt.I<String>(instanceName: 'tenant_id');
    }

    final String? diskTenant = await SecureStorageUtil.getUserTenant();

    if (diskTenant != null) {
      GetIt.I.registerSingleton<String>(diskTenant, instanceName: 'tenant_id');
      return diskTenant;
    }

    throw Exception("CRITICAL: Tenant ID missing from system memory and disk.");
  }
}