class CreatePayment {
  bool? success;
  String? message;
  Data? data;

  CreatePayment({this.success, this.message, this.data});

  CreatePayment.fromJson(Map<String, dynamic> json) {
    success = json['success'] as bool? ?? true;
    message = json['message'] as String?;
    if (json['data'] != null && json['data'] is Map) {
      data = Data.fromJson(Map<String, dynamic>.from(json['data'] as Map));
    } else if (json['txnId'] != null ||
        json['qrCodeLink'] != null ||
        json['transactionId'] != null ||
        json['paymentId'] != null) {
      data = Data.fromJson(json);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = <String, dynamic>{};
    map['success'] = success;
    map['message'] = message;
    if (data != null) {
      map['data'] = data!.toJson();
    }
    return map;
  }
}

class Data {
  String? txnId;
  String? qrCodeLink;
  int? amount;
  String? transDate;
  String? paymentId;
  String? paymentCode;

  Data({
    this.txnId,
    this.qrCodeLink,
    this.amount,
    this.transDate,
    this.paymentId,
    this.paymentCode,
  });

  Data.fromJson(Map<String, dynamic> json) {
    txnId = (json['txnId'] ?? json['transactionId'])?.toString();
    qrCodeLink =
        (json['qrCodeLink'] ?? json['qrCode'] ?? json['qr'])?.toString();
    final rawAmount = json['amount'];
    if (rawAmount is num) {
      amount = rawAmount.toInt();
    } else if (rawAmount is String) {
      amount = int.tryParse(rawAmount) ?? double.tryParse(rawAmount)?.toInt();
    }
    transDate = (json['transDate'] ?? json['transactionDate'])?.toString();
    paymentId = (json['paymentId'] ?? json['orderId'])?.toString();
    paymentCode = json['paymentCode']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = <String, dynamic>{};
    map['txnId'] = txnId;
    map['qrCodeLink'] = qrCodeLink;
    map['amount'] = amount;
    map['transDate'] = transDate;
    map['paymentId'] = paymentId;
    map['paymentCode'] = paymentCode;
    return map;
  }
}
