const admin      = require("firebase-admin");
const crypto     = require("crypto");
const nodemailer = require("nodemailer");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const { createObjectCsvStringifier } = require("csv-writer");

admin.initializeApp();
setGlobalOptions({ region: "us-central1" });

const DEPLOYMENT_TAG = "no-app-check-admin-callables-2026-04-17";

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/** Returns "YYYY-MM" for a given Date (or today). */
function monthKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  return `${y}-${m}`;
}

/** Human-readable label, e.g. "April 2026". */
function monthLabel(date = new Date()) {
  return date.toLocaleString("en-IN", { month: "long", year: "numeric" });
}

function logCallableRequest(name, request, extra = {}) {
  console.log(`[${name}] callable request`, {
    deploymentTag: DEPLOYMENT_TAG,
    region: "us-central1",
    authPresent: Boolean(request.auth),
    authUid: request.auth?.uid || null,
    appCheckPresent: Boolean(request.app),
    ...extra,
  });
}

async function resolveAuthContext(request) {
  // ── Primary path: Firebase callable SDK auto-populates request.auth ──
  if (request.auth?.uid) {
    console.log("[resolveAuthContext] via=callable-auth uid=" + request.auth.uid);
    return {
      uid: request.auth.uid,
      email: String(request.auth.token?.email || ""),
      via: "callable-auth",
    };
  }

  // ── Fallback path: client manually passes the ID token in request.data ─
  const fallbackToken = String(request.data?.authToken || "");
  console.warn(
    "[resolveAuthContext] request.auth is null — attempting fallback token. " +
    "tokenPresent=" + Boolean(fallbackToken) + " tokenLength=" + fallbackToken.length
  );

  if (!fallbackToken) {
    console.error("[resolveAuthContext] No auth token provided in either path.");
    throw new HttpsError("unauthenticated", "Login required.");
  }

  try {
    const decoded = await admin.auth().verifyIdToken(fallbackToken, /* checkRevoked= */ true);
    console.log("[resolveAuthContext] via=payload-token uid=" + decoded.uid);
    return {
      uid: decoded.uid,
      email: String(decoded.email || ""),
      via: "payload-token",
    };
  } catch (error) {
    console.error("[resolveAuthContext] fallback verifyIdToken failed:", error.code, error.message);
    throw new HttpsError("unauthenticated", "Login required.");
  }
}

/**
 * Core logic: creates one invoice per resident for the given month.
 * Idempotent — skips the month if invoices already exist.
 * Returns { created, skipped, month }.
 */
