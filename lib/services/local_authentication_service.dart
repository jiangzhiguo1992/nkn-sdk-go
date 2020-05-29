import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class LocalAuthenticationService {
  final _localAuth = LocalAuthentication();
  bool isProtectionEnabled = false;
  bool isAuthenticated = false;
  BiometricType authType;

  Future<BiometricType> getAuthType() async {
    try {
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (Platform.isIOS) {
        if (availableBiometrics.contains(BiometricType.face)) {
          return BiometricType.face;
        } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
          return BiometricType.fingerprint;
        }
      }
    } on PlatformException catch (e) {
      debugPrint(e.message);
      debugPrintStack();
    }
  }

  Future<void> authenticate() async {
    if (isProtectionEnabled) {
      try {
        isAuthenticated = await _localAuth.authenticateWithBiometrics(
          localizedReason: 'authenticate to access',
          useErrorDialogs: true,
          stickyAuth: true,
        );
      } on PlatformException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
      }
    }
  }
}
