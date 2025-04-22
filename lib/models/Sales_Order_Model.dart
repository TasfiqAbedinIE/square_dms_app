class SalesOrder {
  final int id;
  final String buyerName;
  final int salesDocument;
  final String style;

  SalesOrder({
    required this.id,
    required this.buyerName,
    required this.salesDocument,
    required this.style,
  });

  factory SalesOrder.fromMap(Map<String, dynamic> map) {
    return SalesOrder(
      id: map['id'],
      buyerName: map['buyerName'],
      salesDocument: map['salesDocument'],
      style: map['style'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyerName': buyerName,
      'salesDocument': salesDocument,
      'style': style,
    };
  }
}
