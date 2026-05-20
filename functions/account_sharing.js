/**
 * Cloud Functions for Account Sharing
 * Handles adding/removing flat members, sending emails, managing access
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Firebase Admin SDK is initialized in index.js
// Get references without reinitializing
const getDb = () => admin.firestore();
const getAuth = () => admin.auth();

// ============================================================================
// ADD FLAT MEMBER FUNCTION
// ============================================================================

/**
 * When a resident requests to add a new user to their flat account:
 * 1. Create new user in Firebase Auth
 * 2. Create user document in Firestore
 * 3. Link to primary owner's account
 * 4. Update all flat members' flat_members arrays
 * 5. Send setup email to new user
 */
exports.onAddFlatMemberRequest = onDocumentCreated('_requests/{requestId}', async (event) => {
    const request = event.data.data();
    const requestId = event.params.requestId;

    // Only process add_flat_member requests
    if (request.type !== 'add_flat_member') {
      return;
    }

    const {
      requester_uid,
      email,
      name,
      relationship,
      flat_no,
      wing,
      building,
      primary_owner_uid,
    } = request;

    try {
      console.log(`🔄 Processing add flat member request: ${email}`);

      // Step 1: Verify requester is account owner
      const requesterDoc = await getDb().collection('users').doc(requester_uid).get();
      if (!requesterDoc.exists) {
        throw new Error('Requester not found');
      }

      const requesterData = requesterDoc.data();
      // BUG FIX: admin-created residents have no 'account_link' field at all.
      // Use optional chaining so accessing .primary_owner_uid doesn't throw.
      // A user is the owner if primary_owner_uid is null/undefined (no one above them).
      const accountLink = requesterData.account_link || {};
      const isOwner = !accountLink.primary_owner_uid;
      const isAdmin = requesterData.role === 'admin';

      if (!isOwner) {
        throw new Error('Only account owner can add members');
      }

      // Only admins can add new residents to the society
      if (relationship === 'resident' && !isAdmin) {
        throw new Error('Only admins can add residents. Residents can only add tenants, spouses, or family.');
      }

      // Step 2: Check if email already exists in Auth
      let newUserUid;
      let tempPassword = generateTempPassword(); // Always generate a fresh password
      try {
        const existingUser = await getAuth().getUserByEmail(email);
        newUserUid = existingUser.uid;
        // Reset their password so the new temp password works (they may have
        // been removed and re-added, or forgotten their old credentials).
        await getAuth().updateUser(newUserUid, {
          password: tempPassword,
          displayName: name,
        });
        console.log(`ℹ️ Existing user re-added, password reset: ${newUserUid}`);
      } catch (error) {
        // User doesn't exist in Auth — create them fresh
        if (error.code === 'auth/user-not-found') {
          const newUser = await getAuth().createUser({
            email: email,
            password: tempPassword,
            displayName: name,
          });
          newUserUid = newUser.uid;
          console.log(`✅ Created new user: ${newUserUid}`);
        } else {
          throw error;
        }
      }

      // Step 3: Create/update user document in Firestore
      const currentFlatMembers = requesterData.flat_members || [requester_uid];

      // Add new user to flat_members if not already there
      const updatedFlatMembers = [
        ...new Set([...currentFlatMembers, newUserUid]),
      ];

      // Resolve the owner's actual house_no so the tenant can query
      // invoices/payments that are stored with that house_no.
      // Admin-created owners store it top-level; account-sharing owners in unit_info.
      const ownerHouseNo = requesterData.house_no ||
        (requesterData.unit_info && requesterData.unit_info.flat_no) ||
        (requesterData.unit_info && requesterData.unit_info.house_no) ||
        flat_no || '';

      // Create user document for new member
      const newUserData = {
        name: name,
        email: email,
        phone: '', // Empty initially, user can update
        profile_photo: '', // Empty initially
        role: 'resident', // Same role as owner
        house_no: ownerHouseNo, // Top-level — required for invoice/payment queries
        unit_info: {
          house_no: ownerHouseNo,
          flat_no: flat_no,
          wing: wing,
          building: building,
        },
        account_link: {
          primary_owner_uid: primary_owner_uid || requester_uid,
          linked_as: relationship, // 'spouse', 'tenant', 'roommate', etc.
          linked_on: admin.firestore.FieldValue.serverTimestamp(),
          linked_by: requester_uid,
        },
        flat_members: updatedFlatMembers,
        status: 'active',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Write new user document
      await getDb().collection('users').doc(newUserUid).set(newUserData, { merge: true });
      console.log(`✅ Created user document: ${newUserUid}`);

      // Step 4: Update all existing flat members' flat_members arrays
      const batch = getDb().batch();

      for (const memberId of updatedFlatMembers) {
        if (memberId !== newUserUid) {
          // Don't update the new user again
          try {
            const memberDoc = await getDb().collection('users').doc(memberId).get();
            if (memberDoc.exists) {
              const memberData = memberDoc.data();
              // Validate existing flat_members is a simple array
              let existingMembers = memberData.flat_members || [];
              if (Array.isArray(existingMembers)) {
                // Ensure all elements are strings (not nested arrays)
                existingMembers = existingMembers.filter(item => typeof item === 'string');
              } else {
                existingMembers = [];
              }

              // Add new user if not already present
              if (!existingMembers.includes(newUserUid)) {
                existingMembers.push(newUserUid);
              }

              batch.update(getDb().collection('users').doc(memberId), {
                flat_members: existingMembers,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          } catch (err) {
            console.warn(`⚠️ Warning updating member ${memberId}: ${err.message}`);
          }
        }
      }

      await batch.commit();
      console.log(`✅ Updated flat_members array for all users`);

      // Step 5: Send setup email
      await sendSetupEmail(email, name, flat_no, wing, tempPassword);
      console.log(`✅ Sent setup email to ${email}`);

      // Step 6: Mark request as processed
      const requestRef = getDb().collection('_requests').doc(requestId);
      await requestRef.update({
        status: 'completed',
        processed_at: admin.firestore.FieldValue.serverTimestamp(),
        new_user_uid: newUserUid,
      });

      console.log(`✅ Completed add flat member request`);
    } catch (error) {
      console.error(`❌ Error processing add flat member request:`, error);

      // Mark request as failed
      try {
        const requestRef = getDb().collection('_requests').doc(requestId);
        await requestRef.update({
          status: 'failed',
          error_message: error.message,
          failed_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        console.error('Could not update request status:', updateError);
      }

      // Send error notification (optional)
      // await notifyErrorToOwner(requester_uid, error.message);
    }
  });

// ============================================================================
// REMOVE FLAT MEMBER FUNCTION
// ============================================================================

/**
 * When a resident requests to remove a user from their flat account:
 * 1. Mark user as removed
 * 2. Update all flat members' flat_members arrays
 * 3. Send notification email
 */
exports.onRemoveFlatMemberRequest = onDocumentCreated('_requests/{requestId}', async (event) => {
    const request = event.data.data();
    const requestId = event.params.requestId;

    // Only process remove_flat_member requests
    if (request.type !== 'remove_flat_member') {
      return;
    }

    const { requester_uid, member_uid_to_remove } = request;

    try {
      console.log(
        `🔄 Processing remove flat member request: ${member_uid_to_remove}`
      );

      // Step 1: Verify requester is account owner
      const requesterDoc = await getDb().collection('users').doc(requester_uid).get();
      if (!requesterDoc.exists) {
        throw new Error('Requester not found');
      }

      const requesterData = requesterDoc.data();
      // BUG FIX: admin-created residents have no 'account_link' field.
      const accountLink = requesterData.account_link || {};
      const isOwner = !accountLink.primary_owner_uid;

      if (!isOwner) {
        throw new Error('Only account owner can remove members');
      }

      // Step 2: Cannot remove self
      if (member_uid_to_remove === requester_uid) {
        throw new Error('Cannot remove yourself');
      }

      // Step 3: Get member to remove data
      const memberToRemoveDoc = await getDb()
        .collection('users')
        .doc(member_uid_to_remove)
        .get();

      if (!memberToRemoveDoc.exists) {
        throw new Error('Member not found');
      }

      const memberToRemoveData = memberToRemoveDoc.data();
      const memberEmail = memberToRemoveData.email;

      // Step 4: Disable the Firebase Auth account so the user can no longer
      // sign in even with the correct password, then mark as removed in Firestore.
      try {
        await getAuth().updateUser(member_uid_to_remove, { disabled: true });
        console.log(`✅ Disabled Firebase Auth account: ${member_uid_to_remove}`);
      } catch (authError) {
        // Non-fatal — user may have already been deleted; continue with Firestore update.
        console.warn(`⚠️ Could not disable Auth account: ${authError.message}`);
      }

      await getDb().collection('users').doc(member_uid_to_remove).update({
        status: 'removed',
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Marked user as removed: ${member_uid_to_remove}`);

      // Step 5: Update all flat members to remove this user
      const batch = getDb().batch();

      for (const memberId of requesterData.flat_members) {
        if (memberId !== member_uid_to_remove) {
          batch.update(getDb().collection('users').doc(memberId), {
            flat_members: admin.firestore.FieldValue.arrayRemove([
              member_uid_to_remove,
            ]),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      console.log(`✅ Updated flat_members arrays`);

      // Step 6: Send notification email to removed member
      await sendRemovalEmail(memberEmail, memberToRemoveData.name);
      console.log(`✅ Sent removal notification email`);

      // Step 7: Mark request as processed
      const requestRef = getDb().collection('_requests').doc(requestId);
      await requestRef.update({
        status: 'completed',
        processed_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Completed remove flat member request`);
    } catch (error) {
      console.error(`❌ Error processing remove flat member request:`, error);

      // Mark request as failed
      try {
        const requestRef = getDb().collection('_requests').doc(requestId);
        await requestRef.update({
          status: 'failed',
          error_message: error.message,
          failed_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        console.error('Could not update request status:', updateError);
      }
    }
  });

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Generate a secure temporary password
 */
function generateTempPassword() {
  const chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%';
  let password = '';
  for (let i = 0; i < 12; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return password;
}

/**
 * Send setup email to new flat member
 * @param {string} email - Recipient email
 * @param {string} name - Recipient name
 * @param {string} flatNo - Flat number
 * @param {string} wing - Wing/block identifier
 * @param {string|null} tempPassword - Temporary password if a new account was created, null if account already existed
 */
async function sendSetupEmail(email, name, flatNo, wing, tempPassword) {
  try {
    // Configure your email service here
    // Using Gmail SMTP - requires App Password for Gmail
    const gmailEmail = process.env.EMAIL_USER;
    const gmailPassword = process.env.EMAIL_PASS; // Must match the variable name used in index.js

    if (!gmailEmail || !gmailPassword) {
      throw new Error('Email credentials not configured. Set EMAIL_USER and EMAIL_PASS environment variables.');
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailEmail,
        pass: gmailPassword,
      },
    });

    // Build the credentials section based on whether a new account was created
    const credentialsSection = tempPassword
      ? `<p><strong>Your login credentials:</strong></p>
         <ul>
           <li><strong>Email:</strong> ${email}</li>
           <li><strong>Temporary Password:</strong> <code style="background:#f4f4f4;padding:4px 8px;border-radius:4px;">${tempPassword}</code></li>
         </ul>
         <p style="color:#e65100;">⚠️ Please change your password after your first login.</p>`
      : `<p>Your account already exists. Please use your existing password to log in with <strong>${email}</strong>.</p>`;

    const mailOptions = {
      from: gmailEmail,
      to: email,
      subject: 'Your GateBasic Account is Ready',
      html: `
        <h2>Welcome to GateBasic!</h2>
        <p>Hello ${name},</p>
        <p>You've been added to the account for <strong>Flat ${wing}/${flatNo}</strong>.</p>

        ${credentialsSection}

        <p>Once logged in, you can:</p>
        <ul>
          <li>💳 Pay maintenance bills</li>
          <li>🔧 Report issues</li>
          <li>📢 View notices</li>
          <li>📊 See expense reports</li>
        </ul>

        <p>Welcome aboard!</p>
        <p><strong>GateBasic Team</strong></p>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Setup email sent to ${email}`);
  } catch (error) {
    console.error(`❌ Failed to send setup email to ${email}:`, error);
    // Don't throw - email failure shouldn't fail the whole operation
  }
}

/**
 * Send removal email to removed member
 */
async function sendRemovalEmail(email, name) {
  try {
    // Configure your email service here
    const gmailEmail = process.env.EMAIL_USER;
    const gmailPassword = process.env.EMAIL_PASS; // Must match the variable name used in index.js

    if (!gmailEmail || !gmailPassword) {
      throw new Error('Email credentials not configured. Set EMAIL_USER and EMAIL_PASS environment variables.');
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailEmail,
        pass: gmailPassword,
      },
    });

    const mailOptions = {
      from: gmailEmail,
      to: email,
      subject: 'GateBasic Account Access Removed',
      html: `
        <h2>Account Access Updated</h2>
        <p>Hello ${name},</p>
        <p>Your access to the flat account has been removed.</p>

        <p>If you have any questions, please contact the flat owner.</p>

        <p><strong>GateBasic Team</strong></p>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Removal email sent to ${email}`);
  } catch (error) {
    console.error(`❌ Failed to send removal email to ${email}:`, error);
    // Don't throw - email failure shouldn't fail the whole operation
  }
}

// ============================================================================
// HTTP FUNCTION TO MANUALLY TRIGGER MIGRATIONS (Optional)
// ============================================================================

/**
 * Optional: HTTP endpoint to run migration
 * Access: https://region-projectid.cloudfunctions.net/runMigration?token=SECRET_TOKEN
 */
exports.runMigration = onRequest(
  { cors: true },
  async (request, response) => {
    // Add security check
    const token = request.query.token || (request.body && request.body.token);
    const expectedToken = process.env.MIGRATION_TOKEN || 'migration-secret-key';

    if (token !== expectedToken) {
      return response.status(403).json({ error: 'Unauthorized' });
    }

    try {
      const usersSnapshot = await getDb().collection('users').get();
      let migratedCount = 0;

      const batch = getDb().batch();

      usersSnapshot.forEach((doc) => {
        if (!doc.data().account_link) {
          batch.update(doc.ref, {
            account_link: {
              primary_owner_uid: null,
              linked_as: 'owner',
              linked_on: admin.firestore.FieldValue.serverTimestamp(),
              linked_by: 'system_migration',
            },
            flat_members: [doc.id],
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          migratedCount++;
        }
      });

      await batch.commit();

      response.json({
        success: true,
        migratedCount,
        message: `Migrated ${migratedCount} users to account sharing`,
      });
    } catch (error) {
      console.error('Migration error:', error);
      response.status(500).json({ error: error.message });
    }
  }
);
