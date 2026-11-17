import 'package:flutter_test/flutter_test.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_model.dart';
import 'package:prop_crm/features/payment/data/models/create_payment_request_model.dart';
import 'package:prop_crm/features/payment/data/models/payment_status_response_model.dart';

void main() {
  group('CreatePayment Model Tests', () {
    test('parses standard wrapped response successfully', () {
      final json = {
        'success': true,
        'message': 'Order created',
        'data': {
          'txnId': 'TXN_123456',
          'qrCodeLink': 'https://api.jigropay.com/qr/123456.png',
          'amount': 450,
          'transDate': '2026-11-17',
          'paymentId': 'PAY_987',
          'paymentCode': 'JIGRO_CODE',
        },
      };

      final payment = CreatePayment.fromJson(json);

      expect(payment.success, true);
      expect(payment.message, 'Order created');
      expect(payment.data, isNotNull);
      expect(payment.data!.txnId, 'TXN_123456');
      expect(
        payment.data!.qrCodeLink,
        'https://api.jigropay.com/qr/123456.png',
      );
      expect(payment.data!.amount, 450);
      expect(payment.data!.paymentId, 'PAY_987');
    });

    test('parses direct innerData dictionary without outer wrapper', () {
      final json = {
        'txnId': 'TXN_DIRECT',
        'qrCodeLink': 'upi://pay?pa=salon@upi&pn=Salon&am=300',
        'amount': 300,
        'paymentId': 'PAY_DIRECT',
      };

      final payment = CreatePayment.fromJson(json);

      expect(payment.data, isNotNull);
      expect(payment.data!.txnId, 'TXN_DIRECT');
      expect(
        payment.data!.qrCodeLink,
        'upi://pay?pa=salon@upi&pn=Salon&am=300',
      );
      expect(payment.data!.amount, 300);
    });

    test('safely parses amount when provided as string or double', () {
      final json = {
        'txnId': 'TXN_FLOAT',
        'qrCodeLink': 'https://example.com/qr',
        'amount': '550',
      };

      final payment = CreatePayment.fromJson(json);
      expect(payment.data!.amount, 550);
    });

    test('handles aliases like transactionId and qrCode', () {
      final json = {
        'transactionId': 'TXN_ALIAS',
        'qrCode': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==',
        'orderId': 'ORDER_ALIAS',
      };

      final payment = CreatePayment.fromJson(json);
      expect(payment.data!.txnId, 'TXN_ALIAS');
      expect(
        payment.data!.qrCodeLink,
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==',
      );
      expect(payment.data!.paymentId, 'ORDER_ALIAS');
    });
  });

  group('PaymentVerificationResponse Model Tests', () {
    test('parses exact Jigropay check-status response and evaluates statusString over top-level success', () {
      final json = {
        "success": true,
        "isSuccess": true,
        "message": "Success",
        "data": {
          "merchantName": "Aman Sharma",
          "mobileNo": "9057899440",
          "emailNo": "aman.sharma@example.com",
          "txnId": "JGP_1794896487892_3479",
          "orderID": "GPIS261117111",
          "amount": 100,
          "chargeAmount": 4.1,
          "gstAmount": 0.9,
          "status": 3,
          "statusString": "Failed",
          "dateOfCreation": "2026-11-17T11:52:22.183",
          "refundId": "",
        },
      };

      final response = PaymentVerificationResponse.fromJson(json);

      // Top-level success is true, but statusString is "Failed", so payment MUST NOT be treated as successful!
      expect(response.status, PaymentStatus.failed);
      expect(response.status.isSuccess, false);
      expect(response.status.isFailed, true);
      expect(response.status.isTerminal, true);
      expect(response.txnId, "JGP_1794896487892_3479");
      expect(response.orderId, "GPIS261117111");
      expect(response.amount, 100.0);
      expect(response.chargeAmount, 4.1);
      expect(response.gstAmount, 0.9);
      expect(response.merchantName, "Aman Sharma");
    });

    test('evaluates statusString == "Success" as PaymentStatus.success', () {
      final json = {
        "success": true,
        "isSuccess": true,
        "message": "Success",
        "data": {
          "txnId": "JGP_SUCCESS_1",
          "orderID": "ORDER_1",
          "status": 1,
          "statusString": "Success",
        },
      };

      final response = PaymentVerificationResponse.fromJson(json);

      expect(response.status, PaymentStatus.success);
      expect(response.status.isSuccess, true);
      expect(response.status.isTerminal, true);
    });

    test('evaluates statusString == "Pending" as PaymentStatus.pending', () {
      final json = {
        "success": true,
        "isSuccess": true,
        "message": "Success",
        "data": {
          "txnId": "JGP_PENDING_1",
          "orderID": "ORDER_2",
          "status": 2,
          "statusString": "Pending",
        },
      };

      final response = PaymentVerificationResponse.fromJson(json);

      expect(response.status, PaymentStatus.pending);
      expect(response.status.isSuccess, false);
      expect(response.status.isTerminal, false);
    });

    test('treats unknown status string as unverified and never as success', () {
      final json = {
        "success": true,
        "isSuccess": true,
        "message": "Success",
        "data": {
          "txnId": "JGP_UNKNOWN_1",
          "statusString": "UnrecognizedStatus",
        },
      };

      final response = PaymentVerificationResponse.fromJson(json);

      expect(response.status, PaymentStatus.unknown);
      expect(response.status.isSuccess, false);
      expect(response.status.isTerminal, false);
    });

    test('handles different success aliases like "completed" and "paid"', () {
      expect(PaymentStatus.fromString('paid'), PaymentStatus.success);
      expect(PaymentStatus.fromString('completed'), PaymentStatus.success);
      expect(PaymentStatus.fromString('successful'), PaymentStatus.success);
    });

    test('handles pending and in_progress statuses', () {
      expect(PaymentStatus.fromString('pending'), PaymentStatus.pending);
      expect(PaymentStatus.fromString('initiated'), PaymentStatus.pending);
      expect(PaymentStatus.fromString('processing'), PaymentStatus.pending);
      expect(PaymentStatus.pending.isTerminal, false);
      expect(PaymentStatus.pending.isPending, true);
    });

    test('handles failed and declined statuses', () {
      expect(PaymentStatus.fromString('failed'), PaymentStatus.failed);
      expect(PaymentStatus.fromString('declined'), PaymentStatus.failed);
      expect(PaymentStatus.fromString('rejected'), PaymentStatus.failed);
      expect(PaymentStatus.failed.isTerminal, true);
      expect(PaymentStatus.failed.isFailed, true);
    });

    test('handles expired status', () {
      expect(PaymentStatus.fromString('expired'), PaymentStatus.expired);
      expect(PaymentStatus.fromString('timeout'), PaymentStatus.expired);
      expect(PaymentStatus.expired.isTerminal, true);
      expect(PaymentStatus.expired.isExpired, true);
    });
  });

  group('CreatePaymentRequest Model Tests', () {
    test('serializes correct payload for payment order API', () {
      final request = CreatePaymentRequest(
        amount: 850.50,
        name: 'Jane Doe',
        mobileNo: '9876543210',
        emailAddress: 'jane@example.com',
        remark: 'Booking for Haircut',
      );

      final json = request.toJson();

      expect(json['amount'], 850.50);
      expect(json['name'], 'Jane Doe');
      expect(json['mobileNo'], '9876543210');
      expect(json['emailAddress'], 'jane@example.com');
      expect(json['remark'], 'Booking for Haircut');
    });
  });
}
