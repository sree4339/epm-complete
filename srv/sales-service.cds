using { com.epm as epm } from '../db/schema';

service SalesService {
  entity Products as projection on epm.Products {
    ID,
    name,
    description,
    currency,
    stock,
    rating,
    category
  };

  entity SalesOrderItems as projection on epm.SalesOrderItems;
   entity SalesOrders as projection on epm.SalesOrders
    actions {
      action confirm() returns { status: String; message: String; };
      action cancel(reason: String(500)) returns { status: String; message: String; };
      action ship(trackingNumber: String(50), carrier: String(50)) returns { status: String; };
    };

   entity Customers as projection on epm.Customers;
}