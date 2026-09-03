import 'package:get/get.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/modules/home_screen/binding/home_sceen_binding.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/modules/home_screen/view/home_sceen_view.dart';
import 'package:pos/modules/items/add_edit_item/binding/add_edit_item_binding.dart';
import 'package:pos/modules/items/add_edit_item/view/add_edit_item_view.dart';
import 'package:pos/modules/items/listing_items/controller/listing_items_controller.dart';
import 'package:pos/modules/items/listing_items/view/listing_items_view.dart';
import 'package:pos/modules/settings/controller/settings_controller.dart';
import 'package:pos/modules/sales/binding/sales_binding.dart';
import 'package:pos/modules/sales/view/sales_view.dart';
import 'package:pos/modules/settings/binding/settings_binding.dart';
import 'package:pos/modules/settings/view/settings_view.dart';
import 'package:pos/modules/checkout/binding/checkout_binding.dart';
import 'package:pos/modules/checkout/view/checkout_view.dart';
import 'package:pos/modules/clients/binding/clients_binding.dart';
import 'package:pos/modules/clients/view/clients_view.dart';

class Routes {
  const Routes._();

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: Paths.homeScreen,
      page: () => HomeScreenView(),
      binding: HomeSceenBinding(),
    ),
    GetPage(
      name: Paths.settingsScreen,
      page: () => SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: Paths.addEditItemScreen,
      page: () => AddEditItemView(),
      binding: AddEditItemBinding(),
    ),
    GetPage(
      name: Paths.itemListingScreen,
      page: () => ListingItemsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => HomeSceenController(), fenix: true);
        Get.lazyPut(() => SettingsController(), fenix: true);
        Get.lazyPut(() => ListingItemsController(), fenix: true);
      }),
    ),
    GetPage(
      name: Paths.salesListingScreen,
      page: () => SalesView(),
      binding: SalesBinding(),
    ),
    GetPage(
      name: Paths.checkout,
      page: () => const CheckoutView(),
      binding: CheckoutBinding(),
    ),
    GetPage(
      name: Paths.clients,
      page: () => const ClientsView(),
      binding: ClientsBinding(),
    ),
  ];
}
