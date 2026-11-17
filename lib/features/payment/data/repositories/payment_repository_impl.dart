import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_request_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';

import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_remote_data_source.dart';
import '../models/payment_method_model.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;

  PaymentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    return await remoteDataSource.getPaymentMethods();
  }

  @override
  Future<CreatePayment> createPaymentOrder(CreatePaymentRequest request) async {
    return await remoteDataSource.createPaymentOrder(request);
  }

  @override
  Future<PaymentVerificationResponse> verifyPaymentStatus({
    required String txnId,
    String? paymentId,
  }) async {
    return await remoteDataSource.verifyPaymentStatus(
      txnId: txnId,
      paymentId: paymentId,
    );
  }
}