async function _generateInvoicesForMonth(db, targetMonthKey) {
  // Guard: do nothing if invoices already generated for this month
  const existing = await db.collection("invoices")
    .where("month", "==", targetMonthKey)
    .limit(1)
    .get();

  if (!existing.empty) {
    console.log(`Invoices for ${targetMonthKey} already exist — skipping.`);
    return { created: 0, skipped: true, month: targetMonthKey };
  }

  // Fetch all residents
  const usersSnap = await db.collection("users")
    .where("role", "==", "user")
    .get();

  if (usersSnap.empty) {
    console.log("No resident users found.");
    return { created: 0, skipped: false, month: targetMonthKey };
  }

  // Batch-create one invoice per resident
  const BATCH_LIMIT = 400; // Firestore batch limit is 500; stay safe
  let batch = db.batch();
  let count = 0;
  let batchCount = 0;

  for (const userDoc of usersSnap.docs) {
    const u = userDoc.data();
    const ref = db.collection("invoices").doc();
    batch.set(ref, {
      uid:        userDoc.id,
      house_no:   u.house_no   || "",
      name:       u.name       || "",
      email:      u.email      || "",
      month:      targetMonthKey,
      amount:     1500,
      paid_amount: 0,
      status:     "UNPAID",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    count++;
    batchCount++;

    // Commit and start fresh batch every BATCH_LIMIT writes
    if (batchCount === BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) await batch.commit();

  console.log(`Generated ${count} invoices for ${targetMonthKey}.`);

  // Notify all residents about their new monthly maintenance invoice (non-fatal)
  try {
    const tokens = await getAllResidentFcmTokens(db);
    const label = monthLabel(new Date(targetMonthKey + "-01"));
    await sendFcmMulticast(
      tokens,
      `🏠 Maintenance Due — ${label}`,
      `Your monthly maintenance invoice of ₹1500 has been generated.`,
      { type: "INVOICE_GENERATED", month: targetMonthKey }
    );
  } catch (fcmErr) {
    console.error("[_generateInvoicesForMonth] FCM error (non-fatal):", fcmErr.message);
  }

  return { created: count, skipped: false, month: targetMonthKey };
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED: runs automatically on the 1st of every month at 00:05 IST
// ─────────────────────────────────────────────────────────────────────────────
exports.generateMonthlyInvoices = onSchedule(
  { schedule: "5 0 1 * *", timeZone: "Asia/Kolkata" },
  async () => {
    const db = admin.firestore();
    const result = await _generateInvoicesForMonth(db, monthKey());
    console.log("Scheduled invoice generation result:", result);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: admin can trigger manually from the app as a backup
// ─────────────────────────────────────────────────────────────────────────────
exports.generateInvoicesManual = onCall({ enforceAppCheck: false }, async (request) => {
  const db = admin.firestore();
  logCallableRequest("generateInvoicesManual", request);
  await requireAdminFromRequest(db, request);

  // Optional: caller can pass a specific month, defaults to current month
  const targetMonth = typeof request.data?.month === "string" && request.data.month.match(/^\d{4}-\d{2}$/)
    ? request.data.month
    : monthKey();

  const result = await _generateInvoicesForMonth(db, targetMonth);
  return result;
});

async function getUserRecordByUidOrEmail(db, { uid, email }) {
  if (uid) {
    const byUid = await db.collection("users").doc(uid).get();
    if (byUid.exists) return byUid;
  }

  if (email) {
    const byEmail = await db.collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();
    if (!byEmail.empty) return byEmail.docs[0];
  }

  return null;
}

async function requireAdmin(db, uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) throw new HttpsError("permission-denied", "Admin record not found.");
  const role = String(snap.data().role || "").toLowerCase();
  if (role !== "admin") throw new HttpsError("permission-denied", "Admin only.");
  return uid; // admin uid
}

async function requireAdminFromAuthContext(db, authContext) {
  const authUid = authContext.uid;
  const email = authContext.email;
  const userRecord = await getUserRecordByUidOrEmail(db, { uid: authUid, email });

  if (!userRecord) {
    throw new HttpsError("permission-denied", "Admin record not found.");
  }

  const role = String(userRecord.data().role || "").toLowerCase();
  if (role !== "admin") throw new HttpsError("permission-denied", "Admin only.");

  return {
    authUid,
    userDocId: userRecord.id,
    via: authContext.via,
  };
}

async function requireAdminFromRequest(db, request) {
  const authContext = await resolveAuthContext(request);
  return requireAdminFromAuthContext(db, authContext);
}

async function getResidentRecordForPayment(tx, db, pay) {
  const paymentUid = String(pay.uid || "");
  const houseNo = String(pay.house_no || "");

  if (paymentUid) {
    const byUid = await tx.get(db.collection("users").doc(paymentUid));
    if (byUid.exists) return byUid;
  }

  if (houseNo) {
    const byHouseNo = await tx.get(
      db.collection("users")
        .where("house_no", "==", houseNo)
        .limit(1)
    );
    if (!byHouseNo.empty) return byHouseNo.docs[0];
  }

  return null;
}

async function getPendingInvoicesForPayment(tx, db, pay, residentDocId) {
  const paymentUid = String(pay.uid || "");
  const houseNo = String(pay.house_no || "");
  const explicitInvoiceId = String(pay.invoice_id || "");

  const byResidentDoc = await tx.get(
    db.collection("invoices")
      .where("uid", "==", residentDocId)
      .where("status", "in", ["UNPAID", "PARTIAL"])
  );
  if (!byResidentDoc.empty) {
    return byResidentDoc.docs.sort((a, b) =>
      String(a.data().month || "").localeCompare(String(b.data().month || ""))
    );
  }

  if (paymentUid && paymentUid !== residentDocId) {
    const byAuthUid = await tx.get(
      db.collection("invoices")
        .where("uid", "==", paymentUid)
        .where("status", "in", ["UNPAID", "PARTIAL"])
    );
    if (!byAuthUid.empty) {
      return byAuthUid.docs.sort((a, b) =>
        String(a.data().month || "").localeCompare(String(b.data().month || ""))
      );
    }
  }

  if (houseNo) {
    const byHouseNo = await tx.get(
      db.collection("invoices")
        .where("house_no", "==", houseNo)
    );
    const pending = byHouseNo.docs
      .filter((doc) => ["UNPAID", "PARTIAL"].includes(String(doc.data().status || "")))
      .sort((a, b) =>
        String(a.data().month || "").localeCompare(String(b.data().month || ""))
      );
    if (pending.length > 0) {
      return pending;
    }
  }

  if (explicitInvoiceId) {
    const invoiceSnap = await tx.get(db.collection("invoices").doc(explicitInvoiceId));
    if (invoiceSnap.exists) {
      const status = String(invoiceSnap.data().status || "");
      if (status === "UNPAID" || status === "PARTIAL") {
        return [invoiceSnap];
      }
    }
  }

  return [];
}

async function verifyPaymentInternal(db, adminAuthUid, paymentDocId) {
  if (!paymentDocId) throw new HttpsError("invalid-argument", "paymentDocId required.");

  const paymentRef = db.collection("payments").doc(paymentDocId);

  return db.runTransaction(async (tx) => {
    const paySnap = await tx.get(paymentRef);
    if (!paySnap.exists) throw new HttpsError("not-found", "Payment not found.");

    const pay = paySnap.data();
    if (pay.status !== "SUBMITTED") {
      throw new HttpsError("failed-precondition", `Payment not SUBMITTED (is ${pay.status}).`);
    }

    const uid = String(pay.uid);
    const amount = Number(pay.amount || 0);
    if (!uid || !Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError("invalid-argument", "Bad payment data.");
    }

    const userSnap = await getResidentRecordForPayment(tx, db, pay);
    if (!userSnap) throw new HttpsError("not-found", "User not found.");

    const user = userSnap.data();
    const userRef = userSnap.ref;
    const currentDues = Number(user.dues || 0);
    const houseNo = String(user.house_no || pay.house_no || "");

    const pendingInvoices = await getPendingInvoicesForPayment(tx, db, pay, userRef.id);

    let remaining = amount;
    const allocation = {};

    for (const doc of pendingInvoices) {
      if (remaining <= 0) break;
      const inv = doc.data();
      const invAmt = Number(inv.amount || 0);
      const invPaid = Number(inv.paid_amount || 0);
      const pending = Math.max(0, invAmt - invPaid);
      if (pending <= 0) continue;

      const payHere = Math.min(remaining, pending);
      const newPaid = invPaid + payHere;
      const newStatus = invoiceStatus(invAmt, newPaid);

      allocation[doc.id] = payHere;

      tx.update(doc.ref, {
        paid_amount: newPaid,
        status: newStatus,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      remaining -= payHere;
    }

    const allocatedTotal = Object.values(allocation).reduce((a, b) => a + b, 0);

    const newDues = Math.max(0, currentDues - allocatedTotal);
    tx.set(userRef, {
      dues: newDues,
      last_payment_date: admin.firestore.FieldValue.serverTimestamp(),
      ledger: {
        ...(user.ledger || {}),
        total_paid: Number(user.ledger?.total_paid || 0) + allocatedTotal,
        total_due: newDues,
      }
    }, { merge: true });

    tx.set(paymentRef, {
      status: "VERIFIED",
      verified_at: admin.firestore.FieldValue.serverTimestamp(),
      verified_by: adminAuthUid,
      allocation,
      house_no: houseNo,
      resolved_user_doc_id: userRef.id,
    }, { merge: true });

    const receiptId = String(pay.receipt_id || "");
    if (receiptId) {
      const receiptRef = db.collection("receipts").doc(receiptId);
      tx.set(receiptRef, {
        receipt_type: "FINAL",
        status: "VERIFIED",
        allocation,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } else {
      const receiptRef = db.collection("receipts").doc();
      tx.set(receiptRef, {
        uid,
        house_no: houseNo,
        payment_id: paymentDocId,
        amount: allocatedTotal,
        utr: String(pay.utr || ""),
        receipt_type: "FINAL",
        status: "VERIFIED",
        allocation,
        admin_note: "",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        receipt_url: "",
      });
      tx.set(paymentRef, { receipt_id: receiptRef.id }, { merge: true });
    }

    return { allocatedTotal, allocation, newDues, residentUid: userRef.id };
  });
}


function invoiceStatus(amount, paid) {
  if (paid <= 0) return "UNPAID";
  if (paid >= amount) return "PAID";
  return "PARTIAL";
}

/**
 * VERIFY (Manual)
 * - payment SUBMITTED -> VERIFIED
 * - apply Option B allocation oldest month first
 * - update invoices, users.dues
 * - update receipt ACK -> FINAL
 */
exports.verifyPaymentManual = onCall({ enforceAppCheck: false }, async (request) => {
  const db = admin.firestore();
  logCallableRequest("verifyPaymentManual", request, {
    paymentDocId: String(request.data?.paymentDocId || ""),
  });
  const adminUser = await requireAdminFromRequest(db, request);
  return verifyPaymentInternal(
    db,
    adminUser.authUid,
    String(request.data?.paymentDocId || "")
  );
});

exports.verifyPaymentManualHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method-not-allowed" });
    return;
  }

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const fallbackToken = bearer.startsWith("Bearer ")
      ? bearer.slice("Bearer ".length)
      : String(body.authToken || "");

    const authContext = await resolveAuthContext({
      auth: null,
      data: { authToken: fallbackToken },
    });
    const adminUser = await requireAdminFromAuthContext(db, authContext);
    const paymentDocId = String(body.paymentDocId || "");

    console.log("[verifyPaymentManualHttp] request", {
      deploymentTag: DEPLOYMENT_TAG,
      adminAuthUid: adminUser.authUid,
      paymentDocId,
    });

    const result = await verifyPaymentInternal(db, adminUser.authUid, paymentDocId);

    // Notify the resident (non-fatal)
    try {
      const tokens = await getFcmTokensForUids(db, [result.residentUid]);
      await sendFcmMulticast(
        tokens,
        "✅ Payment Verified",
        `Your payment of ₹${result.allocatedTotal} has been verified. Outstanding: ₹${result.newDues}`,
        { type: "PAYMENT_VERIFIED", paymentId: paymentDocId }
      );
    } catch (fcmErr) {
      console.error("[verifyPaymentManualHttp] FCM error (non-fatal):", fcmErr.message);
    }

    res.status(200).json({ ok: true, result });
  } catch (error) {
    if (error instanceof HttpsError) {
      res.status(error.httpErrorCode.status).json({
        error: {
          status: error.code.toUpperCase().replace(/-/g, "_"),
          message: error.message,
        },
      });
      return;
    }

    console.error("verifyPaymentManualHttp unexpected error", error);
    res.status(500).json({
      error: {
        status: "INTERNAL",
        message: "Internal error",
      },
    });
  }
});

/**
 * REJECT (Manual) — HTTP version for Flutter (bypasses App Check interceptor)
 */
exports.rejectPaymentManualHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method-not-allowed" });
    return;
  }

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const fallbackToken = bearer.startsWith("Bearer ")
      ? bearer.slice("Bearer ".length)
      : String(body.authToken || "");

    const authContext = await resolveAuthContext({
      auth: null,
      data: { authToken: fallbackToken },
    });
    const adminUser = await requireAdminFromAuthContext(db, authContext);

    const paymentDocId = String(body.paymentDocId || "");
    const reason = String(body.reason || "").trim();
    if (!paymentDocId || !reason) {
      res.status(400).json({ error: { status: "INVALID_ARGUMENT", message: "paymentDocId + reason required." } });
      return;
    }

    console.log("[rejectPaymentManualHttp] request", {
      deploymentTag: DEPLOYMENT_TAG,
      adminAuthUid: adminUser.authUid,
      paymentDocId,
    });

    const paymentRef = db.collection("payments").doc(paymentDocId);
    let residentUid = "";

    await db.runTransaction(async (tx) => {
      const paySnap = await tx.get(paymentRef);
      if (!paySnap.exists) throw new HttpsError("not-found", "Payment not found.");
      const pay = paySnap.data();
      if (pay.status !== "SUBMITTED") {
        throw new HttpsError("failed-precondition", `Payment not SUBMITTED (is ${pay.status}).`);
      }
      residentUid = String(pay.uid || ""); // capture for FCM after transaction
      tx.set(paymentRef, {
        status: "REJECTED",
        admin_note: reason,
        verified_at: admin.firestore.FieldValue.serverTimestamp(),
        verified_by: adminUser.authUid,
      }, { merge: true });
      const receiptId = String(pay.receipt_id || "");
      if (receiptId) {
        tx.set(db.collection("receipts").doc(receiptId), {
          status: "REJECTED",
          receipt_type: "ACK",
          admin_note: reason,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    });

    // Notify the resident (non-fatal)
    try {
      if (residentUid) {
        const tokens = await getFcmTokensForUids(db, [residentUid]);
        await sendFcmMulticast(
          tokens,
          "❌ Payment Rejected",
          `Your payment was rejected. Reason: ${reason}. Please resubmit.`,
          { type: "PAYMENT_REJECTED", paymentId: paymentDocId }
        );
      }
    } catch (fcmErr) {
      console.error("[rejectPaymentManualHttp] FCM error (non-fatal):", fcmErr.message);
    }

    res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof HttpsError) {
      res.status(error.httpErrorCode.status).json({
        error: {
          status: error.code.toUpperCase().replace(/-/g, "_"),
          message: error.message,
        },
      });
      return;
    }
    console.error("rejectPaymentManualHttp unexpected error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: "Internal error" } });
  }
});

/**
 * GENERATE INVOICES (Manual) — HTTP version for Flutter (bypasses App Check interceptor)
 */
exports.generateInvoicesManualHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method-not-allowed" });
    return;
  }

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const fallbackToken = bearer.startsWith("Bearer ")
      ? bearer.slice("Bearer ".length)
      : String(body.authToken || "");

    const authContext = await resolveAuthContext({
      auth: null,
      data: { authToken: fallbackToken },
    });
    await requireAdminFromAuthContext(db, authContext);

    const targetMonth = typeof body.month === "string" && body.month.match(/^\d{4}-\d{2}$/)
      ? body.month
      : monthKey();

    console.log("[generateInvoicesManualHttp] request", {
      deploymentTag: DEPLOYMENT_TAG,
      targetMonth,
    });

    const result = await _generateInvoicesForMonth(db, targetMonth);
    res.status(200).json({ ok: true, result });
  } catch (error) {
    if (error instanceof HttpsError) {
      res.status(error.httpErrorCode.status).json({
        error: {
          status: error.code.toUpperCase().replace(/-/g, "_"),
          message: error.message,
        },
      });
      return;
    }
    console.error("generateInvoicesManualHttp unexpected error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: "Internal error" } });
  }
});

/**
 * REJECT (Manual)
 */
exports.rejectPaymentManual = onCall({ enforceAppCheck: false }, async (request) => {
  const db = admin.firestore();
  logCallableRequest("rejectPaymentManual", request, {
    paymentDocId: String(request.data?.paymentDocId || ""),
  });
  const adminUser = await requireAdminFromRequest(db, request);


  const paymentDocId = String(request.data?.paymentDocId || "");
  const reason = String(request.data?.reason || "").trim();
  if (!paymentDocId || !reason) throw new HttpsError("invalid-argument", "paymentDocId + reason required.");

  const paymentRef = db.collection("payments").doc(paymentDocId);

  await db.runTransaction(async (tx) => {
    const paySnap = await tx.get(paymentRef);
    if (!paySnap.exists) throw new HttpsError("not-found", "Payment not found.");
    const pay = paySnap.data();

    if (pay.status !== "SUBMITTED") {
      throw new HttpsError("failed-precondition", `Payment not SUBMITTED (is ${pay.status}).`);
    }

    tx.set(paymentRef, {
      status: "REJECTED",
      admin_note: reason,
      verified_at: admin.firestore.FieldValue.serverTimestamp(),
      verified_by: adminUser.authUid,
    }, { merge: true });

    const receiptId = String(pay.receipt_id || "");
    if (receiptId) {
      tx.set(db.collection("receipts").doc(receiptId), {
        status: "REJECTED",
        receipt_type: "ACK",
        admin_note: reason,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  });

  return { ok: true };
});

/**
 * EXPORT CSV for a month (Admin)
 */
exports.exportMonthCsv = onCall({ enforceAppCheck: false }, async (request) => {
  const db = admin.firestore();
  logCallableRequest("exportMonthCsv", request, {
    month: String(request.data?.month || ""),
  });
  await requireAdminFromRequest(db, request);


  const month = String(request.data?.month || "");
  if (!month) throw new HttpsError("invalid-argument", "month required (YYYY-MM).");

  const invSnap = await db.collection("invoices").where("month", "==", month).get();

  // join user names
  const userIds = [...new Set(invSnap.docs.map(d => String(d.data().uid || "")))].filter(Boolean);
  const userDocs = await Promise.all(userIds.map(id => db.collection("users").doc(id).get()));
  const userMap = new Map();
  userDocs.forEach(u => { if (u.exists) userMap.set(u.id, u.data()); });

  const rows = invSnap.docs.map(d => {
    const inv = d.data();
    const u = userMap.get(String(inv.uid)) || {};
    const billed = Number(inv.amount || 0);
    const paid = Number(inv.paid_amount || 0);
    const pending = Math.max(0, billed - paid);
    return {
      month: inv.month,
      house_no: String(inv.house_no || u.house_no || ""),
      name: String(u.name || ""),
      billed,
      paid,
      pending,
      status: String(inv.status || ""),
      invoice_id: d.id,
    };
  });

  const csv = createObjectCsvStringifier({
    header: [
      { id: "month", title: "MONTH" },
      { id: "house_no", title: "HOUSE_NO" },
      { id: "name", title: "NAME" },
      { id: "billed", title: "BILLED" },
      { id: "paid", title: "PAID" },
      { id: "pending", title: "PENDING" },
      { id: "status", title: "STATUS" },
      { id: "invoice_id", title: "INVOICE_ID" },
    ],
  });

  const csvContent = csv.getHeaderString() + csv.stringifyRecords(rows);

  // save to Storage + signed url
  const bucket = admin.storage().bucket();
  const path = `exports/${month}/invoices_${month}_${Date.now()}.csv`;
  const file = bucket.file(path);

  await file.save(csvContent, { contentType: "text/csv", resumable: false });

  const [url] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + 60 * 60 * 1000, // 1 hour
  });

  return { url, count: rows.length };
});

// =============================================================================
// DEMAND DUES
// =============================================================================

/**
 * Helper to build a standard HTTP error response for demand-due endpoints.
 */
function httpError(res, status, code, message) {
  return res.status(status).json({ error: { status: code, message } });
}

/**
 * CREATE DEMAND DUE
 * POST /createDemandDueHttp
 * Body: { title, description, category, amountPerUnit, targetType, targetHouses[], dueDateMs }
 *
 * Creates a demand_dues document and one invoice per targeted resident.
 * Idempotent per (title + month) to prevent accidental duplicates.
 */
exports.createDemandDueHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") return httpError(res, 405, "METHOD_NOT_ALLOWED", "POST only");

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : String(body.authToken || "");

    const authContext = await resolveAuthContext({ auth: null, data: { authToken: token } });
    const adminUser   = await requireAdminFromAuthContext(db, authContext);

    // ── Validate inputs ────────────────────────────────────────────
    const title       = String(body.title || "").trim();
    const description = String(body.description || "").trim();
    const category    = String(body.category || "Other").trim();
    const amount      = Number(body.amountPerUnit);
    const targetType  = String(body.targetType || "ALL"); // "ALL" | "SPECIFIC"
    const targetHouses = Array.isArray(body.targetHouses) ? body.targetHouses.map(String) : [];
    const dueDateMs   = Number(body.dueDateMs);

    if (!title)                        return httpError(res, 400, "INVALID_ARGUMENT", "title required");
    if (!Number.isFinite(amount) || amount <= 0) return httpError(res, 400, "INVALID_ARGUMENT", "amountPerUnit must be > 0");
    if (!Number.isFinite(dueDateMs))   return httpError(res, 400, "INVALID_ARGUMENT", "dueDateMs required");
    if (targetType === "SPECIFIC" && targetHouses.length === 0)
      return httpError(res, 400, "INVALID_ARGUMENT", "targetHouses required when targetType=SPECIFIC");

    const dueDate = admin.firestore.Timestamp.fromMillis(dueDateMs);

    // ── Fetch target residents ─────────────────────────────────────
    let usersQuery = db.collection("users").where("role", "==", "user");
    const usersSnap = await usersQuery.get();

    const targetDocs = targetType === "ALL"
      ? usersSnap.docs
      : usersSnap.docs.filter(d => targetHouses.includes(String(d.data().house_no || "")));

    if (targetDocs.length === 0)
      return httpError(res, 400, "NOT_FOUND", "No matching residents found");

    // ── Create demand_dues document ────────────────────────────────
    const demandRef = db.collection("demand_dues").doc();
    const demandData = {
      title,
      description,
      category,
      amount_per_unit: amount,
      target_type: targetType,
      target_houses: targetType === "SPECIFIC" ? targetHouses : [],
      due_date: dueDate,
      status: "ACTIVE",
      invoices_created: targetDocs.length,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_by: adminUser.authUid,
    };

    // ── Batch-create one invoice per resident ──────────────────────
    const BATCH_LIMIT = 400;
    let batch = db.batch();
    let batchCount = 0;

    batch.set(demandRef, demandData);
    batchCount++;

    for (const userDoc of targetDocs) {
      const u = userDoc.data();
      const invRef = db.collection("invoices").doc();
      batch.set(invRef, {
        type:        "DEMAND",
        uid:         userDoc.id,
        house_no:    String(u.house_no || ""),
        name:        String(u.name || ""),
        email:       String(u.email || ""),
        title,
        description,
        category,
        demand_id:   demandRef.id,
        amount,
        paid_amount: 0,
        status:      "UNPAID",
        due_date:    dueDate,
        created_at:  admin.firestore.FieldValue.serverTimestamp(),
        created_by:  adminUser.authUid,
      });
      batchCount++;

      if (batchCount >= BATCH_LIMIT) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) await batch.commit();

    console.log(`[createDemandDueHttp] Created demand due "${title}" with ${targetDocs.length} invoices. demandId=${demandRef.id}`);

    // ── Send FCM to targeted residents (non-fatal) ─────────────────────────
    try {
      const targetUids = targetDocs.map((d) => d.id);
      const tokens = await getFcmTokensForUids(db, targetUids);
      const dueDateStr = dueDate.toDate().toLocaleDateString("en-IN");
      await sendFcmMulticast(
        tokens,
        `💸 New Due: ${title}`,
        `Amount: ₹${amount}  |  Due by ${dueDateStr}`,
        { type: "DEMAND_DUE", demandId: demandRef.id }
      );
    } catch (fcmErr) {
      console.error("[createDemandDueHttp] FCM error (non-fatal):", fcmErr.message);
    }

    res.status(200).json({
      ok: true,
      demandId: demandRef.id,
      invoicesCreated: targetDocs.length,
    });
  } catch (error) {
    if (error instanceof HttpsError)
      return res.status(error.httpErrorCode.status).json({ error: { status: error.code.toUpperCase().replace(/-/g,"_"), message: error.message } });
    console.error("createDemandDueHttp error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: "Internal error" } });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// EMAIL HELPER
// ─────────────────────────────────────────────────────────────────────────────

/** Lazy-creates the Nodemailer transporter from .env / environment variables. */
function createTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });
}

