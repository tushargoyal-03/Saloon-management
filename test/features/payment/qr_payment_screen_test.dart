import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop_crm/core/constants/route_names.dart';
import 'package:prop_crm/features/addresses/data/models/address_model.dart';
import 'package:prop_crm/features/branches/data/models/branch_model.dart';
import 'package:prop_crm/features/booking_summary/data/models/booking_summary_model.dart';
import 'package:prop_crm/features/booking_summary/data/models/pricing_breakdown_model.dart';
import 'package:prop_crm/features/bookings/data/models/create_booking_request_model.dart';
import 'package:prop_crm/features/bookings/data/models/create_booking_response_model.dart';
import 'package:prop_crm/features/bookings/domain/repositories/booking_repository.dart';
import 'package:prop_crm/features/bookings/presentation/providers/booking_provider.dart';
import 'package:prop_crm/features/date_time/data/models/service_date_model.dart';
import 'package:prop_crm/features/date_time/data/models/time_slot_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_request_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_method_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';
import 'package:prop_crm/features/payment/domain/repositories/payment_repository.dart';
import 'package:prop_crm/features/payment/presentation/providers/payment_provider.dart';
import 'package:prop_crm/features/payment/presentation/screens/qr_payment_screen.dart';
import 'package:prop_crm/features/services/data/models/service_model.dart';
import 'package:provider/provider.dart';

class FakePaymentRepository implements PaymentRepository {
  PaymentVerificationResponse verificationResponse =
      const PaymentVerificationResponse(
        success: true,
        message: 'Pending',
        status: PaymentStatus.pending,
        txnId: 'TXN_TEST_999',
      );

  int verifyCallCount = 0;

  @override
  Future<CreatePayment> createPaymentOrder(CreatePaymentRequest request) async {
    return CreatePayment(
      success: true,
      data: Data(
        txnId: 'TXN_TEST_999',
        qrCodeLink: 'upi://pay?pa=salon@upi&pn=Salon&am=600',
        amount: request.amount.toInt(),
      ),
    );
  }

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    return [];
  }

  @override
  Future<PaymentVerificationResponse> verifyPaymentStatus({
    required String txnId,
    String? paymentId,
  }) async {
    verifyCallCount++;
    return verificationResponse;
  }
}

class FakeBookingRepository implements BookingRepository {
  CreateBookingResponseModel? mockBooking;
  Exception? errorToThrow;
  int createBookingCallCount = 0;

  @override
  Future<CreateBookingResponseModel> createBooking({
    required CreateBookingRequestModel request,
    BookingSummaryModel? summary,
    PaymentMethodModel? paymentMethod,
  }) async {
    createBookingCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return mockBooking ??
        CreateBookingResponseModel(
          appointment: AppointmentModel(
            id: 'app_1',
            appointmentCode: 'APP-100',
            date: '2026-11-20',
            timeSlot: '14:30',
            status: 'confirmed',
            finalAmount: 600,
          ),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePaymentRepository fakePaymentRepo;
  late FakeBookingRepository fakeBookingRepo;
  late PaymentProvider paymentProvider;
  late BookingProvider bookingProvider;

  setUp(() {
    fakePaymentRepo = FakePaymentRepository();
    fakeBookingRepo = FakeBookingRepository();
    paymentProvider = PaymentProvider(repository: fakePaymentRepo);
    bookingProvider = BookingProvider(repository: fakeBookingRepo);
  });

  Widget createWidgetUnderTest() {
    final summary = BookingSummaryModel(
      service: const ServiceModel(
        id: 'srv_1',
        categoryId: 'cat_1',
        name: 'Deluxe Facial',
        description: 'Facial',
        startingPrice: 600,
      ),
      address: const AddressModel(
        id: 'addr_1',
        userId: 'user_1',
        label: 'Home',
        houseNumber: '12',
        addressLine: 'MG Road',
        city: 'Bangalore',
        state: 'Karnataka',
        pincode: '560001',
      ),
      scheduledDate: ServiceDateModel(
        date: DateTime(2026, 11, 20),
        isAvailable: true,
      ),
      timeSlot: const TimeSlotModel(
        id: '14:30',
        startTime: '14:30',
        endTime: '15:15',
        isAvailable: true,
      ),
      branch: const BranchModel(
        id: 'branch_1',
        name: 'Downtown',
        address: '1st Ave',
        phone: '9876543210',
      ),
      pricing: const PricingBreakdown(
        packagePrice: 600,
        discount: 0,
        taxRate: 0,
        taxAmount: 0,
        totalAmount: 600,
      ),
    );

    final paymentData = Data(
      txnId: 'TXN_TEST_999',
      qrCodeLink: 'upi://pay?pa=salon@upi&pn=Salon&am=600',
      amount: 600,
    );

    final selectedMethod = PaymentMethodModel.fromDynamic('jigropay');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PaymentProvider>.value(value: paymentProvider),
        ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
      ],
      child: MaterialApp(
        routes: {
          AppRoutes.bookingConfirmation: (context) =>
              const Scaffold(body: Text('Booking Confirmed')),
        },
        home: QrPaymentScreen(
          paymentData: paymentData,
          summary: summary,
          selectedMethod: selectedMethod,
        ),
      ),
    );
  }

