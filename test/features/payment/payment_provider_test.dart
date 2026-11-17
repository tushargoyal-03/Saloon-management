import 'package:flutter_test/flutter_test.dart';
import 'package:prop_crm/core/base/view_state.dart';
import 'package:prop_crm/core/error/app_error.dart';
import 'package:prop_crm/features/booking_summary/data/models/booking_summary_model.dart';
import 'package:prop_crm/features/booking_summary/data/models/pricing_breakdown_model.dart';
import 'package:prop_crm/features/date_time/data/models/service_date_model.dart';
import 'package:prop_crm/features/date_time/data/models/time_slot_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_request_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_method_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';
import 'package:prop_crm/features/payment/domain/repositories/payment_repository.dart';
import 'package:prop_crm/features/payment/presentation/providers/payment_provider.dart';
import 'package:prop_crm/features/services/data/models/service_model.dart';

class MockPaymentRepository implements PaymentRepository {
  List<PaymentMethodModel> mockMethods = [];
  CreatePayment? mockCreatePayment;
  PaymentVerificationResponse? mockVerification;
  Exception? errorToThrow;
  int createPaymentOrderCallCount = 0;
  int verifyPaymentCallCount = 0;
  CreatePaymentRequest? lastCreateRequest;

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    if (errorToThrow != null) throw errorToThrow!;
    return mockMethods;
  }

  @override
  Future<CreatePayment> createPaymentOrder(CreatePaymentRequest request) async {
    createPaymentOrderCallCount++;
    lastCreateRequest = request;
    if (errorToThrow != null) throw errorToThrow!;
    return mockCreatePayment ??
        CreatePayment(
          success: true,
          message: 'Order created',
          data: Data(
            txnId: 'TXN_TEST_123',
            qrCodeLink: 'https://jigropay.com/qr/123.png',
            amount: request.amount.toInt(),
          ),
        );
  }

  @override
  Future<PaymentVerificationResponse> verifyPaymentStatus({
    required String txnId,
    String? paymentId,
  }) async {
    verifyPaymentCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return mockVerification ??
        PaymentVerificationResponse(
          success: true,
          message: 'Verified',
          status: PaymentStatus.success,
          txnId: txnId,
          paymentId: paymentId,
        );
  }
}

BookingSummaryModel createDummySummary({required double amount}) {
  return BookingSummaryModel(
    service: const ServiceModel(
      id: 'srv_1',
      name: 'Signature Haircut',
      description: 'Haircut',
      price: 500,
      finalPrice: 500,
      durationMinutes: 45,
      genderCategory: 'Unisex',
    ),
    scheduledDate: ServiceDateModel(date: DateTime(2026, 11, 20)),
    timeSlot: const TimeSlotModel(
      time: '14:30',
      period: 'PM',
      isAvailable: true,
    ),
    pricing: PricingBreakdownModel(
      subtotal: amount,
      discount: 0,
      tax: 0,
      finalAmount: amount,
    ),
  );
}

