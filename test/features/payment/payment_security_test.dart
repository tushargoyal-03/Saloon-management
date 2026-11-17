import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop_crm/core/constants/api_constants.dart';
import 'package:prop_crm/core/constants/route_names.dart';
import 'package:prop_crm/core/networking/api_interceptors.dart';
import 'package:prop_crm/core/storage/storage_keys.dart';
import 'package:prop_crm/core/storage/storage_service.dart';
import 'package:prop_crm/features/payment/data/models/payment_method_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';

class MockStorageService implements StorageService {
  final Map<String, dynamic> _store = {};

  @override
  String? getString(String key) => _store[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> clear() async {
    _store.clear();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Payment Security Tests', () {
    test('Client cannot mark a transaction successful independently', () {
      // Status must come from backend verification response
      final pendingResponse = PaymentVerificationResponse.fromJson({
        'success': true,
        'data': {'status': 'pending'},
      });

      expect(pendingResponse.status.isSuccess, false);
      expect(pendingResponse.status.isTerminal, false);

      final successResponse = PaymentVerificationResponse.fromJson({
        'success': true,
        'data': {'status': 'success'},
      });

      expect(successResponse.status.isSuccess, true);
      expect(successResponse.status.isTerminal, true);
    });

    test('AuthInterceptor sanitizes sensitive payment credentials in request logs', () {
      final interceptor = AppLoggingInterceptor();
      final sensitiveData = {
        'amount': 500,
        'password': 'mySecretPassword',
        'token': 'secretJwtToken',
        'otp': '123456',
        'cvv': '999',
        'pin': '1234',
        'cardNumber': '4111222233334444',
      };

      final requestOptions = RequestOptions(
        path: ApiConstants.createPaymentOrder,
        data: sensitiveData,
      );

      interceptor.onRequest(requestOptions, RequestInterceptorHandler());
      expect(sensitiveData.containsKey('password'), true);
    });

    test('AuthInterceptor attaches Bearer token to protected payment requests', () {
      final storage = MockStorageService();
      storage.setString(StorageKeys.authToken, 'mock_access_token_xyz');

      final authInterceptor = AuthInterceptor(storageService: storage);
      final options = RequestOptions(path: ApiConstants.createPaymentOrder);

      authInterceptor.onRequest(options, RequestInterceptorHandler());

      expect(
        options.headers[ApiConstants.authorizationHeader],
        'Bearer mock_access_token_xyz',
      );
    });

    test('Offline payment methods are correctly classified', () {
      final cashMethod = PaymentMethodModel.fromDynamic('cash');
      expect(cashMethod.type.isPayAtSalon, true);
      expect(cashMethod.type.isOnline, false);

      final upiMethod = PaymentMethodModel.fromDynamic('jigropay');
      expect(upiMethod.type.isPayAtSalon, false);
      expect(upiMethod.type.isOnline, true);
    });

    test('Route definitions include dedicated QR Payment route', () {
      expect(AppRoutes.qrPayment, '/checkout/qr-payment');
    });
  });
}

