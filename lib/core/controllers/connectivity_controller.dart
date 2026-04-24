import 'dart:async';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/ui_utils.dart';

/// Monitors network connectivity for offline support using GetX.
class ConnectivityController extends GetxController {
  final RxBool _isOnline = true.obs;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  bool get isOnline => _isOnline.value;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  void _init() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final newStatus = results.any((r) => r != ConnectivityResult.none);
      if (newStatus != _isOnline.value) {
        _isOnline.value = newStatus;
        if (newStatus) {
          UIUtils.showSuccess('Internet connection restored.');
        } else {
          UIUtils.showError('No internet connection detected.');
        }
      }
    });

    // Check initial connectivity
    Connectivity().checkConnectivity().then((results) {
      _isOnline.value = results.any((r) => r != ConnectivityResult.none);
    });
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }
}
