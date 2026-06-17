using { com.epm as epm } from '../db/views';

@readonly
service ReportService {
  entity ProductCatalog as projection on epm.ProductCatalog;
  entity OrderReport as projection on epm.OrderReport;
  entity LowStockAlert as projection on epm.LowStockAlert;
}