void main() {
  late MockPaymentRepository mockRepo;
  late PaymentProvider provider;

  setUp(() {
    mockRepo = MockPaymentRepository();
    provider = PaymentProvider(repository: mockRepo);
  });

  group('PaymentProvider Tests', () {
    test('payableAmount is strictly derived from BookingSummaryModel', () {
      expect(provider.payableAmount, 0.0);

      final summary = createDummySummary(amount: 750.0);
      provider.setBookingSummary(summary);

      expect(provider.payableAmount, 750.0);
    });

    test(
      'createPaymentOrder sends actual request parameters to repository',
      () async {
        final request = CreatePaymentRequest(
          amount: 500.0,
          name: 'Sarah Connor',
          mobileNo: '9876543210',
          emailAddress: 'sarah@example.com',
          remark: 'Booking for Signature Haircut',
        );

        final result = await provider.createPaymentOrder(request: request);

        expect(result, isNotNull);
        expect(mockRepo.createPaymentOrderCallCount, 1);
        expect(mockRepo.lastCreateRequest!.amount, 500.0);
        expect(mockRepo.lastCreateRequest!.name, 'Sarah Connor');
        expect(provider.createPaymentState.isSuccess, true);
      },
    );

    test(
      'createPaymentOrder fails when transaction ID is missing from response',
      () async {
        mockRepo.mockCreatePayment = CreatePayment(
          success: true,
          data: Data(txnId: '', qrCodeLink: 'https://jigropay.com/qr'),
        );

        final request = CreatePaymentRequest(
          amount: 200.0,
          name: 'John',
          mobileNo: '9876543210',
          emailAddress: 'john@example.com',
          remark: 'Test',
        );

        final result = await provider.createPaymentOrder(request: request);

        expect(result, isNull);
        expect(provider.createPaymentState.isError, true);
        expect(
          provider.createPaymentState.errorMessage,
          contains('transaction ID was missing'),
        );
      },
    );

    test(
      'createPaymentOrder prevents duplicate requests while loading',
      () async {
        final request = CreatePaymentRequest(
          amount: 300.0,
          name: 'Alice',
          mobileNo: '9876543210',
          emailAddress: 'alice@example.com',
          remark: 'Test',
        );

        // Simulate first call in flight
        provider.createPaymentOrder(request: request);
        // Attempt duplicate call immediately
        final duplicateResult = await provider.createPaymentOrder(
          request: request,
        );

        expect(duplicateResult, isNull);
        expect(mockRepo.createPaymentOrderCallCount, 1);
      },
    );

    test('verifyPaymentStatus verifies transaction with backend', () async {
      mockRepo.mockVerification = const PaymentVerificationResponse(
        success: true,
        message: 'Payment completed',
        status: PaymentStatus.success,
        txnId: 'TXN_TEST_123',
      );

      final result = await provider.verifyPaymentStatus(txnId: 'TXN_TEST_123');

      expect(result, isNotNull);
      expect(result!.status, PaymentStatus.success);
      expect(mockRepo.verifyPaymentCallCount, 1);
      expect(provider.verificationState.isSuccess, true);
    });

    test(
      'verifyPaymentStatus prevents multiple simultaneous polling requests',
      () async {
        mockRepo.mockVerification = const PaymentVerificationResponse(
          success: true,
          message: 'Pending',
          status: PaymentStatus.pending,
          txnId: 'TXN_123',
        );

        provider.verifyPaymentStatus(txnId: 'TXN_123');
        final duplicateCheck = await provider.verifyPaymentStatus(
          txnId: 'TXN_123',
        );

        // Returns the current data without making another repo call
        expect(mockRepo.verifyPaymentCallCount, 1);
      },
    );

    test('startPaymentPolling prevents duplicate polling loops for same txnId', () {
      mockRepo.mockVerification = const PaymentVerificationResponse(
        success: true,
        message: 'Pending',
        status: PaymentStatus.pending,
        txnId: 'TXN_POLL_1',
      );

      provider.startPaymentPolling(txnId: 'TXN_POLL_1');
      expect(provider.isPolling, true);
      expect(provider.activePollingTxnId, 'TXN_POLL_1');
      expect(mockRepo.verifyPaymentCallCount, 1);

      // Call startPaymentPolling again with same txnId
      provider.startPaymentPolling(txnId: 'TXN_POLL_1');
      // Should not spawn a second loop or call again immediately
      expect(mockRepo.verifyPaymentCallCount, 1);

      provider.stopPaymentPolling();
      expect(provider.isPolling, false);
    });

    test('verifyPaymentStatus stops polling immediately on terminal status (Success)', () async {
      mockRepo.mockVerification = const PaymentVerificationResponse(
        success: true,
        message: 'Success',
        status: PaymentStatus.success,
        txnId: 'TXN_TERM_1',
      );

      provider.startPaymentPolling(txnId: 'TXN_TERM_1');
      await provider.verifyPaymentStatus(txnId: 'TXN_TERM_1');

      expect(provider.paymentStatus, PaymentStatus.success);
      expect(provider.isPolling, false);
    });

    test('verifyPaymentStatus stops polling immediately on terminal status (Failed)', () async {
      mockRepo.mockVerification = const PaymentVerificationResponse(
        success: false,
        message: 'Failed',
        status: PaymentStatus.failed,
        txnId: 'TXN_TERM_2',
      );

      provider.startPaymentPolling(txnId: 'TXN_TERM_2');
      await provider.verifyPaymentStatus(txnId: 'TXN_TERM_2');

      expect(provider.paymentStatus, PaymentStatus.failed);
      expect(provider.isPolling, false);
    });

    test('verifyPaymentStatus does not mark transaction as failed on network timeout', () async {
      mockRepo.errorToThrow = Exception('Network connection timed out');

      provider.startPaymentPolling(txnId: 'TXN_TIMEOUT');
      final result = await provider.verifyPaymentStatus(txnId: 'TXN_TIMEOUT');

      expect(result, isNull);
      // Status remains pending so polling can continue
      expect(provider.paymentStatus, PaymentStatus.pending);
      expect(provider.verificationState.isError, true);

      provider.stopPaymentPolling();
    });

    test('verifyPaymentStatus rejects mismatched transaction ID response', () async {
      mockRepo.mockVerification = const PaymentVerificationResponse(
        success: true,
        message: 'Success',
        status: PaymentStatus.success,
        txnId: 'TXN_DIFFERENT_XYZ',
      );

      final result = await provider.verifyPaymentStatus(txnId: 'TXN_REQUESTED_123');

      expect(result, isNull);
      expect(provider.verificationState.isError, true);
      expect(provider.verificationState.errorMessage, contains('mismatch'));
    });

    test('resetPaymentOrderState resets provider state', () {
      provider.resetPaymentOrderState();
      expect(provider.createPaymentState.isInitial, true);
      expect(provider.verificationState.isInitial, true);
      expect(provider.isProcessing, false);
      expect(provider.isPolling, false);
      expect(provider.paymentStatus, PaymentStatus.pending);
    });
  });
}
