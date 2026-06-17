using { com.epm as db } from '../db/schema';

service PurchasingService @(path: '/purchasing') {

  entity PurchaseOrders as projection on db.PurchaseOrders
    actions {
      // Workflow actions
      action submit() returns { status: String; message: String; };
      action approve(comment: String(500)) returns { status: String; message: String; approvedAt: DateTime; };
      action reject(reason: String(500)) returns { status: String; message: String; };
      action receive(receivedQty: Integer, notes: String(500)) returns { status: String; message: String; };

      // Read-only functions
      function getSummary() returns {
        poNumber: String;
        supplier: String;
        itemCount: Integer;
        totalAmount: Decimal;
        status: String;
        daysOpen: Integer;
      };
    };

  entity PurchaseOrderItems as projection on db.PurchaseOrderItems;
  @readonly entity Suppliers as projection on db.Suppliers;
  @readonly entity Products as projection on db.Products;

  // Unbound function: Dashboard stats
  function getPurchasingDashboard() returns {
    totalPOs: Integer;
    draftCount: Integer;
    pendingApproval: Integer;
    approvedCount: Integer;
    totalSpend: Decimal;
  };

  // Events
  event POSubmitted {
    poId: UUID;
    poNumber: String;
    supplierName: String;
    totalAmount: Decimal;
    submittedBy: String;
  }

  event POApproved {
    poId: UUID;
    poNumber: String;
    approvedBy: String;
    comment: String;
  }

  event POrejected {
    poId: UUID;
    poNumber: String;
    rejectedBy: String;
    reason: String;
  }
}
annotate PurchasingService.PurchaseOrders with @odata.draft.enabled;