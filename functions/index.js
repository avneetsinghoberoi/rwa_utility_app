const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

admin.initializeApp();

exports.verifyPayment = onCall({ region: "asia-south1" }, async (request) => {
  const db = admin.firestore();
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError("unauthenticated", "Login required.");

  // ✅ Simple admin check (based on your users.role)
  const adminDoc = await db.collection("users").doc(uid).get();
  if (!adminDoc.exists || (adminDoc.data()?.role || "").toLowerCase() != "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  const { paymentDocId } = request.data || {};
  if (!paymentDocId) throw new HttpsError("invalid-argument", "paymentDocId is required");

  const paymentRef = db.collection("payments_new").doc(paymentDocId);

  return await db.runTransaction(async (tx) => {
    const paySnap = await tx.get(paymentRef);
    if (!paySnap.exists) throw new HttpsError("not-found", "Payment not found");

    const pay = paySnap.data();

    if (pay.status !== "SUBMITTED") {
      throw new HttpsError("failed-precondition", "Payment already processed");
    }

    const invoiceId = pay.invoice_id;
    const invoiceRef = db.collection("invoices").doc(invoiceId);
    const invSnap = await tx.get(invoiceRef);
    if (!invSnap.exists) throw new HttpsError("not-found", "Invoice not found");

    const inv = invSnap.data();
    const userRef = db.collection("users").doc(pay.uid);

    // 1) mark payment verified
    tx.update(paymentRef, {
      status: "VERIFIED",
      verified_at: admin.firestore.FieldValue.serverTimestamp(),
      verified_by: uid,
      admin_note: pay.admin_note || "",
    });

    // 2) update invoice
    const paidAmount = Number(inv.paid_amount || 0) + Number(pay.amount || 0);
    const invoiceTotal = Number(inv.amount || 0);

    tx.update(invoiceRef, {
      paid_amount: paidAmount,
      status: paidAmount >= invoiceTotal ? "PAID" : "PARTIAL",
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3) update your existing user fields (same ones your scheduler uses)
    tx.set(
      userRef,
      {
        dues: admin.firestore.FieldValue.increment(-Number(pay.amount || 0)),
        ledger: {
          total_paid: admin.firestore.FieldValue.increment(Number(pay.amount || 0)),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        last_payment_date: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { ok: true };
  });
});

exports.rejectPayment = onCall({ region: "asia-south1" }, async (request) => {
  const db = admin.firestore();
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Login required.");

  const adminDoc = await db.collection("users").doc(uid).get();
  if (!adminDoc.exists || (adminDoc.data()?.role || "").toLowerCase() != "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  const { paymentDocId, reason } = request.data || {};
  if (!paymentDocId) throw new HttpsError("invalid-argument", "paymentDocId is required");

  await db.collection("payments_new").doc(paymentDocId).update({
    status: "REJECTED",
    verified_at: admin.firestore.FieldValue.serverTimestamp(),
    verified_by: uid,
    admin_note: reason || "Rejected",
  });

  return { ok: true };
});