const SOCIETY_NAME = process.env.SOCIETY_NAME || "RWA Society";

/** Sends a welcome email to a newly created resident with their login credentials. */
async function sendWelcomeEmail({ toEmail, toName, houseNo, tempPassword }) {
  const transporter = createTransporter();

  const html = `
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f0f4ff;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:32px 16px;">
      <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#1A56DB,#3B82F6);padding:36px 40px;border-radius:16px 16px 0 0;text-align:center;">
            <h1 style="color:#fff;margin:0;font-size:26px;letter-spacing:0.5px;">Welcome to ${SOCIETY_NAME}!</h1>
            <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;font-size:14px;">Your resident account is ready</p>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="background:#ffffff;padding:36px 40px;border-radius:0 0 16px 16px;border:1px solid #e5e7eb;">

            <p style="color:#1e293b;font-size:16px;margin:0 0 8px;">Hello <strong>${toName}</strong>,</p>
            <p style="color:#475569;font-size:14px;margin:0 0 24px;line-height:1.6;">
              The society admin has created your account on the <strong>${SOCIETY_NAME}</strong> resident app.
              You can now log in to view and pay your dues, raise issues, and stay updated with society notices.
            </p>

            <!-- Credentials box -->
            <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f7ff;border-radius:12px;margin-bottom:24px;">
              <tr><td style="padding:24px;">
                <p style="color:#1A56DB;font-weight:bold;font-size:13px;margin:0 0 16px;letter-spacing:0.5px;text-transform:uppercase;">Your Login Credentials</p>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding:8px 0;border-bottom:1px solid #dbeafe;">
                      <span style="color:#64748b;font-size:13px;">Flat / Unit</span><br>
                      <strong style="color:#1e293b;font-size:15px;">${houseNo}</strong>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:8px 0;border-bottom:1px solid #dbeafe;">
                      <span style="color:#64748b;font-size:13px;">Email Address</span><br>
                      <strong style="color:#1e293b;font-size:15px;">${toEmail}</strong>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:8px 0;">
                      <span style="color:#64748b;font-size:13px;">Temporary Password</span><br>
                      <strong style="color:#1A56DB;font-size:18px;letter-spacing:1px;">${tempPassword}</strong>
                    </td>
                  </tr>
                </table>
              </td></tr>
            </table>

            <!-- Tip -->
            <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff7ed;border-radius:10px;margin-bottom:24px;">
              <tr><td style="padding:14px 18px;">
                <p style="margin:0;color:#92400e;font-size:13px;">
                  💡 <strong>Tip:</strong> After logging in, use the <em>"Forgot Password?"</em> option on the login screen to set your own password.
                </p>
              </td></tr>
            </table>

            <p style="color:#94a3b8;font-size:12px;margin:0;text-align:center;">
              This is an automated message from the ${SOCIETY_NAME} RWA Manager app.<br>
              Please do not reply to this email.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;

  await transporter.sendMail({
    from: `"${SOCIETY_NAME} RWA" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: `Welcome to ${SOCIETY_NAME} — Your Login Credentials`,
    html,
  });
}

