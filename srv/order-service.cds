using { com.epm as db } from '../db/schema';

service OrderService @(path: '/orders') {

  entity Orders as projection on db.SalesOrders {
    *,
    items
  } actions {
    action confirm() returns { status: String; message: String; };
    action cancel(reason: String(500)) returns { status: String; message: String; refund: Decimal(12,2); };
    action ship(trackingNumber: String(50), carrier: String(50)) returns { status: String; message: String; };
    action deliver() returns { status: String; message: String; };

    function getTotal() returns { net: Decimal(12,2); tax: Decimal(12,2); gross: Decimal(12,2); };
  };

  entity OrderItems as projection on db.SalesOrderItems;
}