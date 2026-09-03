import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:pos/core/routes/routes.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/http_client/local_storage/local_storage_helpers.dart';

/// Every box the app opens at startup. Mirrors HiveService._openBoxes.
const List<String> kPosBoxes = <String>[
  'userBox',
  'settingsBox',
  'itemsBox',
  'clientsBox',
  'salesBox',
];

Directory? _hiveDir;

/// Boots Hive against a throwaway directory and opens the app's boxes.
///
/// [HiveService.init] is not reusable in tests because `Hive.initFlutter()`
/// goes through path_provider, so we stand up the same boxes by hand.
Future<void> bootStorage() async {
  // Outside a real route, SmartManagement.full garbage-collects controllers
  // that no route claims, which would make these tests flaky for reasons that
  // have nothing to do with the app.
  Get.testMode = true;
  Get.smartManagement = SmartManagement.onlyBuilder;
  // flutter_test stubs HTTP to fail fast, so the font request resolves as a
  // miss and google_fonts falls back. Disabling runtime fetching instead makes
  // it throw, because the app bundles no font assets.
  GoogleFonts.config.allowRuntimeFetching = true;
  _hiveDir ??= await Directory.systemTemp.createTemp('pos_test_hive');
  Hive.init(_hiveDir!.path);
  for (final box in kPosBoxes) {
    if (!Hive.isBoxOpen(box)) {
      await Hive.openBox(box);
    }
  }
  for (final box in kPosBoxes) {
    await Hive.box(box).clear();
  }
}

/// Closes every box and reopens it from disk — the test equivalent of the
/// user killing the app and launching it again. Anything that only survives
/// in memory is gone after this.
Future<void> restartApp() async {
  await Hive.close();
  for (final box in kPosBoxes) {
    await Hive.openBox(box);
  }
}

/// Registers a controller for the duration of a test, immune to GetX's
/// route-scoped cleanup.
T register<T>(T controller) => Get.put<T>(controller, permanent: true);

Future<void> tearDownStorage() async {
  Get.reset();
  await Hive.close();
}

/// Seeds the catalog the way the app itself writes it.
Future<void> seedCatalog({
  required List<String> categories,
  required List<AddEditItemModel> products,
}) async {
  await LocalStorageHelpers.storeJsonList(
    'itemsBox',
    'categories',
    categories.map((c) => {'name': c}).toList(),
  );
  await LocalStorageHelpers.storeJsonList(
    'itemsBox',
    'products',
    products.map((p) => p.toJson()).toList(),
  );
}

AddEditItemModel product({
  required String description,
  required String category,
  String? barcode,
  double sellingPrice = 10.0,
  double costPrice = 5.0,
  int quantity = 100,
}) {
  return AddEditItemModel(
    description: description,
    category: category,
    barcode: barcode,
    quantity: quantity,
    costPrice: costPrice,
    sellingPrice: sellingPrice,
    tvaPercent: 0,
    priceAfterTva: costPrice,
    profitPercent: 0,
  );
}

/// The real app shell, so navigation, bindings and route arguments behave
/// exactly as they do in production.
Widget posApp({String initialRoute = '/home_screen'}) {
  return GetMaterialApp(
    initialRoute: initialRoute,
    getPages: Routes.routes,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
  );
}

/// Bounded settle. `pumpAndSettle` is a trap here: any in-flight font request
/// or debounce timer makes it spin until its ten-minute timeout.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Hive writes to a real disk. Inside `testWidgets` the fake clock never lets
/// those futures complete, so every storage call has to escape to real async.
Future<T> withStorage<T>(WidgetTester tester, Future<T> Function() body) async {
  final result = await tester.runAsync(body);
  return result as T;
}

/// Sizes the test surface like the tablet this POS actually runs on, so
/// layout assertions reflect the real device rather than the 800x600 default.
Future<void> useTabletSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2360, 1640);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Runs a controller action that writes to disk, then lets the write finish.
/// Storage calls are fire-and-forget in the app, and a pending Hive write is
/// enough for `testWidgets` to fail the test at teardown.
Future<void> act(WidgetTester tester, FutureOr<void> Function() body) async {
  // The action itself has to run in the widget-test zone, or form validation
  // and navigation misbehave. Only the disk flush escapes to real async.
  await tester.runAsync(() async {
    await body();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
}
