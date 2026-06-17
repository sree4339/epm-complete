namespace com.epm;

using com.epm as epm from './schema';

entity ProductCatalog as select from epm.Products {
  ID,
  name,
  description,
  price,
  currency.code as currency,
  stock,
  minStock,
  rating,
  supplier.name as supplierName,
  category.name as categoryName,

  case
    when stock <= minStock then 'LOW STOCK'
    when stock <= minStock + 10 then 'MEDIUM STOCK'
    else 'AVAILABLE'
  end as stockStatus : String(20)
};

entity OrderReport as select from epm.SalesOrders {
  ID,
  orderNumber,
  customer.name as customerName,
  orderDate,
  totalAmount,
  taxAmount,
  netAmount,
  currency.code as currency,
  status
};

entity LowStockAlert as select from epm.Products {
  ID,
  name as productName,
  stock,
  minStock,
  supplier.name as supplierName,
  supplier.contact as supplierContact,
  supplier.email as supplierEmail,
  supplier.phone as supplierPhone
}
where stock <= minStock;