import 'deal_model.dart';
import 'reservation_model.dart';

class CartItemModel {
  final DealModel deal;
  int quantity;

  /// Stock hold for this line item. The starter app does not reserve stock —
  /// see the "Reservations" feature task.
  ReservationModel? reservation;

  /// True while a reservation request is in flight for this item.
  bool isReserving;

  CartItemModel({
    required this.deal,
    this.quantity = 1,
    this.reservation,
    this.isReserving = false,
  });

  num get lineTotal => deal.price * quantity;

  bool get isReservationExpired =>
      reservation != null && reservation!.isExpired;
}
