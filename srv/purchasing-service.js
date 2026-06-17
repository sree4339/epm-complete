const cds = require('@sap/cds');

module.exports = function () {
  const { PurchaseOrders, PurchaseOrderItems } = this.entities;

  const criticalityOf = (s) =>
    s === 'Approved' || s === 'Received' ? 3 :
    s === 'Submitted' ? 2 :
    s === 'Rejected'  ? 1 : 0;

  // Compute UI fields + live totals on every read (draft + active)
  this.after('READ', 'PurchaseOrders', async (data) => {
    for (const po of [].concat(data)) {
      if (!po || !po.ID) continue;
      po.criticality  = criticalityOf(po.status);
      po.fieldControl = po.status === 'Draft' ? 7 : 1;   // 7=editable, 1=read-only
      po.hideSubmit   = po.status !== 'Draft';
      po.hideApprove  = po.status !== 'Submitted';
      po.hideReject   = po.status !== 'Submitted';
      po.hideReceive  = po.status !== 'Approved';
      try {
        const src   = po.IsActiveEntity === false ? PurchaseOrderItems.drafts : PurchaseOrderItems;
        const items = await SELECT.from(src).where({ order_ID: po.ID });
        po.totalAmount = items.reduce((s, i) => s + (i.quantity || 0) * (i.unitPrice || 0), 0);
      } catch (e) { /* keep stored total */ }
    }
  });

  this.after('READ', 'PurchaseOrderItems', (data) => {
    for (const it of [].concat(data)) {
      if (it && it.quantity != null && it.unitPrice != null)
        it.totalPrice = it.quantity * it.unitPrice;
    }
  });

  // Validate required fields + persist totals on Save (draft activation)
  this.before('SAVE', 'PurchaseOrders', (req) => {
    const { poNumber, supplier_ID, items = [] } = req.data;
    if (!poNumber)     req.error({ target: 'poNumber',    message: 'PO Number is required' });
    if (!supplier_ID)  req.error({ target: 'supplier_ID', message: 'Supplier is required' });
    if (!items.length) req.error('At least one line item is required');
    let total = 0;
    for (const it of items) { it.totalPrice = (it.quantity || 0) * (it.unitPrice || 0); total += it.totalPrice; }
    const tax = +(total * 0.18).toFixed(2);
    req.data.totalAmount = total;
    req.data.taxAmount   = tax;
    req.data.netAmount   = total + tax;
  });

  this.on('submit', 'PurchaseOrders', async (req) => {
    const { ID } = req.params[0];

    const po = await SELECT.one.from('com.epm.PurchaseOrders').where({ ID });
    if (!po) req.reject(404, 'Purchase Order not found');

    if (po.status !== 'Draft') {
      req.reject(400, `Only Draft POs can be submitted. Current status: ${po.status}`);
    }

    const items = await SELECT.from('com.epm.PurchaseOrderItems')
      .where({ order_ID: ID });

    if (items.length === 0) {
      req.reject(400, 'PO must have at least one item');
    }

    const total = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);

    await UPDATE('com.epm.PurchaseOrders')
      .set({
        status: 'Submitted',
        totalAmount: +total.toFixed(2)
      })
      .where({ ID });

    const supplier = await SELECT.one.from('com.epm.Suppliers')
      .where({ ID: po.supplier_ID });

    await this.emit('POSubmitted', {
      poId: ID,
      poNumber: po.poNumber,
      supplierName: supplier?.name || 'Unknown',
      totalAmount: +total.toFixed(2),
      submittedBy: req.user.id
    });

    return {
      status: 'Submitted',
      message: `PO ${po.poNumber} submitted for approval`
    };
  });

  this.on('approve', 'PurchaseOrders', async (req) => {
    const { ID } = req.params[0];
    const { comment } = req.data;

    const po = await SELECT.one.from('com.epm.PurchaseOrders').where({ ID });
    if (!po) req.reject(404, 'Purchase Order not found');

    if (po.status !== 'Submitted') {
      req.reject(400, `Only Submitted POs can be approved. Current status: ${po.status}`);
    }

    await UPDATE('com.epm.PurchaseOrders')
      .set({ status: 'Approved' })
      .where({ ID });

    await this.emit('POApproved', {
      poId: ID,
      poNumber: po.poNumber,
      approvedBy: req.user.id,
      comment: comment || ''
    });

    return {
      status: 'Approved',
      message: `PO ${po.poNumber} approved`,
      approvedAt: new Date().toISOString()
    };
  });

  this.on('reject', 'PurchaseOrders', async (req) => {
    const { ID } = req.params[0];
    const { reason } = req.data;

    const po = await SELECT.one.from('com.epm.PurchaseOrders').where({ ID });
    if (!po) req.reject(404, 'Purchase Order not found');

    if (po.status !== 'Submitted') {
      req.reject(400, `Only Submitted POs can be rejected. Current status: ${po.status}`);
    }

    if (!reason || reason.trim() === '') {
      req.reject(400, 'Rejection reason is required');
    }

    await UPDATE('com.epm.PurchaseOrders')
      .set({ status: 'Rejected' })
      .where({ ID });

    await this.emit('POrejected', {
      poId: ID,
      poNumber: po.poNumber,
      rejectedBy: req.user.id,
      reason
    });

    return {
      status: 'Rejected',
      message: `PO ${po.poNumber} rejected. Reason: ${reason}`
    };
  });

  this.on('receive', 'PurchaseOrders', async (req) => {
    const { ID } = req.params[0];
    const { notes } = req.data;

    const po = await SELECT.one.from('com.epm.PurchaseOrders').where({ ID });
    if (!po) req.reject(404, 'Purchase Order not found');

    if (po.status !== 'Approved') {
      req.reject(400, `Only Approved POs can be received. Current status: ${po.status}`);
    }

    await UPDATE('com.epm.PurchaseOrders')
      .set({ status: 'Received' })
      .where({ ID });

    const items = await SELECT.from('com.epm.PurchaseOrderItems')
      .where({ order_ID: ID });

    for (const item of items) {
      const product = await SELECT.one.from('com.epm.Products')
        .where({ ID: item.product_ID });

      if (product) {
        await UPDATE('com.epm.Products')
          .set({ stock: product.stock + item.quantity })
          .where({ ID: item.product_ID });
      }
    }

    return {
      status: 'Received',
      message: `PO ${po.poNumber} received. Stock updated for ${items.length} products.${notes ? ' Notes: ' + notes : ''}`
    };
  });

  this.on('getSummary', 'PurchaseOrders', async (req) => {
    const { ID } = req.params[0];

    const po = await SELECT.one.from('com.epm.PurchaseOrders').where({ ID });
    if (!po) req.reject(404, 'Purchase Order not found');

    const items = await SELECT.from('com.epm.PurchaseOrderItems')
      .where({ order_ID: ID });

    const supplier = await SELECT.one.from('com.epm.Suppliers')
      .where({ ID: po.supplier_ID });

    const createdDate = new Date(po.createdAt || po.orderDate);
    const today = new Date();
    const daysOpen = Math.floor((today - createdDate) / (1000 * 60 * 60 * 24));

    const totalAmount = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);

    return {
      poNumber: po.poNumber,
      supplier: supplier?.name || 'Unknown',
      itemCount: items.length,
      totalAmount: +totalAmount.toFixed(2),
      status: po.status,
      daysOpen
    };
  });

  this.on('getPurchasingDashboard', async () => {
    const allPOs = await SELECT.from('com.epm.PurchaseOrders');

    return {
      totalPOs: allPOs.length,
      draftCount: allPOs.filter(p => p.status === 'Draft').length,
      pendingApproval: allPOs.filter(p => p.status === 'Submitted').length,
      approvedCount: allPOs.filter(p => p.status === 'Approved').length,
      totalSpend: +allPOs
        .filter(p => ['Approved', 'Received'].includes(p.status))
        .reduce((sum, p) => sum + (p.totalAmount || 0), 0)
        .toFixed(2),
      rejectedpoCount: allPOs.filter(p => p.status === 'Rejected').length
    };
  });

  this.on('POSubmitted', (msg) => {
    const { poNumber, supplierName, totalAmount, submittedBy } = msg.data;
    console.log(`PO SUBMITTED: ${poNumber}, Supplier: ${supplierName}, Amount: ${totalAmount}, By: ${submittedBy}`);
  });

  this.on('POApproved', (msg) => {
    const { poNumber, approvedBy, comment } = msg.data;
    console.log(`PO APPROVED: ${poNumber}, By: ${approvedBy}, Comment: ${comment}`);
  });

  this.on('POrejected', (msg) => {
    const { poNumber, rejectedBy, reason } = msg.data;
    console.log(`PO REJECTED: ${poNumber}, By: ${rejectedBy}, Reason: ${reason}`);
  });

};