// =============================================================================
// FCM PUSH NOTIFICATION HELPERS
// =============================================================================

/**
 * Fetch FCM tokens for a specific list of resident UIDs.
 * Queries in chunks of 10 (Firestore 'in' limit).
 */
async function getFcmTokensForUids(db, uids) {
  if (!uids || uids.length === 0) return [];
  const tokens = [];
  for (let i = 0; i < uids.length; i += 10) {
    const chunk = uids.slice(i, i + 10);
    const snap = await db.collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", chunk)
      .get();
    snap.forEach((doc) => {
      const t = doc.data().fcm_token;
      if (t && typeof t === "string") tokens.push(t);
    });
  }
  return tokens;
}

/**
 * Fetch FCM tokens for ALL residents (role == "user").
 */
async function getAllResidentFcmTokens(db) {
  const snap = await db.collection("users").where("role", "==", "user").get();
  const tokens = [];
  snap.forEach((doc) => {
    const t = doc.data().fcm_token;
    if (t && typeof t === "string") tokens.push(t);
  });
  return tokens;
}

/**
 * Send an FCM multicast notification to a list of device tokens.
 * Sends in batches of 500 (FCM limit per request).
 * Non-throwing — logs errors but never crashes the caller.
 */
async function sendFcmMulticast(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) {
    console.log("[FCM] No tokens — skipping notification.");
    return;
  }
  // Convert all data values to strings (FCM requirement)
  const safeData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );

  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        data: safeData,
        android: {
          notification: {
            channelId: "rwa_channel",
            priority: "high",
          },
        },
        apns: {
          payload: {
            aps: { sound: "default" },
          },
        },
      });
      console.log(
        `[FCM] Sent to ${chunk.length} tokens — ` +
        `success=${response.successCount} fail=${response.failureCount}`
      );
    } catch (err) {
      console.error("[FCM] sendEachForMulticast error:", err.message || err);
    }
  }
}

