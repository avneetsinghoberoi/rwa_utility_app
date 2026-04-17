const admin = require("firebase-admin");
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

    return { allocatedTotal, allocation, newDues };
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

    // ── Backfill month field on existing MAINTENANCE invoices (if missing) ──
    // (no-op for demand dues; just log)
    console.log(`[createDemandDueHttp] Created demand due "${title}" with ${targetDocs.length} invoices. demandId=${demandRef.id}`);

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

/**
 * CREATE RESIDENT
 * POST /createResidentHttp
 * Body: { name, email, phone, houseNo, password }
 *
 * Uses Admin SDK to create a Firebase Auth user, then creates the Firestore
 * users document with the Auth UID as the document ID.
 * This guarantees firestoreDocId == Auth UID, which is required for invoice queries.
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

    const name     = String(body.name     || "").trim();
    const email    = String(body.email    || "").trim().toLowerCase();
    const phone    = String(body.phone    || "").trim();
    const houseNo  = String(body.houseNo  || "").trim();
    const password = String(body.password || "").trim();

    if (!name)                        return httpError(res, 400, "INVALID_ARGUMENT", "name required");
    if (!email)                       return httpError(res, 400, "INVALID_ARGUMENT", "email required");
    if (!houseNo)                     return httpError(res, 400, "INVALID_ARGUMENT", "houseNo required");
    if (!password || password.length < 6)
      return httpError(res, 400, "INVALID_ARGUMENT", "password must be at least 6 characters");

    // Guard: check Firestore for existing email
    const existing = await db.collection("users").where("email", "==", email).limit(1).get();
    if (!existing.empty) return httpError(res, 400, "ALREADY_EXISTS", "A resident with this email already exists");

    // Step 1: Create Firebase Auth user
    const authUser = await admin.auth().createUser({
      email,
      password,
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

    console.log(`[createResidentHttp] Created resident uid=${authUser.uid} email=${email} house=${houseNo}`);
    res.status(200).json({ ok: true, uid: authUser.uid, email, name, houseNo });

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
