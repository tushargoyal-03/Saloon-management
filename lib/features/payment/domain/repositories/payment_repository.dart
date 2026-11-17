import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_request_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';

import '../../data/models/payment_method_model.dart';

abstract class PaymentRepository {
  Future<List<PaymentMethodModel>> getPaymentMethods();
  Future<CreatePayment> createPaymentOrder(CreatePaymentRequest request);
  Future<PaymentVerificationResponse> verifyPaymentStatus({
    required String txnId,
    String? paymentId,
  });
}
