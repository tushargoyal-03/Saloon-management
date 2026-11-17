import 'package:prop_crm/core/constants/api_constants.dart';
import 'package:prop_crm/core/networking/api_client.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_request_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';
import '../models/payment_method_model.dart';

abstract class PaymentRemoteDataSource {
  Future<List<PaymentMethodModel>> getPaymentMethods();
  Future<CreatePayment> createPaymentOrder(CreatePaymentRequest paymentOrder);
  Future<PaymentVerificationResponse> verifyPaymentStatus({
    required String txnId,
    String? paymentId,
  });
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
      subtitle: 'Pay at the salon counter when you arrive for your appointment',
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
            .map((item) => PaymentMethodModel.fromDynamic(item))
            .toList();
      }
    } catch (_) {
      // Fallback to default payment methods when backend endpoint is not reachable
    }
    return defaultPaymentMethods;
  }

  @override
  Future<CreatePayment> createPaymentOrder(CreatePaymentRequest request) async {
    final response = await apiService.post<CreatePayment>(
      ApiConstants.createPaymentOrder,
      data: request.toJson(),
      fromJson: (json) {
        if (json is Map<String, dynamic>) {
          return CreatePayment.fromJson(json);
        } else if (json is Map) {
          return CreatePayment.fromJson(Map<String, dynamic>.from(json));
        }
        throw const FormatException('Invalid payment order response format');
      },
    );

    if (response.data != null) {
      return response.data!;
    }

    throw UnexpectedException(
      message: response.message.isNotEmpty
          ? response.message
          : 'Failed to create payment order.',
    );
  }

  @override
  Future<PaymentVerificationResponse> verifyPaymentStatus({
    required String txnId,
    String? paymentId,
  }) async {
    final response = await apiService.get<PaymentVerificationResponse>(
      ApiConstants.checkPaymentStatus,
      queryParameters: {'txnId': txnId},
      fromJson: (json) {
        if (json is Map<String, dynamic>) {
          return PaymentVerificationResponse.fromJson(json);
        } else if (json is Map) {
          return PaymentVerificationResponse.fromJson(
            Map<String, dynamic>.from(json),
          );
        }
        return const PaymentVerificationResponse(
          success: false,
          message: 'Invalid verification response format',
          status: PaymentStatus.unknown,
        );
      },
    );

    if (response.data != null) {
      return response.data!;
    }

    throw UnexpectedException(
      message: response.message.isNotEmpty
          ? response.message
          : 'Failed to verify payment status.',
    );
  }
}
