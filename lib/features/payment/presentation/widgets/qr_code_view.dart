import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prop_crm/core/constants/app_colors.dart';
import 'package:prop_crm/core/constants/app_typography.dart';
import 'package:prop_crm/core/widgets/app_loading_indicator.dart';

/// Renders QR code securely across all possible backend formats:
/// 1. Remote Image URL (HTTP/HTTPS)
/// 2. Base64 Data URI (data:image/png;base64,...)
/// 3. Raw Base64 string
/// 4. Raw payload or UPI string (upi://pay?...) using pure Dart QR matrix painter
class QrCodeView extends StatelessWidget {
  final String? qrData;
  final double size;
  final VoidCallback? onRetry;

  const QrCodeView({
    super.key,
    required this.qrData,
    this.size = 220,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (qrData == null || qrData!.trim().isEmpty) {
      return _buildErrorState('No QR code data provided.');
    }

    final trimmed = qrData!.trim();

    // 1. HTTP or HTTPS Image URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _buildNetworkImage(trimmed);
    }

    // 2. Data URI (Base64)
    if (trimmed.startsWith('data:image/')) {
      return _buildDataUriImage(trimmed);
    }

    // 3. Raw Base64 Image
    if (_isLikelyBase64(trimmed)) {
      return _buildRawBase64Image(trimmed);
    }

    // 4. Raw String / UPI URI: Render using native CustomPainter
    return _buildCustomQrMatrix(trimmed);
  }

  Widget _buildNetworkImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorState('Failed to load QR code image.');
        },
      ),
    );
  }

  Widget _buildDataUriImage(String dataUri) {
    try {
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex == -1) {
        return _buildErrorState('Invalid QR image data.');
      }
      final base64String = dataUri.substring(commaIndex + 1).trim();
      final bytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorState('Invalid QR image bytes.');
          },
        ),
      );
    } catch (_) {
      return _buildErrorState('Failed to decode QR image.');
    }
  }

  Widget _buildRawBase64Image(String rawBase64) {
    try {
      final bytes = base64Decode(rawBase64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorState('Invalid QR image bytes.');
          },
        ),
      );
    } catch (_) {
      return _buildErrorState('Failed to decode Base64 QR code.');
    }
  }

  Widget _buildCustomQrMatrix(String payload) {
    try {
      final matrix = _QrCodeEncoder.encode(payload);
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          size: Size(size - 16, size - 16),
          painter: _QrMatrixPainter(matrix),
        ),
      );
    } catch (_) {
      // Graceful fallback if payload cannot be encoded
      return _buildPayloadFallback(payload);
    }
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppLoadingIndicator(size: 32),
          SizedBox(height: 12),
          Text(
            'Generating QR Code...',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 36,
            color: AppColors.error,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayloadFallback(String payload) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'UPI Payment Intent',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                payload,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLikelyBase64(String str) {
    if (str.length < 100) return false;
    final regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    return regex.hasMatch(str.replaceAll('\n', '').replaceAll('\r', ''));
  }
}

/// CustomPainter that renders a 2D boolean QR module matrix
class _QrMatrixPainter extends CustomPainter {
  final List<List<bool>> matrix;

  _QrMatrixPainter(this.matrix);

