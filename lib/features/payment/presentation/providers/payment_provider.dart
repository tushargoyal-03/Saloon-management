import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:prop_crm/core/base/view_state.dart';
import 'package:prop_crm/core/error/error_handler.dart';
import 'package:prop_crm/core/networking/api_client.dart';
import 'package:prop_crm/features/booking_summary/data/models/booking_summary_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_request_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';
import '../../data/models/payment_method_model.dart';
import '../../domain/repositories/payment_repository.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentRepository repository;

  ViewState<List<PaymentMethodModel>> _methodsState = ViewState.initial();
  PaymentMethodModel? _selectedMethod;
  BookingSummaryModel? _bookingSummary;
  bool _isProcessing = false;
  ViewState<CreatePayment> _createPaymentState = ViewState.initial();
  ViewState<PaymentVerificationResponse> _verificationState =
      ViewState.initial();

  // Automatic Polling state controls
  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isVerifying = false;
  String? _activePollingTxnId;
  String? _activePaymentId;
  PaymentStatus _paymentStatus = PaymentStatus.pending;

  PaymentProvider({required this.repository});

  ViewState<List<PaymentMethodModel>> get methodsState => _methodsState;
  ViewState<CreatePayment> get createPaymentState => _createPaymentState;
  ViewState<PaymentVerificationResponse> get verificationState =>
      _verificationState;

  List<PaymentMethodModel> get paymentMethods => _methodsState.data ?? [];
  PaymentMethodModel? get selectedMethod => _selectedMethod;
  BookingSummaryModel? get bookingSummary => _bookingSummary;
  CreatePayment? get activePaymentOrder => _createPaymentState.data;

  bool get isLoading => _methodsState.isLoading;
  bool get hasError => _methodsState.isError;
  String? get errorMessage => _methodsState.errorMessage;
  bool get isProcessing => _isProcessing;

  // Polling getters
  bool get isPolling => _isPolling;
  bool get isVerifying => _isVerifying;
  PaymentStatus get paymentStatus => _paymentStatus;
  String? get activePollingTxnId => _activePollingTxnId;

  /// Payable amount strictly derived from the Booking Summary source of truth
  double get payableAmount => _bookingSummary?.pricing.totalAmount ?? 0.0;

  /// Selection is valid only when an available payment method is selected
  bool get isSelectionValid =>
      _selectedMethod != null && _selectedMethod!.isAvailable;

  /// Updates or syncs the active booking summary context
  void setBookingSummary(BookingSummaryModel? summary) {
    _bookingSummary = summary;
    notifyListeners();
  }

  /// Loads available payment options from the dynamic API
  Future<void> loadPaymentMethods({bool forceRefresh = false}) async {
    if (!forceRefresh && _methodsState.isSuccess && paymentMethods.isNotEmpty) {
      return;
    }

    _methodsState = ViewState.loading();
    notifyListeners();

    try {
      final methods = await repository.getPaymentMethods();
      if (methods.isEmpty) {
        _methodsState = ViewState.empty();
        _selectedMethod = null;
      } else {
        _methodsState = ViewState.success(methods);

        // Preserve selected method if still present and valid, otherwise pre-select first available
        if (_selectedMethod != null) {
          final existsIndex = methods.indexWhere(
            (m) =>
                m.id == _selectedMethod!.id ||
                (m.code != null && m.code == _selectedMethod!.code),
          );
          if (existsIndex != -1) {
            _selectedMethod = methods[existsIndex];
          } else {
            _selectedMethod = methods.firstWhere(
              (m) => m.isAvailable,
              orElse: () => methods.first,
            );
          }
        } else {
          // Pre-select first available method for smooth checkout flow
          _selectedMethod = methods.firstWhere(
            (m) => m.isAvailable,
            orElse: () => methods.first,
          );
        }
      }
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      _methodsState = ViewState.error(
        appError.message,
        statusCode: appError.statusCode,
      );
    }

    notifyListeners();
  }

  /// Creates a payment order via backend API
  /// Returns the parsed CreatePayment model, or null on error
  Future<CreatePayment?> createPaymentOrder({
    required CreatePaymentRequest request,
  }) async {
    if (_createPaymentState.isLoading || _isProcessing) {
      return null;
    }

    _isProcessing = true;
    _createPaymentState = ViewState.loading();
    notifyListeners();

    try {
      final payment = await repository.createPaymentOrder(request);

      final txnId = payment.data?.txnId;
      if (txnId == null || txnId.trim().isEmpty) {
        throw UnexpectedException(
          message:
              'Payment order was created, but transaction ID was missing from server response.',
        );
      }

      _createPaymentState = ViewState.success(payment);
      _isProcessing = false;
      notifyListeners();
      return payment;
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      _createPaymentState = ViewState.error(
        appError.message,
        statusCode: appError.statusCode,
      );
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  /// Starts automatic 3-second payment status polling using the transaction ID
  void startPaymentPolling({
    required String txnId,
    String? paymentId,
  }) {
    if (txnId.trim().isEmpty) return;

    // Prevent duplicate polling loops for the same active transaction
    if (_isPolling && _activePollingTxnId == txnId) {
      return;
    }

    stopPaymentPolling();

    _activePollingTxnId = txnId;
    _activePaymentId = paymentId;
    _isPolling = true;
    _paymentStatus = PaymentStatus.pending;
    notifyListeners();

    // Perform an immediate initial status verification
    verifyPaymentStatus(txnId: txnId, paymentId: paymentId);

    // Schedule 3-second periodic polling
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isPolling || _paymentStatus.isTerminal) {
        timer.cancel();
        _isPolling = false;
        return;
      }

      // Avoid overlapping requests if one check takes longer than 3 seconds
      if (!_isVerifying) {
        await verifyPaymentStatus(txnId: txnId, paymentId: paymentId);
      }
    });
  }

  /// Stops automatic polling immediately
  void stopPaymentPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _isVerifying = false;
  }

  /// Resumes polling and verifies immediately upon app coming to foreground
  Future<void> resumeAndVerify() async {
    if (_isPolling &&
        _activePollingTxnId != null &&
        !_paymentStatus.isTerminal &&
        !_isVerifying) {
      await verifyPaymentStatus(
        txnId: _activePollingTxnId!,
        paymentId: _activePaymentId,
      );
    }
  }

  /// Verifies transaction payment status using trusted backend API
  Future<PaymentVerificationResponse?> verifyPaymentStatus({
    required String txnId,
    String? paymentId,
  }) async {
    // Prevent overlapping verification requests
    if (_isVerifying) {
      return _verificationState.data;
    }

    _isVerifying = true;
    _verificationState = ViewState.loading();
    notifyListeners();

    try {
      final response = await repository.verifyPaymentStatus(
        txnId: txnId,
        paymentId: paymentId,
      );

      // Validate returned transaction ID matches requested transaction ID
      if (response.txnId != null &&
          response.txnId!.isNotEmpty &&
          response.txnId != txnId) {
        throw UnexpectedException(
          message:
              'Transaction ID mismatch in status verification response (expected $txnId, got ${response.txnId}).',
        );
      }

      _paymentStatus = response.status;
      _verificationState = ViewState.success(response);

      // Stop polling immediately when terminal status is reached
      if (response.status.isTerminal) {
        stopPaymentPolling();
      }

      _isVerifying = false;
      notifyListeners();
      return response;
    } catch (e) {
      // Temporary network failure or timeout:
      // Do NOT mark transaction as failed. Preserve existing transaction and pending status.
      final appError = ErrorHandler.handleError(e);
      _verificationState = ViewState.error(
        appError.message,
        statusCode: appError.statusCode,
      );
      _isVerifying = false;
      notifyListeners();
      return null;
    }
  }

  /// Selects a payment method if available
  void selectPaymentMethod(PaymentMethodModel method) {
    if (!method.isAvailable) {
      return;
    }
    _selectedMethod = method;
    notifyListeners();
  }

  /// Clears the active selection
  void clearSelection() {
    _selectedMethod = null;
    notifyListeners();
  }

  /// Sets processing state
  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  /// Resets payment order & verification states
  void resetPaymentOrderState() {
    stopPaymentPolling();
    _createPaymentState = ViewState.initial();
    _verificationState = ViewState.initial();
    _paymentStatus = PaymentStatus.pending;
    _activePollingTxnId = null;
    _activePaymentId = null;
    _isProcessing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPaymentPolling();
    super.dispose();
  }
}
