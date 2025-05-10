class ShipmentRecord {
  final DateTime date;
  final String buyer;
  final String so;
  final String style;
  final int orderQty;
  final int shippedQty;
  final int shortQty;
  final int excess;
  final String modeOfShipment;
  final String sfl;
  final String buyerName;

  ShipmentRecord({
    required this.date,
    required this.buyer,
    required this.so,
    required this.style,
    required this.orderQty,
    required this.shippedQty,
    required this.shortQty,
    required this.excess,
    required this.modeOfShipment,
    required this.sfl,
    required this.buyerName,
  });

  factory ShipmentRecord.fromJson(Map<String, dynamic> json) {
    return ShipmentRecord(
      date: DateTime.parse(json['Date']),
      buyer: json['Buyer'],
      so: json['SO'],
      style: json['Style'],
      orderQty: json['OrderQty'],
      shippedQty: json['ShippedQty'],
      shortQty: json['Short'],
      excess: json['Excess'],
      modeOfShipment: json['ModeOfShipment'],
      sfl: json['SFL'],
      buyerName: json['BuyerName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Date': date.toIso8601String(),
      'Buyer': buyer,
      'SO': so,
      'Style': style,
      'OrderQty': orderQty,
      'ShippedQty': shippedQty,
      'Short': shortQty,
      'Excess': excess,
      'ModeOfShipment': modeOfShipment,
      'SFL': sfl,
      'BuyerName': buyerName,
    };
  }
}
