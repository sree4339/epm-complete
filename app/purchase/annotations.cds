using { PurchasingService } from '../../srv/purchasing-service';

// ---- Text arrangement (show names not GUIDs) ----
annotate PurchasingService.PurchaseOrders with {
  supplier @Common: { Text: supplier.name, TextArrangement: #TextOnly };
}
annotate PurchasingService.PurchaseOrderItems with {
  product  @Common: { Text: product.name, TextArrangement: #TextOnly };
}

// ---- Value Helps ----
annotate PurchasingService.PurchaseOrders with {
  supplier @Common.ValueList: {
    CollectionPath: 'Suppliers',
    Parameters: [
      { $Type: 'Common.ValueListParameterInOut',       LocalDataProperty: supplier_ID, ValueListProperty: 'ID' },
      { $Type: 'Common.ValueListParameterDisplayOnly',                                 ValueListProperty: 'name' },
      { $Type: 'Common.ValueListParameterDisplayOnly',                                 ValueListProperty: 'city' }
    ]
  };
}
annotate PurchasingService.PurchaseOrderItems with {
  product @Common.ValueList: {
    CollectionPath: 'Products',
    Parameters: [
      { $Type: 'Common.ValueListParameterInOut',       LocalDataProperty: product_ID, ValueListProperty: 'ID' },
      { $Type: 'Common.ValueListParameterDisplayOnly',                                ValueListProperty: 'name' },
      { $Type: 'Common.ValueListParameterOut',         LocalDataProperty: unitPrice,  ValueListProperty: 'price' }
    ]
  };
}

// ---- Labels + Field Control (lock fields after submit) ----
annotate PurchasingService.PurchaseOrders with {
  poNumber     @title: 'PO Number'      @Common.FieldControl: fieldControl;
  supplier     @title: 'Supplier'       @Common.FieldControl: fieldControl;
  priority     @title: 'Priority'       @Common.FieldControl: fieldControl;
  orderDate    @title: 'Order Date'     @Common.FieldControl: fieldControl;
  expectedDate @title: 'Expected Date'  @Common.FieldControl: fieldControl;
  notes        @title: 'Notes'          @Common.FieldControl: fieldControl  @UI.MultiLineText;
  status       @title: 'Status'         @readonly;
  totalAmount  @title: 'Total Amount'   @readonly  @Measures.ISOCurrency: currency_code;
  taxAmount    @title: 'Tax Amount'     @readonly  @Measures.ISOCurrency: currency_code;
  netAmount    @title: 'Net Amount'     @readonly  @Measures.ISOCurrency: currency_code;
}
annotate PurchasingService.PurchaseOrderItems with {
  product    @title: 'Product';
  quantity   @title: 'Quantity';
  unitPrice  @title: 'Unit Price';
  totalPrice @title: 'Line Total' @readonly;
}

// ---- List Report + Object Page ----
annotate PurchasingService.PurchaseOrders with @UI: {


  SelectionFields: [ poNumber, status, priority, supplier_ID, orderDate ],

  LineItem: [
    { Value: poNumber },
    { Value: supplier_ID, Label: 'Supplier' },
    { Value: priority },
    { Value: orderDate },
    { Value: totalAmount },
    { Value: status, Criticality: criticality },
    { $Type: 'UI.DataFieldForAction', Action: 'PurchasingService.submit',  Label: 'Submit' },
    { $Type: 'UI.DataFieldForAction', Action: 'PurchasingService.approve', Label: 'Approve' },
    { $Type: 'UI.DataFieldForAction', Action: 'PurchasingService.reject',  Label: 'Reject' }
  ],

  HeaderInfo: {
    TypeName: 'Purchase Order',
    TypeNamePlural: 'Purchase Orders',
    Title:       { Value: poNumber },
    Description: { Value: supplier_ID }
  },

  HeaderFacets: [
    { $Type: 'UI.ReferenceFacet', Target: '@UI.FieldGroup#KPIs', Label: 'Overview' }
  ],
  FieldGroup#KPIs: { Data: [
    { Value: totalAmount },
    { Value: status, Criticality: criticality },
    { Value: priority }
  ]},

  Identification: [
    { $Type: 'UI.DataFieldForAction', Action: 'PurchasingService.submit',  Label: 'Submit',  ![@UI.Hidden]: hideSubmit },
    { $Type: 'UI.DataFieldForAction', Action: 'PurchasingService.approve', Label: 'Approve', ![@UI.Hidden]: hideApprove },
    { $Type: 'UI.DataFieldForAction', Action: 'PurchasingService.reject',  Label: 'Reject',  ![@UI.Hidden]: hideReject },
    { $Type: 'UI.DataFieldForAction', Action: 'PurchasingService.receive', Label: 'Receive', ![@UI.Hidden]: hideReceive }
  ],

  Facets: [
    { $Type: 'UI.ReferenceFacet', Target: '@UI.FieldGroup#General', Label: 'General Information' },
    { $Type: 'UI.ReferenceFacet', Target: 'items/@UI.LineItem',     Label: 'Purchase Order Items' }
  ],

  FieldGroup#General: { Data: [
    { Value: poNumber },
    { Value: supplier_ID, Label: 'Supplier' },
    { Value: priority },
    { Value: orderDate },
    { Value: expectedDate },
    { Value: totalAmount },
    { Value: taxAmount },
    { Value: netAmount },
    { Value: status, Criticality: criticality },
    { Value: notes }
  ]}
};

