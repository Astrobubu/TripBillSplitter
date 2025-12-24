class SettlementInfo {
  final String personName;
  final String personId;
  final double amount;
  final bool isAnonymous;

  SettlementInfo({
    required this.personName,
    required this.personId,
    required this.amount,
    this.isAnonymous = false,
  });
}
