using { com.epm as epm } from '../db/schema';

service AdminService {
  entity Suppliers as projection on epm.Suppliers;
  entity Categories as projection on epm.Categories;
  entity Products as projection on epm.Products;
  entity Customers as projection on epm.Customers;
  entity SalesOrders as projection on epm.SalesOrders;
  entity SalesOrderItems as projection on epm.SalesOrderItems;
  entity PurchaseOrders as projection on epm.PurchaseOrders;
  entity PurchaseOrderItems as projection on epm.PurchaseOrderItems;
}