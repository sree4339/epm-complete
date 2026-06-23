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

// =====================================================================
//  SECURITY  (kept in separate annotate blocks — required by your
//  @sap/cds ^9 compiler; inline @requires/@restrict break the parser)
// =====================================================================

// Service-level: any logged-in user must be authenticated to reach it
annotate PurchasingService with @(requires: 'authenticated-user');

// Entity-level: scope-based CRUD + action grants
//   Read     -> Viewer, PurchaseManager, Administrator
//   Create   -> PurchaseManager, Administrator (CREATE + UPDATE)
//   submit   -> PurchaseManager, Administrator
//   approve  -> Approve scope (PurchaseManager, Administrator)
//   reject   -> Approve scope
//   receive  -> Approve scope
//   Delete   -> Administrator only
annotate PurchasingService.PurchaseOrders with @(restrict: [
  { grant: 'READ',            to: 'Read' },
  { grant: ['CREATE','UPDATE'], to: 'Create' },
  { grant: 'submit',          to: 'Create' },
  { grant: 'approve',         to: 'Approve' },
  { grant: 'reject',          to: 'Approve' },
  { grant: 'receive',         to: 'Approve' },
  { grant: 'DELETE',          to: 'Delete' }
]);

annotate PurchasingService.PurchaseOrderItems with @(restrict: [
  { grant: 'READ',              to: 'Read' },
  { grant: ['CREATE','UPDATE','DELETE'], to: 'Create' }
]);

// Suppliers and Products are @readonly already; restrict reads to anyone
// who can read PO data.
annotate PurchasingService.Suppliers with @(restrict: [
  { grant: 'READ', to: 'Read' }
]);

annotate PurchasingService.Products with @(restrict: [
  { grant: 'READ', to: 'Read' }
]);