/**
 * POST NOTICE
 * POST /postNoticeHttp
 * Body: { title, description, type }
 *
 * Saves the notice to Firestore and sends FCM to all residents.
 */
exports.postNoticeHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") return httpError(res, 405, "METHOD_NOT_ALLOWED", "POST only");

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body   = typeof req.body === "object" && req.body ? req.body : {};
    const token  = bearer.startsWith("Bearer ") ? bearer.slice(7) : String(body.authToken || "");

    const authContext = await resolveAuthContext({ auth: null, data: { authToken: token } });
    await requireAdminFromAuthContext(db, authContext);

    const title       = String(body.title       || "").trim();
    const description = String(body.description || "").trim();
    const type        = String(body.type        || "General").trim();
    const postedBy    = String(body.posted_by   || "Admin").trim();

    if (!title) return httpError(res, 400, "INVALID_ARGUMENT", "title required");

    // Save notice to Firestore
    const noticeRef = await db.collection("notices").add({
      title,
      description,
      type,
      posted_by: postedBy,
      date: new Date().toISOString().slice(0, 10),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[postNoticeHttp] Created notice ${noticeRef.id} "${title}"`);

    // Notify all residents (non-fatal)
    try {
      const tokens = await getAllResidentFcmTokens(db);
      await sendFcmMulticast(
        tokens,
        `📢 ${title}`,
        description.slice(0, 120) || type,
        { type: "NOTICE", noticeId: noticeRef.id }
      );
    } catch (fcmErr) {
      console.error("[postNoticeHttp] FCM error (non-fatal):", fcmErr.message);
    }

    res.status(200).json({ ok: true, noticeId: noticeRef.id });
  } catch (error) {
    if (error instanceof HttpsError)
      return res.status(error.httpErrorCode.status).json({ error: { status: error.code.toUpperCase().replace(/-/g, "_"), message: error.message } });
    console.error("postNoticeHttp error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: "Internal error" } });
  }
});

/**
 * UPDATE COMPLAINT STATUS
 * POST /updateComplaintStatusHttp
 * Body: { complaintId, status, adminFeedback? }
 *
 * Updates the complaint document and sends FCM to the resident who filed it.
 */
exports.updateComplaintStatusHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") return httpError(res, 405, "METHOD_NOT_ALLOWED", "POST only");

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body   = typeof req.body === "object" && req.body ? req.body : {};
    const token  = bearer.startsWith("Bearer ") ? bearer.slice(7) : String(body.authToken || "");

    const authContext = await resolveAuthContext({ auth: null, data: { authToken: token } });
    await requireAdminFromAuthContext(db, authContext);

    const complaintId   = String(body.complaintId   || "").trim();
    const newStatus     = String(body.status        || "").trim();
    const adminFeedback = String(body.adminFeedback || "").trim();

    if (!complaintId) return httpError(res, 400, "INVALID_ARGUMENT", "complaintId required");
    if (!newStatus)   return httpError(res, 400, "INVALID_ARGUMENT", "status required");

    const complaintRef = db.collection("complaints").doc(complaintId);
    const complaintSnap = await complaintRef.get();
    if (!complaintSnap.exists) return httpError(res, 404, "NOT_FOUND", "Complaint not found");

    const complaint = complaintSnap.data();
    const uid = String(complaint.uid || "");

    // Build update payload
    const updateData = {
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (newStatus === "Resolved") {
      updateData.adminFeedback = adminFeedback;
      updateData.resolvedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await complaintRef.update(updateData);
    console.log(`[updateComplaintStatusHttp] complaintId=${complaintId} → ${newStatus}`);

    // Notify the resident (non-fatal)
    try {
      if (uid) {
        const tokens = await getFcmTokensForUids(db, [uid]);
        const complaintTitle = String(complaint.title || "Your complaint");
        let notifBody = `Status updated to: ${newStatus}`;
        if (newStatus === "Resolved") {
          notifBody = `Your complaint "${complaintTitle}" has been resolved.`;
        } else if (newStatus === "In Progress") {
          notifBody = `Your complaint "${complaintTitle}" is now being looked into.`;
        }
        await sendFcmMulticast(tokens, "Complaint Update", notifBody, {
          type: "COMPLAINT_STATUS",
          complaintId,
          status: newStatus,
        });
      }
    } catch (fcmErr) {
      console.error("[updateComplaintStatusHttp] FCM error (non-fatal):", fcmErr.message);
    }

    res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof HttpsError)
      return res.status(error.httpErrorCode.status).json({ error: { status: error.code.toUpperCase().replace(/-/g, "_"), message: error.message } });
    console.error("updateComplaintStatusHttp error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: "Internal error" } });
  }
});

/**
 * CREATE RESIDENT
 * POST /createResidentHttp
 * Body: { name, email, phone, houseNo }
 *
 * Uses Admin SDK to create a Firebase Auth user, then creates the Firestore
 * users document with the Auth UID as the document ID.
 * Sends a welcome email with login credentials to the new resident.
 */
exports.createResidentHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") return httpError(res, 405, "METHOD_NOT_ALLOWED", "POST only");

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : String(body.authToken || "");

    const authContext = await resolveAuthContext({ auth: null, data: { authToken: token } });
    await requireAdminFromAuthContext(db, authContext);

    const name    = String(body.name    || "").trim();
    const email   = String(body.email   || "").trim().toLowerCase();
    const phone   = String(body.phone   || "").trim();
    const houseNo = String(body.houseNo || "").trim();

    if (!name)    return httpError(res, 400, "INVALID_ARGUMENT", "name required");
    if (!email)   return httpError(res, 400, "INVALID_ARGUMENT", "email required");
    if (!houseNo) return httpError(res, 400, "INVALID_ARGUMENT", "houseNo required");

    // Generate a human-readable temporary password e.g. "HomeA101@3847"
    const houseSlug   = houseNo.replace(/[^a-zA-Z0-9]/g, "").substring(0, 6);
    const randomDigits = Math.floor(1000 + Math.random() * 9000); // 4-digit
    const tempPassword = `Home${houseSlug}@${randomDigits}`;

    // Guard: check Firestore for existing email
    const existing = await db.collection("users").where("email", "==", email).limit(1).get();
    if (!existing.empty) return httpError(res, 400, "ALREADY_EXISTS", "A resident with this email already exists");

    // Step 1: Create Firebase Auth user
    const authUser = await admin.auth().createUser({
      email,
      password: tempPassword,
      displayName: name,
    });

    // Step 2: Create Firestore document using Auth UID as doc ID
    await db.collection("users").doc(authUser.uid).set({
      name,
      email,
      phone,
      house_no: houseNo,
      floor: "",
      dues: 0,
      role: "user",
      qr_payload: houseNo,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      last_due_update: "",
      last_payment_date: "",
    });

    // Step 3: Send welcome email with credentials (non-fatal if it fails)
    let emailSent = false;
    try {
      await sendWelcomeEmail({ toEmail: email, toName: name, houseNo, tempPassword });
      emailSent = true;
      console.log(`[createResidentHttp] Welcome email sent to ${email}`);
    } catch (mailErr) {
      console.error("[createResidentHttp] Failed to send welcome email:", mailErr.message);
    }

    console.log(`[createResidentHttp] Created resident uid=${authUser.uid} email=${email} house=${houseNo} emailSent=${emailSent}`);
    res.status(200).json({ ok: true, uid: authUser.uid, email, name, houseNo, tempPassword, emailSent });

  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      return httpError(res, 400, "ALREADY_EXISTS", "This email is already registered. Use a different email.");
    }
    if (error instanceof HttpsError)
      return res.status(error.httpErrorCode.status).json({ error: { status: error.code.toUpperCase().replace(/-/g, "_"), message: error.message } });
    console.error("createResidentHttp error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: error.message || "Internal error" } });
  }
});

/**
 * DELETE RESIDENT
 * POST /deleteResidentHttp
 * Body: { userId }
 *
 * Deletes the Firebase Auth user and Firestore document.
 */
exports.deleteResidentHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") return httpError(res, 405, "METHOD_NOT_ALLOWED", "POST only");

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : String(body.authToken || "");

    const authContext = await resolveAuthContext({ auth: null, data: { authToken: token } });
    await requireAdminFromAuthContext(db, authContext);

    const userId = String(body.userId || "").trim();
    if (!userId) return httpError(res, 400, "INVALID_ARGUMENT", "userId required");

    // Step 1: Delete Firebase Auth account (ignore if already gone)
    try {
      await admin.auth().deleteUser(userId);
    } catch (authErr) {
      if (authErr.code !== "auth/user-not-found") throw authErr;
      console.warn(`[deleteResidentHttp] Auth user ${userId} not found — deleting Firestore doc only`);
    }

    // Step 2: Delete Firestore document
    await db.collection("users").doc(userId).delete();

    console.log(`[deleteResidentHttp] Deleted resident uid=${userId}`);
    res.status(200).json({ ok: true });

  } catch (error) {
    if (error instanceof HttpsError)
      return res.status(error.httpErrorCode.status).json({ error: { status: error.code.toUpperCase().replace(/-/g, "_"), message: error.message } });
    console.error("deleteResidentHttp error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: error.message || "Internal error" } });
  }
});

/**
 * CLOSE DEMAND DUE
 * POST /closeDemandDueHttp
 * Body: { demandId }
 */
exports.closeDemandDueHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") return httpError(res, 405, "METHOD_NOT_ALLOWED", "POST only");

  try {
    const db = admin.firestore();
    const bearer = String(req.headers.authorization || "");
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : String(body.authToken || "");

    const authContext = await resolveAuthContext({ auth: null, data: { authToken: token } });
    await requireAdminFromAuthContext(db, authContext);

    const demandId = String(body.demandId || "");
    if (!demandId) return httpError(res, 400, "INVALID_ARGUMENT", "demandId required");

    await db.collection("demand_dues").doc(demandId).update({
      status: "CLOSED",
      closed_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[closeDemandDueHttp] Closed demand due ${demandId}`);
    res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof HttpsError)
      return res.status(error.httpErrorCode.status).json({ error: { status: error.code.toUpperCase().replace(/-/g,"_"), message: error.message } });
    console.error("closeDemandDueHttp error", error);
    res.status(500).json({ error: { status: "INTERNAL", message: "Internal error" } });
  }
});
