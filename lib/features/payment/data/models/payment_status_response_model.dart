enum PaymentStatus {
  pending,
  success,
  failed,
  expired,
  unknown;

  static PaymentStatus fromString(String? status) {
    if (status == null || status.trim().isEmpty) return PaymentStatus.unknown;
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'success':
      case 'successful':
      case 'completed':
      case 'paid':
      case '1':
        return PaymentStatus.success;
      case 'pending':
      case 'initiated':
      case 'processing':
      case 'in_progress':
      case 'created':
      case '2':
        return PaymentStatus.pending;
      case 'failed':
      case 'failure':
      case 'declined':
      case 'rejected':
      case 'error':
      case '3':
        return PaymentStatus.failed;
      case 'expired':
      case 'timeout':
      case 'cancelled':
      case 'canceled':
      case '4':
        return PaymentStatus.expired;
      default:
        return PaymentStatus.unknown;
    }
  }

  bool get isTerminal =>
      this == PaymentStatus.success ||
      this == PaymentStatus.failed ||
      this == PaymentStatus.expired;

  bool get isSuccess => this == PaymentStatus.success;
  bool get isFailed => this == PaymentStatus.failed;
  bool get isExpired => this == PaymentStatus.expired;
  bool get isPending => this == PaymentStatus.pending;
  bool get isUnknown => this == PaymentStatus.unknown;
}

class PaymentVerificationResponse {
  final bool success;
  final bool isSuccess;
  final String message;
  final PaymentStatus status;
  final String? statusString;
  final int? statusCode;
  final String? txnId;
  final String? orderId;
  final double? amount;
  final double? chargeAmount;
  final double? gstAmount;
  final String? merchantName;
  final String? mobileNo;
  final String? emailNo;
  final String? dateOfCreation;
  final String? refundId;

  String? get paymentId => orderId;

  const PaymentVerificationResponse({
    required this.success,
    this.isSuccess = false,
    required this.message,
    required this.status,
    this.statusString,
    this.statusCode,
    this.txnId,
    String? orderId,
    String? paymentId,
    this.amount,
    this.chargeAmount,
    this.gstAmount,
    this.merchantName,
    this.mobileNo,
    this.emailNo,
    this.dateOfCreation,
    this.refundId,
  }) : orderId = orderId ?? paymentId;

  factory PaymentVerificationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final rawStatusString = (data['statusString'] ??
            data['status_string'] ??
            data['paymentStatus'])
        ?.toString();

    // Primary status indicator is data.statusString; fall back to data.status if needed
    final effectiveStatusStr = rawStatusString ?? data['status']?.toString();
    final status = PaymentStatus.fromString(effectiveStatusStr);

    final success = json['success'] as bool? ?? false;
    final isSuccess = json['isSuccess'] as bool? ?? false;
    final message = (json['message'] ?? data['message'] ?? '') as String;
    final txnId = (data['txnId'] ?? data['transactionId'] ?? json['txnId'])
        ?.toString();
    final orderId = (data['orderID'] ??
            data['orderId'] ??
            data['paymentId'] ??
            json['orderID'])
        ?.toString();

    final rawStatusCode = data['status'];
    final int? statusCode = rawStatusCode is num
        ? rawStatusCode.toInt()
        : int.tryParse(rawStatusCode?.toString() ?? '');

    final rawAmount = data['amount'] ?? json['amount'];
    final double? amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '');

    final rawCharge = data['chargeAmount'] ?? json['chargeAmount'];
    final double? chargeAmount = rawCharge is num
        ? rawCharge.toDouble()
        : double.tryParse(rawCharge?.toString() ?? '');

    final rawGst = data['gstAmount'] ?? json['gstAmount'];
    final double? gstAmount = rawGst is num
        ? rawGst.toDouble()
        : double.tryParse(rawGst?.toString() ?? '');

    return PaymentVerificationResponse(
      success: success,
      isSuccess: isSuccess,
      message: message,
      status: status,
      statusString: rawStatusString ?? status.name,
      statusCode: statusCode,
      txnId: txnId,
      orderId: orderId,
      amount: amount,
      chargeAmount: chargeAmount,
      gstAmount: gstAmount,
      merchantName: data['merchantName']?.toString(),
      mobileNo: data['mobileNo']?.toString(),
      emailNo: data['emailNo']?.toString(),
      dateOfCreation: data['dateOfCreation']?.toString(),
      refundId: data['refundId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'isSuccess': isSuccess,
    'message': message,
    'status': status.name,
    'statusString': statusString,
    'statusCode': statusCode,
    'txnId': txnId,
    'orderID': orderId,
    'amount': amount,
    'chargeAmount': chargeAmount,
    'gstAmount': gstAmount,
    'merchantName': merchantName,
    'mobileNo': mobileNo,
    'emailNo': emailNo,
    'dateOfCreation': dateOfCreation,
    'refundId': refundId,
  };
}
