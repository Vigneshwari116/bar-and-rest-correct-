
class BillEntity {
  final String billId;
  final String cCode;
  final String meterNo;
  final String name;
  final String type;
  final double rate;
  final double preRead;
  final double prevBalance;
  double? currentRead;
  double excelReadLimit;
  bool isCalculated;
  double consumption;
  double totalAmount;

  BillEntity({
    required this.billId,
    required this.cCode,
    required this.meterNo,
    required this.name,
    required this.type,
    required this.rate,
    required this.preRead,
    this.prevBalance = 0.0,
    this.currentRead,
    this.excelReadLimit = 0.0,
    this.isCalculated = false,
    this.consumption = 0.0,
    this.totalAmount = 0.0,
  });

  Map<String, dynamic> toSqlMap() => {
    'bil': billId,
    'ccode': cCode,
    'meter': meterNo,
    'name': name,
    'type': type,
    'rate': rate,
    'pre': preRead,
    'prevBal': prevBalance,
    'curr': currentRead,
    'readLimit': excelReadLimit, // Save limit to SQLite
    'isCalc': isCalculated ? 1 : 0,
    'consumption': consumption,
    'totalAmount': totalAmount,
  };

  factory BillEntity.fromSqlMap(Map<String, dynamic> map) => BillEntity(
    billId: map['bil'] ?? "",
    cCode: map['ccode'] ?? "",
    meterNo: map['meter'] ?? "",
    name: map['name'] ?? "N/A",
    type: map['type'] ?? "Unknown",
    rate: (map['rate'] ?? 0.0).toDouble(),
    preRead: (map['pre'] ?? 0.0).toDouble(),
    prevBalance: (map['prevBal'] ?? 0.0).toDouble(),
    currentRead: map['curr'] != null ? (map['curr'] as num).toDouble() : null,
    excelReadLimit: (map['readLimit'] ?? 0.0).toDouble(),
    isCalculated: map['isCalc'] == 1,
    consumption: (map['consumption'] ?? 0.0).toDouble(),
    totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
  );

  double get consumption1 => (currentRead ?? 0) > preRead ? (currentRead! - preRead) : 0;
  double get currentBillAmount => consumption * rate;
  double get totalSum => currentBillAmount + prevBalance;
}