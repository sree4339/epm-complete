const cds = require('@sap/cds');

module.exports = function () {

  // SALES ORDERS - VALIDATIONS
  this.before('CREATE', 'SalesOrders', async (req) => {
    const { customer_ID, orderDate, items } = req.data;

    if (!customer_ID) {
      req.error(400, 'Customer is required for orders', 'customer_ID');
    }

    if (orderDate) {
      const today = new Date().toISOString().split('T')[0];

      if (orderDate < today) {
        req.error(400, 'Order date cannot be in the past', 'orderDate');
      }
    }

    if (!items || items.length === 0) {
      req.error(400, 'Order must have at least one item');
    }

    if (items) {
      for (let i = 0; i < items.length; i++) {
        const item = items[i];

        if (!item.product_ID) {
          req.error(400, `Item ${i + 1}: Product is required`);
        }

        if (!item.quantity || item.quantity <= 0) {
          req.error(400, `Item ${i + 1}: Quantity must be greater than zero`);
        }

        if (!item.unitPrice || item.unitPrice <= 0) {
          req.error(400, `Item ${i + 1}: Unit price must be greater than zero`);
        }
      }
    }

    if (customer_ID) {
      const customer = await SELECT.one.from('com.epm.Customers')
        .where({ ID: customer_ID });

      if (!customer) {
        req.error(404, 'Customer not found', 'customer_ID');
      }
    }
  });

  // AUTO CALCULATE TOTALS
  this.before('CREATE', 'SalesOrders', (req) => {
    const { items } = req.data;

    if (items && items.length > 0) {
      let netAmount = 0;

      for (const item of items) {
        item.netAmount = +(item.quantity * item.unitPrice).toFixed(2);
        netAmount += item.netAmount;
      }

      req.data.netAmount = +netAmount.toFixed(2);
      req.data.taxAmount = +(netAmount * 0.18).toFixed(2);
      req.data.totalAmount = +(netAmount + req.data.taxAmount).toFixed(2);
    }

    if (!req.data.status) {
      req.data.status = 'New';
    }
  });

  // STATUS TRANSITION VALIDATION
  this.before('UPDATE', 'SalesOrders', async (req) => {
    if (req.data.status) {
      const orderId = req.params[0]?.ID || req.params[0];

      const order = await SELECT.one.from('com.epm.SalesOrders')
        .where({ ID: orderId });

      if (!order) {
        req.reject(404, 'Order not found');
      }

      const transitions = {
        New: ['Confirmed', 'Cancelled'],
        Confirmed: ['Shipped', 'Cancelled'],
        Shipped: ['Delivered'],
        Delivered: [],
        Cancelled: []
      };

      const allowed = transitions[order.status] || [];

      if (!allowed.includes(req.data.status)) {
        req.reject(
          400,
          `Cannot change status from "${order.status}" to "${req.data.status}". Allowed: ${allowed.join(', ') || 'none'}`
        );
      }
    }
  });

  // PREVENT DELETE DELIVERED ORDER
  this.before('DELETE', 'SalesOrders', async (req) => {
    const orderId = req.params[0]?.ID || req.params[0];

    const order = await SELECT.one.from('com.epm.SalesOrders')
      .where({ ID: orderId });

    if (order && order.status === 'Delivered') {
      req.reject(409, 'Cannot delete a delivered order');
    }
  });
  // BOUND ACTION: confirm
  this.on('confirm', 'SalesOrders', async (req) => {
    const orderId = req.params[0]?.ID || req.params[0];

    const order = await SELECT.one.from('com.epm.SalesOrders')
      .where({ ID: orderId });

    if (!order) {
      req.reject(404, 'Order not found');
    }

    if (order.status !== 'New') {
      req.reject(400, `Only New orders can be confirmed. Current status: ${order.status}`);
    }

    await UPDATE('com.epm.SalesOrders')
      .set({ status: 'Confirmed' })
      .where({ ID: orderId });

    return {
      status: 'Confirmed',
      message: `Order ${order.orderNumber} confirmed successfully`
    };
  });

  // BOUND ACTION: cancel
  this.on('cancel', 'SalesOrders', async (req) => {
    const orderId = req.params[0]?.ID || req.params[0];
    const { reason } = req.data;

    const order = await SELECT.one.from('com.epm.SalesOrders')
      .where({ ID: orderId });

    if (!order) {
      req.reject(404, 'Order not found');
    }

    if (!reason || reason.trim() === '') {
      req.reject(400, 'Cancellation reason is required');
    }

    if (order.status === 'Delivered') {
      req.reject(400, 'Cannot cancel a delivered order');
    }

    if (order.status === 'Cancelled') {
      req.reject(400, 'Order is already cancelled');
    }

    await UPDATE('com.epm.SalesOrders')
      .set({ status: 'Cancelled' })
      .where({ ID: orderId });

    const refundAmount =
      order.status === 'Confirmed' || order.status === 'Shipped'
        ? order.totalAmount
        : 0;

    return {
      status: 'Cancelled',
      message: `Order ${order.orderNumber} cancelled. Reason: ${reason}`,
      refundAmount: refundAmount
    };
  });

  // BOUND ACTION: ship
  this.on('ship', 'SalesOrders', async (req) => {
    const orderId = req.params[0]?.ID || req.params[0];
    const { trackingNumber, carrier } = req.data;

    const order = await SELECT.one.from('com.epm.SalesOrders')
      .where({ ID: orderId });

    if (!order) {
      req.reject(404, 'Order not found');
    }

    if (order.status !== 'Confirmed') {
      req.reject(400, `Cannot ship order in "${order.status}" status. Order must be "Confirmed" first.`);
    }

    if (!trackingNumber) {
      req.reject(400, 'Tracking number is required');
    }

    if (!carrier) {
      req.reject(400, 'Carrier name is required');
    }

    await UPDATE('com.epm.SalesOrders')
      .set({ status: 'Shipped' })
      .where({ ID: orderId });

    const deliveryDate = new Date();
    deliveryDate.setDate(deliveryDate.getDate() + 5);

    return {
      status: 'Shipped',
      message: `Order ${order.orderNumber} shipped via ${carrier}. Tracking: ${trackingNumber}`,
      estimatedDelivery: deliveryDate.toISOString().split('T')[0]
    };
  });

};