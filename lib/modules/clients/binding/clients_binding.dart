import 'package:get/get.dart';
import '../controller/clients_controller.dart';

class ClientsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClientsController>(
      () => ClientsController(),
    );
  }
}
