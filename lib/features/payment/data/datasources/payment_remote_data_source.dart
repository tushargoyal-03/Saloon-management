import 'package:prop_crm/core/constants/api_constants.dart';
import 'package:prop_crm/core/networking/api_client.dart';
import '../models/payment_method_model.dart';

abstract class PaymentRemoteDataSource {
  Future<List<PaymentMethodModel>> getPaymentMethods();
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final ApiClient apiService;

  PaymentRemoteDataSourceImpl({required this.apiService});

  static const List<PaymentMethodModel> defaultPaymentMethods = [
    PaymentMethodModel(
      id: 'jigropay',
      code: 'jigropay',
      title: 'Instant UPI / QR Code (Jigropay)',
      subtitle:
          'Pay instantly using Google Pay, PhonePe, Paytm, or any UPI App / NetBanking',
      type: PaymentMethodType.upi,
      icon: '⚡',
      iconName: '⚡',
      isAvailable: true,
    ),
    PaymentMethodModel(
      id: 'cash',
      code: 'cash',
      title: 'Pay at Salon (Cash / Card at Desk)',
      subtitle:
          'Pay at the salon counter when you arrive for your appointment',
      type: PaymentMethodType.cod,
      icon: '💵',
      iconName: '💵',
      isAvailable: true,
    ),
  ];

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    try {
      final response = await apiService.get(ApiConstants.paymentMethods);
      final dynamic data = response.data;

      List<dynamic>? rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        if (data['paymentMethods'] is List) {
          rawList = data['paymentMethods'] as List;
        } else if (data['data'] is Map &&
            data['data']['paymentMethods'] is List) {
          rawList = data['data']['paymentMethods'] as List;
        } else if (data['data'] is List) {
          rawList = data['data'] as List;
        } else if (data['methods'] is List) {
          rawList = data['methods'] as List;
        } else if (data['data'] is Map && data['data']['methods'] is List) {
          rawList = data['data']['methods'] as List;
        }
      }

      if (rawList != null && rawList.isNotEmpty) {
        return rawList
            .map(
              (item) => PaymentMethodModel.fromDynamic(item),
            )
            .toList();
      }
    } catch (_) {
      // Fallback to default payment methods when backend endpoint is not reachable
    }
    return defaultPaymentMethods;
  }
}

class MockPaymentRemoteDataSource implements PaymentRemoteDataSource {
  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    // Simulate brief network latency
    await Future.delayed(const Duration(milliseconds: 100));

    return const [
      PaymentMethodModel(
        id: 'jigropay',
        code: 'jigropay',
        title: 'Instant UPI / QR Code (Jigropay)',
        subtitle:
            'Pay instantly using Google Pay, PhonePe, Paytm, or any UPI App / NetBanking',
        type: PaymentMethodType.upi,
        icon: '⚡',
        iconName: '⚡',
        isAvailable: true,
      ),
      PaymentMethodModel(
        id: 'cash',
        code: 'cash',
        title: 'Pay at Salon (Cash / Card at Desk)',
        subtitle:
            'Pay at the salon counter when you arrive for your appointment',
        type: PaymentMethodType.cod,
        icon: '💵',
        iconName: '💵',
        isAvailable: true,
      ),
    ];
  }
}