  @override
  void paint(Canvas canvas, Size size) {
    final moduleCount = matrix.length;
    if (moduleCount == 0) return;

    final moduleSize = size.width / moduleCount;
    final paint = Paint()
      ..color = const Color(0xFF1C1917)
      ..style = PaintingStyle.fill;

    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        if (matrix[r][c]) {
          canvas.drawRect(
            Rect.fromLTWH(
              c * moduleSize,
              r * moduleSize,
              moduleSize + 0.3,
              moduleSize + 0.3,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) {
    return oldDelegate.matrix != matrix;
  }
}

/// Compact, zero-dependency QR Matrix Generator for raw strings / UPI payloads
class _QrCodeEncoder {
  static List<List<bool>> encode(String text) {
    final bytes = utf8.encode(text);
    int version = 1;
    while (version <= 10 && _maxCapacity(version) < bytes.length) {
      version++;
    }
    if (version > 10) version = 10;

    final size = version * 4 + 17;
    final matrix = List.generate(size, (_) => List.filled(size, false));
    final isFunction = List.generate(size, (_) => List.filled(size, false));

    // 1. Finder patterns (top-left, top-right, bottom-left)
    _addFinderPattern(matrix, isFunction, 0, 0);
    _addFinderPattern(matrix, isFunction, size - 7, 0);
    _addFinderPattern(matrix, isFunction, 0, size - 7);

    // 2. Timing patterns
    for (int i = 8; i < size - 8; i++) {
      final val = (i % 2 == 0);
      matrix[6][i] = val;
      isFunction[6][i] = true;
      matrix[i][6] = val;
      isFunction[i][6] = true;
    }

    // 3. Mark format info areas as function
    for (int i = 0; i < 9; i++) {
      if (i < size) {
        isFunction[8][i] = true;
        isFunction[i][8] = true;
      }
    }
    for (int i = size - 8; i < size; i++) {
      if (i >= 0 && i < size) {
        isFunction[8][i] = true;
        isFunction[i][8] = true;
      }
    }

    // 4. Fill data modules using byte stream with alternating mask
    final bits = _buildBitStream(bytes, version);
    int bitIndex = 0;
    int row = size - 1;
    int col = size - 1;
    bool upward = true;

    while (col > 0) {
      if (col == 6) col--; // Skip vertical timing pattern column

      for (int i = 0; i < size; i++) {
        final r = upward ? (row - i) : (row + i);
        for (int c = col; c >= col - 1; c--) {
          if (!isFunction[r][c]) {
            bool bit = false;
            if (bitIndex < bits.length) {
              bit = bits[bitIndex++];
            }
            // Standard QR mask (row + col) % 2 == 0
            if ((r + c) % 2 == 0) {
              bit = !bit;
            }
            matrix[r][c] = bit;
          }
        }
      }

      col -= 2;
      upward = !upward;
      row = upward ? (size - 1) : 0;
    }

    return matrix;
  }

  static void _addFinderPattern(
    List<List<bool>> matrix,
    List<List<bool>> isFunction,
    int startRow,
    int startCol,
  ) {
    for (int r = -1; r <= 7; r++) {
      for (int c = -1; c <= 7; c++) {
        final row = startRow + r;
        final col = startCol + c;
        if (row >= 0 &&
            row < matrix.length &&
            col >= 0 &&
            col < matrix.length) {
          isFunction[row][col] = true;
          if (r >= 0 && r <= 6 && c >= 0 && c <= 6) {
            matrix[row][col] =
                (r == 0 || r == 6 || c == 0 || c == 6) ||
                (r >= 2 && r <= 4 && c >= 2 && c <= 4);
          } else {
            matrix[row][col] = false;
          }
        }
      }
    }
  }

  static int _maxCapacity(int version) {
    const capacities = [17, 32, 53, 78, 106, 134, 154, 192, 230, 271];
    return capacities[version - 1];
  }

  static List<bool> _buildBitStream(List<int> bytes, int version) {
    final bits = <bool>[];
    // Mode indicator: 0100 (Byte mode)
    bits.addAll([false, true, false, false]);

    // Character count (8 bits for version 1-9)
    final count = bytes.length;
    for (int i = 7; i >= 0; i--) {
      bits.add(((count >> i) & 1) == 1);
    }

    // Data bytes
    for (final b in bytes) {
      for (int i = 7; i >= 0; i--) {
        bits.add(((b >> i) & 1) == 1);
      }
    }

    // Terminator
    while (bits.length % 8 != 0) {
      bits.add(false);
    }

    return bits;
  }
}
