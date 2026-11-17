class CreatePaymentRequest {
  final double amount;
  final String name;
  final String mobileNo;
  final String emailAddress;
  final String remark;

  CreatePaymentRequest({
    required this.amount,
    required this.name,
    required this.mobileNo,
    required this.emailAddress,
    required this.remark,
  });

  Map<String, dynamic> toJson() => {
    "amount": amount,
    "name": name,
    "mobileNo": mobileNo,
    "emailAddress": emailAddress,
    "remark": remark,
  };
}
