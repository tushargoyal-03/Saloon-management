enum PaymentMethodType {
  upi,
  card,
  cod;

  static PaymentMethodType fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'upi':
      case 'online':
      case 'jigropay':
        return PaymentMethodType.upi;
      case 'card':
        return PaymentMethodType.card;
      case 'cod':
      case 'cash':
      case 'cash_on_delivery':
      case 'salon':
      case 'pay_at_salon':
      case 'payatsalon':
      case 'pay at salon':
      case 'offline':
        return PaymentMethodType.cod;
      default:
        return PaymentMethodType.upi;
    }
  }

  bool get isPayAtSalon => this == PaymentMethodType.cod;
  bool get isOnline => this != PaymentMethodType.cod;

  String toFormattedString() {
    switch (this) {
      case PaymentMethodType.upi:
        return 'upi';
      case PaymentMethodType.card:
        return 'card';
      case PaymentMethodType.cod:
        return 'cod';
    }
  }
}

class PaymentMethodModel {
  final String id;
  final String? code;
  final String title;
  final String subtitle;
  final PaymentMethodType type;
  final bool isAvailable;
  final String? iconName;
  final String? icon;

  const PaymentMethodModel({
    required this.id,
    this.code,
    required this.title,
    required this.subtitle,
    required this.type,
    this.isAvailable = true,
    this.iconName,
    this.icon,
  });

  PaymentMethodModel copyWith({
    String? id,
    String? code,
    String? title,
    String? subtitle,
    PaymentMethodType? type,
    bool? isAvailable,
    String? iconName,
    String? icon,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      isAvailable: isAvailable ?? this.isAvailable,
      iconName: iconName ?? this.iconName,
      icon: icon ?? this.icon,
    );
  }

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? json['method'] ?? json['code'] ?? 'upi').toString();
    final type = PaymentMethodType.fromString(typeStr);

    final resolvedCode = (json['code'] ?? json['id'] ?? json['_id'])?.toString();

    final defaultTitle = type == PaymentMethodType.cod
        ? 'Pay at Salon (Cash / Card at Desk)'
        : (type == PaymentMethodType.card
              ? 'Credit / Debit Card'
              : 'Instant UPI / QR Code (Jigropay)');

    final defaultSubtitle = type == PaymentMethodType.cod
        ? 'Pay at the salon counter when you arrive for your appointment'
        : 'Pay instantly using Google Pay, PhonePe, Paytm, or any UPI App / NetBanking';

    final title = (json['name'] ?? json['title'] ?? defaultTitle).toString();
    final subtitle =
        (json['description'] ?? json['subtitle'] ?? defaultSubtitle).toString();
    final iconVal = (json['icon'] ?? json['iconName'])?.toString();

    final id = (json['code'] ??
            json['id'] ??
            json['_id'] ??
            (type == PaymentMethodType.cod ? 'cash' : 'jigropay'))
        .toString();

    final isAvailable = json['active'] as bool? ??
        json['isAvailable'] as bool? ??
        json['available'] as bool? ??
        true;

    return PaymentMethodModel(
      id: id,
      code: resolvedCode ?? id,
      title: title,
      subtitle: subtitle,
      type: type,
      isAvailable: isAvailable,
      iconName: iconVal,
      icon: iconVal,
    );
  }

  factory PaymentMethodModel.fromDynamic(dynamic raw) {
    if (raw is PaymentMethodModel) {
      return raw;
    }
    if (raw is Map) {
      return PaymentMethodModel.fromJson(Map<String, dynamic>.from(raw));
    }
    final str = raw?.toString().trim() ?? '';
    final type = PaymentMethodType.fromString(str);
    final title = type == PaymentMethodType.cod
        ? 'Pay at Salon (Cash / Card at Desk)'
        : (type == PaymentMethodType.card
              ? 'Credit / Debit Card'
              : (str.toLowerCase().contains('jigropay') ||
                      str.toLowerCase().contains('upi')
                  ? 'Instant UPI / QR Code (Jigropay)'
                  : 'Online Payment'));
    final subtitle = type == PaymentMethodType.cod
        ? 'Pay at the salon counter when you arrive for your appointment'
        : 'Pay instantly using Google Pay, PhonePe, Paytm, or any UPI App / NetBanking';

    final code = type == PaymentMethodType.cod ? 'cash' : 'jigropay';

    return PaymentMethodModel(
      id: code,
      code: code,
      title: title,
      subtitle: subtitle,
      type: type,
      isAvailable: true,
      icon: type == PaymentMethodType.cod ? '💵' : '⚡',
      iconName: type == PaymentMethodType.cod ? '💵' : '⚡',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (code != null) 'code': code,
      'title': title,
      'name': title,
      'subtitle': subtitle,
      'description': subtitle,
      'type': type.toFormattedString(),
      'isAvailable': isAvailable,
      'active': isAvailable,
      if (iconName != null) 'iconName': iconName,
      if (icon != null) 'icon': icon,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethodModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          title == other.title &&
          subtitle == other.subtitle &&
          type == other.type &&
          isAvailable == other.isAvailable &&
          iconName == other.iconName &&
          icon == other.icon;

  @override
  int get hashCode =>
      id.hashCode ^
      code.hashCode ^
      title.hashCode ^
      subtitle.hashCode ^
      type.hashCode ^
      isAvailable.hashCode ^
      iconName.hashCode ^
      icon.hashCode;
}
