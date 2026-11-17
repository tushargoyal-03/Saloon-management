import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop_crm/features/payment/presentation/widgets/qr_code_view.dart';

void main() {
  group('QrCodeView Widget Tests', () {
    testWidgets('displays error state when qrData is null or empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QrCodeView(qrData: null)),
        ),
      );

      expect(find.text('No QR code data provided.'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('renders network image widget when URL is http/https', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrCodeView(qrData: 'https://api.jigropay.com/qr/sample.png'),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders CustomPaint matrix when payload is raw UPI string', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrCodeView(
              qrData: 'upi://pay?pa=salon@upi&pn=Salon&am=500&tr=TXN123',
            ),
          ),
        ),
      );

      final qrPaintFinder = find.descendant(
        of: find.byType(QrCodeView),
        matching: find.byType(CustomPaint),
      );
      expect(qrPaintFinder, findsOneWidget);
    });

    testWidgets('handles Data URI Base64 image payload', (tester) async {
      // 1x1 transparent PNG Base64
      const base64Png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QrCodeView(qrData: base64Png)),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });
}

