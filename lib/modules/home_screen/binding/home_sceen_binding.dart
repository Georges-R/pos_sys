import 'package:get/get.dart';
import 'package:pos/modules/clients/controller/clients_controller.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/modules/settings/controller/settings_controller.dart';

class HomeSceenBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => HomeSceenController(),
    );
    Get.lazyPut(
      () => SettingsController(),
    );
    Get.lazyPut(
      () => ClientsController(),
    );
  }
}