annotate PurchasingService.PurchaseOrderItems with @UI: {
  LineItem: [
    { Value: product_ID, Label: 'Product' },
    { Value: quantity },
    { Value: unitPrice },
    { Value: totalPrice }
  ],

  HeaderInfo: {
    TypeName: 'Line Item',
    TypeNamePlural: 'Line Items',
    Title:       { Value: product_ID },
    Description: { Value: totalPrice }
  },

  Facets: [
    { $Type: 'UI.ReferenceFacet', Target: '@UI.FieldGroup#ItemDetail', Label: 'Item Details' }
  ],

  FieldGroup#ItemDetail: {
    Data: [
      { Value: product_ID, Label: 'Product' },
      { Value: quantity },
      { Value: unitPrice },
      { Value: totalPrice }
    ]
  }
};

// ---- Side Effects ----
annotate PurchasingService.PurchaseOrderItems with @(
  Common.SideEffects#ItemTotal: {
    SourceProperties: [ quantity, unitPrice, product_ID ],
    TargetProperties: [ 'totalPrice' ]
  }
);
annotate PurchasingService.PurchaseOrders with @(
  Common.SideEffects#TotalRefresh: {
    SourceEntities:   [ items ],
    TargetProperties: [ 'totalAmount', 'taxAmount', 'netAmount' ]
  }
);

annotate PurchasingService.PurchaseOrders with @(
  UI.SelectionPresentationVariant #Default: {
    PresentationVariant: { Visualizations: ['@UI.LineItem'] },
    SelectionVariant: { SelectOptions: [] }
  }
);

// Quick filter views (tabs)
annotate PurchasingService.PurchaseOrders with @(
  UI.SelectionVariant #Drafts: {
    Text: 'Drafts',
    SelectOptions: [{ PropertyName: status, Ranges: [{ Sign: #I, Option: #EQ, Low: 'Draft' }] }]
  },
  UI.SelectionVariant #Submitted: {
    Text: 'Pending Approval',
    SelectOptions: [{ PropertyName: status, Ranges: [{ Sign: #I, Option: #EQ, Low: 'Submitted' }] }]
  },
  UI.SelectionVariant #Approved: {
    Text: 'Approved',
    SelectOptions: [{ PropertyName: status, Ranges: [{ Sign: #I, Option: #EQ, Low: 'Approved' }] }]
  }
);

annotate PurchasingService.PurchaseOrders with @(
  Aggregation.ApplySupported: {
    Transformations: ['aggregate', 'groupby'],
    GroupableProperties: [ status, priority, supplier_ID ],
    AggregatableProperties: [ { Property: totalAmount }, { Property: netAmount } ]
  }
);

annotate PurchasingService.PurchaseOrders {
  totalAmount @Aggregation.default: #SUM;
  netAmount   @Aggregation.default: #SUM;
};