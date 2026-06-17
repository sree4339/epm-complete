using { com.epm as db } from '../db/schema';
using { com.epm as views } from '../db/views';

service AnalyticsService @(path:'/analytics') {

  action GenerateReport(
    reportType : String(20),
    startDate  : Date,
    endDate    : Date
  ) returns {
    reportId : UUID;
    status   : String(20);
    message  : String(200);
  };

  action PingHealth() returns {
    status    : String(10);
    timestamp : Timestamp;
  };

  @readonly entity ProductCatalog as projection on views.ProductCatalog;
  
}