  group('QrPaymentScreen Widget Tests', () {
    testWidgets('renders amount, transaction ID, instructions and pending badge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: true,
        message: 'Pending',
        status: PaymentStatus.pending,
        txnId: 'TXN_TEST_999',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Check amount displayed
      expect(find.text('₹600.00'), findsOneWidget);
      expect(find.text('Deluxe Facial'), findsOneWidget);

      // Check transaction ID displayed
      expect(find.text('TXN_TEST_999'), findsOneWidget);

      // Check payment instructions
      expect(find.text('Payment Instructions'), findsOneWidget);
      expect(
        find.text('Open Google Pay, PhonePe, Paytm, BHIM, or any UPI app.'),
        findsOneWidget,
      );

      // Check pending status and action button
      expect(find.text("I've Paid — Check Status"), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('manual check triggers status check and updates state to success', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: true,
        message: 'Pending',
        status: PaymentStatus.pending,
        txnId: 'TXN_TEST_999',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text("I've Paid — Check Status"), findsOneWidget);

      // Change verification response to Success
      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: true,
        message: 'Payment completed',
        status: PaymentStatus.success,
        txnId: 'TXN_TEST_999',
      );

      // Tap manual check
      await tester.tap(find.text("I've Paid — Check Status"));
      await tester.pump();
      await tester.pumpAndSettle();

      // Should transition to success and call finalize booking
      expect(fakeBookingRepo.createBookingCallCount, 1);
      expect(find.text('Booking Confirmed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('displays failed status when backend reports failed transaction', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: true,
        message: 'Pending',
        status: PaymentStatus.pending,
        txnId: 'TXN_TEST_999',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Update response to Failed
      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: false,
        message: 'Bank server declined the transaction.',
        status: PaymentStatus.failed,
        statusString: 'Failed',
        txnId: 'TXN_TEST_999',
      );

      // Trigger status check
      await tester.tap(find.text("I've Paid — Check Status"));
      await tester.pump();

      expect(find.text('Payment Failed'), findsOneWidget);
      expect(find.text('Return to Checkout'), findsOneWidget);
      expect(fakeBookingRepo.createBookingCallCount, 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('displays reconciliation card when booking creation fails after payment succeeds', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: true,
        message: 'Pending',
        status: PaymentStatus.pending,
        txnId: 'TXN_TEST_999',
      );

      // Simulate server error during booking creation
      fakeBookingRepo.errorToThrow = Exception('Booking server timeout');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Transition to Success
      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: true,
        message: 'Payment completed',
        status: PaymentStatus.success,
        txnId: 'TXN_TEST_999',
      );

      // Trigger status check
      await tester.tap(find.text("I've Paid — Check Status"));
      await tester.pumpAndSettle();

      // Reconciliation card must appear preserving txnId and providing retry
      expect(
        find.text('Payment Verified — Finalizing Booking'),
        findsOneWidget,
      );
      expect(find.text('Retry Finalizing Booking'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not navigate to booking confirmation while status is pending or failed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: true,
        message: 'Pending',
        status: PaymentStatus.pending,
        txnId: 'TXN_TEST_999',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(seconds: 4));

      // User must still be on the QR payment screen, NOT booking confirmation
      expect(find.text('Scan & Pay'), findsOneWidget);
      expect(find.text('Booking Confirmed'), findsNothing);
      expect(fakeBookingRepo.createBookingCallCount, 0);

      // Now update to Failed
      fakePaymentRepo.verificationResponse = const PaymentVerificationResponse(
        success: false,
        message: 'Failed',
        status: PaymentStatus.failed,
        statusString: 'Failed',
        txnId: 'TXN_TEST_999',
      );

      await tester.tap(find.text("I've Paid — Check Status"));
      await tester.pumpAndSettle();

      // User must still be on the payment screen, NOT booking confirmation
      expect(find.text('Scan & Pay'), findsOneWidget);
      expect(find.text('Payment Failed'), findsOneWidget);
      expect(find.text('Booking Confirmed'), findsNothing);
      expect(fakeBookingRepo.createBookingCallCount, 0);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
