const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Automatically adds ₹500 dues to all users on the 1st of each month.
 */
exports.addMonthlyDues = functions.pubsub
  .schedule("0 0 1 * *") // runs every 1st of month at midnight UTC
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    const db = admin.firestore();
    const usersRef = db.collection("users");
    const snapshot = await usersRef.get();

    const now = new Date();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const currentDue = data.dues || 0;
      const lastDueUpdate = data.last_due_update
        ? new Date(data.last_due_update)
        : null;

      // Add dues only if not already updated this month
      if (!lastDueUpdate || now.getMonth() !== lastDueUpdate.getMonth()) {
        await doc.ref.update({
          dues: currentDue + 500,
          maintenance_status: "Pending",
          last_due_update: now.toISOString(),
        });
        console.log(`✅ Updated dues for ${doc.id}`);
      } else {
        console.log(`⏭️ Already updated this month for ${doc.id}`);
      }
    }

    console.log("🎉 Monthly dues added successfully!");
    return null;
  });

