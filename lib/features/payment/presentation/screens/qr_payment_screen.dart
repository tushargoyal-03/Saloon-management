import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prop_crm/core/constants/app_colors.dart';
import 'package:prop_crm/core/constants/app_typography.dart';
import 'package:prop_crm/core/constants/route_names.dart';
import 'package:prop_crm/core/utilities/formatters.dart';
import 'package:prop_crm/core/widgets/app_button.dart';
import 'package:prop_crm/core/widgets/app_dialog.dart';
import 'package:prop_crm/core/widgets/custom_app_bar.dart';
import 'package:prop_crm/features/booking_summary/data/models/booking_summary_model.dart';
import 'package:prop_crm/features/bookings/presentation/providers/booking_provider.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_method_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';
import 'package:prop_crm/features/payment/presentation/providers/payment_provider.dart';
import 'package:prop_crm/features/payment/presentation/widgets/qr_code_view.dart';
import 'package:prop_crm/features/services/data/models/service_products_response.dart';
import 'package:provider/provider.dart';

class QrPaymentScreen extends StatefulWidget {
  final Data paymentData;
  final BookingSummaryModel summary;
  final PaymentMethodModel selectedMethod;
  final ConsumableProduct? selectedProduct;

  const QrPaymentScreen({
    super.key,
    required this.paymentData,
    required this.summary,
    required this.selectedMethod,
    this.selectedProduct,
  });

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen>
    with WidgetsBindingObserver {
  PaymentProvider? _paymentProvider;
  Timer? _countdownTimer;
  static const int _totalDurationSeconds = 600; // 10 minutes expiry window
  int _secondsRemaining = _totalDurationSeconds;
  bool _isExpired = false;

  // Booking finalization and navigation state
  bool _isFinalizingBooking = false;
  bool _bookingFinalizeFailed = false;
  String? _bookingErrorMessage;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final txnId = widget.paymentData.txnId;
      if (txnId != null && txnId.isNotEmpty && mounted) {
        final paymentProvider = context.read<PaymentProvider>();
        _paymentProvider = paymentProvider;
        paymentProvider.addListener(_onPaymentStateChanged);
        paymentProvider.startPaymentPolling(
          txnId: txnId,
          paymentId: widget.paymentData.paymentId,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paymentProvider = context.read<PaymentProvider>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentProvider?.removeListener(_onPaymentStateChanged);
    _paymentProvider?.stopPaymentPolling();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // User likely returned from their UPI application (GPay, PhonePe, Paytm).
      // Resume and verify transaction immediately.
      _paymentProvider?.resumeAndVerify();
    }
  }

  void _onPaymentStateChanged() {
    if (!mounted) return;
    final paymentProvider = _paymentProvider ?? context.read<PaymentProvider>();
    final status = paymentProvider.paymentStatus;

    if (status == PaymentStatus.failed || status == PaymentStatus.expired) {
      _countdownTimer?.cancel();
    }

    if (status == PaymentStatus.success &&
        !_isFinalizingBooking &&
        !_hasNavigated) {
      _countdownTimer?.cancel();
      _finalizeBooking();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isExpired = true;
        });
        context.read<PaymentProvider>().stopPaymentPolling();
      }
    });
  }

  /// Finalizes booking creation after payment is verified by the backend
  Future<void> _finalizeBooking() async {
    if (_isFinalizingBooking || _hasNavigated) return;

    final paymentProvider = context.read<PaymentProvider>();
    paymentProvider.stopPaymentPolling();

    setState(() {
      _isFinalizingBooking = true;
      _bookingFinalizeFailed = false;
      _bookingErrorMessage = null;
    });

    try {
      final bookingProvider = context.read<BookingProvider>();

      final booking = await bookingProvider.createBooking(
        summary: widget.summary,
        paymentMethod: widget.selectedMethod,
        selectedProduct: widget.selectedProduct,
        transactionId: widget.paymentData.txnId,
        paymentId: widget.paymentData.paymentId,
      );

      if (!mounted) return;

      if (booking != null) {
        _hasNavigated = true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.bookingConfirmation,
          (route) =>
              route.settings.name == AppRoutes.mainNav || route.isFirst,
          arguments: {'booking': booking},
        );
      } else {
        setState(() {
          _bookingFinalizeFailed = true;
          _bookingErrorMessage =
              bookingProvider.errorMessage ??
              'Payment succeeded, but appointment finalization encountered a delay. Tap below to complete your booking.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bookingFinalizeFailed = true;
          _bookingErrorMessage =
              'Payment confirmed, but booking creation was interrupted: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFinalizingBooking = false;
        });
      }
    }
  }

  Future<bool> _handleOnBackPressed() async {
    final paymentProvider = context.read<PaymentProvider>();
    final currentStatus = _isExpired
        ? PaymentStatus.expired
        : paymentProvider.paymentStatus;

    if (currentStatus == PaymentStatus.success) {
      return false; // Prevent navigating away while finalizing booking
    }

    if (currentStatus == PaymentStatus.pending) {
      final shouldExit = await AppDialog.confirm(
        context: context,
        title: 'Cancel Payment?',
        message:
            'If you have already scanned and paid in your UPI app, please wait for confirmation. Exiting now may interrupt your booking.',
        confirmText: 'Exit Payment',
        cancelText: 'Wait & Confirm',
      );

      if (shouldExit == true) {
        paymentProvider.stopPaymentPolling();
        return true;
      }
      return false;
    }

    paymentProvider.stopPaymentPolling();
    return true;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatRemainingTime() {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = context.watch<PaymentProvider>();
    final currentStatus = _isExpired
        ? PaymentStatus.expired
        : paymentProvider.paymentStatus;

    final txnId = widget.paymentData.txnId ?? 'N/A';
    final payableAmount = widget.summary.pricing.totalAmount;
    final qrData = widget.paymentData.qrCodeLink;

    final verificationState = paymentProvider.verificationState;
    final isVerifying = paymentProvider.isVerifying;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _handleOnBackPressed();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Scan & Pay',
          showBackButton: true,
          onBackPressed: () async {
            final shouldPop = await _handleOnBackPressed();
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Amount Banner Card
                  _buildAmountBanner(payableAmount),
                  const SizedBox(height: 20),

                  // 2. Status Indicator Badge
                  _buildStatusBadge(currentStatus, isVerifying),
                  const SizedBox(height: 8),

                  // Status explanation / live feedback
                  _buildStatusMessage(currentStatus, verificationState),
                  const SizedBox(height: 20),

                  // 3. QR Code Presentation Card
                  _buildQrCard(qrData),
                  const SizedBox(height: 20),

                  // 4. Transaction Reference ID Card
                  _buildTransactionIdTile(txnId),
                  const SizedBox(height: 20),

                  // 5. Payment Instructions & UPI Guidelines
                  _buildInstructionsCard(),
                  const SizedBox(height: 24),

                  // 6. Reconciliation State (If payment succeeded but booking creation failed)
                  if (_bookingFinalizeFailed) ...[
                    _buildReconciliationCard(txnId),
                    const SizedBox(height: 20),
                  ],

                  // 7. Interactive Action Buttons
                  _buildActionButtons(currentStatus, isVerifying),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountBanner(double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Payable Amount',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.summary.service.name,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          Text(
            AppFormatters.formatCurrency(amount, showDecimals: true),
            style: AppTypography.priceLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PaymentStatus status, bool isVerifying) {
    Color badgeColor;
    Color textColor;
    IconData badgeIcon;
    String badgeLabel;

    switch (status) {
      case PaymentStatus.pending:
        badgeColor = AppColors.warningLight;
        textColor = AppColors.warning;
        badgeIcon = Icons.hourglass_top_rounded;
        badgeLabel = isVerifying
            ? 'Checking payment status...'
            : 'Waiting for payment (${_formatRemainingTime()})';
        break;
      case PaymentStatus.success:
        badgeColor = AppColors.successLight;
        textColor = AppColors.success;
        badgeIcon = Icons.check_circle_rounded;
        badgeLabel = 'Payment Verified Successfully!';
        break;
      case PaymentStatus.failed:
        badgeColor = AppColors.errorLight;
        textColor = AppColors.error;
        badgeIcon = Icons.cancel_rounded;
        badgeLabel = 'Payment Failed';
        break;
      case PaymentStatus.expired:
        badgeColor = AppColors.surfaceMuted;
        textColor = AppColors.textTertiary;
        badgeIcon = Icons.timer_off_outlined;
        badgeLabel = 'QR Code Expired';
        break;
      case PaymentStatus.unknown:
        badgeColor = AppColors.surfaceMuted;
        textColor = AppColors.textSecondary;
        badgeIcon = Icons.help_outline_rounded;
        badgeLabel = 'Unverified Status';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVerifying && status == PaymentStatus.pending)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
              ),
            )
          else
            Icon(badgeIcon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            badgeLabel,
            style: AppTypography.labelLarge.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(
    PaymentStatus status,
    dynamic verificationState,
  ) {
    String message;
    Color textColor = AppColors.textSecondary;

    switch (status) {
      case PaymentStatus.pending:
        message = 'Waiting for payment confirmation... Polling every 3 seconds.';
        break;
      case PaymentStatus.success:
        message = 'Payment confirmed! Proceeding to booking confirmation...';
        textColor = AppColors.success;
        break;
      case PaymentStatus.failed:
        final serverMsg = verificationState.data?.statusString ??
            verificationState.data?.message;
        message = (serverMsg != null && serverMsg.toString().isNotEmpty)
            ? 'Transaction Failed: $serverMsg'
            : 'Payment was declined or failed by bank/gateway.';
        textColor = AppColors.error;
        break;
      case PaymentStatus.expired:
        message =
            'QR code session has expired. No funds were debited. Please return to checkout.';
        textColor = AppColors.textTertiary;
        break;
      case PaymentStatus.unknown:
        message = 'Transaction status could not be verified by the backend.';
        textColor = AppColors.warning;
        break;
    }

    return Text(
      message,
      style: AppTypography.bodySmall.copyWith(
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildQrCard(String? qrData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowMedium,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: QrCodeView(
              qrData: qrData,
              size: 220,
              onRetry: () {
                final txnId = widget.paymentData.txnId;
                if (txnId != null) {
                  context.read<PaymentProvider>().verifyPaymentStatus(
                    txnId: txnId,
                    paymentId: widget.paymentData.paymentId,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'End-to-End Encrypted UPI Payment',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionIdTile(String txnId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaction Reference ID',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  txnId,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            tooltip: 'Copy Reference ID',
            onPressed: () => _copyToClipboard(txnId, 'Transaction ID'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Instructions',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildInstructionStep(
            step: '1',
            text: 'Open Google Pay, PhonePe, Paytm, BHIM, or any UPI app.',
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(
            step: '2',
            text: 'Scan the QR code displayed above.',
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(
            step: '3',
            text: 'Verify the amount and complete the payment with your UPI PIN.',
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(
            step: '4',
            text:
                'Return to this screen. We automatically check payment status every 3 seconds.',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep({required String step, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReconciliationCard(String txnId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment Verified — Finalizing Booking',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _bookingErrorMessage ??
                'Your payment is confirmed. Please tap below to complete appointment scheduling without paying again.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Retry Finalizing Booking',
            isLoading: _isFinalizingBooking,
            onPressed: _finalizeBooking,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PaymentStatus status, bool isVerifying) {
    if (status == PaymentStatus.success) {
      return AppButton(
        text: _isFinalizingBooking
            ? 'Confirming Appointment...'
            : 'Proceed to Confirmation',
        isLoading: _isFinalizingBooking,
        onPressed: _isFinalizingBooking ? null : _finalizeBooking,
      );
    }

    if (status == PaymentStatus.failed || status == PaymentStatus.expired) {
      return Column(
        children: [
          AppButton(
            text: 'Return to Checkout',
            onPressed: () {
              context.read<PaymentProvider>().stopPaymentPolling();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    // Pending state actions
    return Column(
      children: [
        AppButton(
          text: isVerifying
              ? 'Verifying Payment...'
              : "I've Paid — Check Status",
          isLoading: isVerifying,
          onPressed: isVerifying
              ? null
              : () {
                  final txnId = widget.paymentData.txnId;
                  if (txnId != null) {
                    context.read<PaymentProvider>().verifyPaymentStatus(
                      txnId: txnId,
                      paymentId: widget.paymentData.paymentId,
                    );
                  }
                },
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            final shouldExit = await _handleOnBackPressed();
            if (shouldExit && mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            'Cancel & Return to Payment Options',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
