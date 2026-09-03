import 'package:get/get.dart';
import 'package:pos/modules/settings/controller/settings_controller.dart';
import 'package:pos/modules/clients/controller/clients_controller.dart';
import '../controller/checkout_controller.dart';

class CheckoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsController>(
      () => SettingsController(),
    );
    Get.lazyPut<ClientsController>(
      () => ClientsController(),
    );
    Get.lazyPut<CheckoutController>(
      () => CheckoutController(),
    );
  }
}
