/**
 * Migration: Add account sharing support to existing users
 *
 * This script:
 * 1. Adds 'account_link' field to all existing users
 * 2. Adds 'flat_members' array to all existing users
 * 3. Each user becomes the primary owner of their own flat
 *
 * Run this ONCE before deploying account sharing feature
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function migrateToAccountSharing() {
  console.log('🔄 Starting migration to account sharing...');

  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} users to migrate`);

    let migratedCount = 0;
    let errorCount = 0;
    const batch = db.batch();

    // Process each user
    usersSnapshot.forEach((doc) => {
      const userId = doc.id;
      const userData = doc.data();

      // Skip if already migrated
      if (userData.account_link) {
        console.log(`⏭️  Skipping ${userId} (already migrated)`);
        return;
      }

      try {
        // Add account_link
        const updateData = {
          account_link: {
            primary_owner_uid: null, // This user is the owner
            linked_as: 'owner',
            linked_on: admin.firestore.FieldValue.serverTimestamp(),
            linked_by: 'system_migration',
          },
          flat_members: [userId], // Only themselves initially
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        };

        batch.update(doc.ref, updateData);
        migratedCount++;
        console.log(`✅ Queued migration for ${userId}`);
      } catch (error) {
        errorCount++;
        console.error(`❌ Error processing ${userId}:`, error.message);
      }
    });

    // Commit batch
    if (migratedCount > 0) {
      await batch.commit();
      console.log(`✅ Migration complete: ${migratedCount} users updated`);
    } else {
      console.log('⚠️  No users to migrate');
    }

    if (errorCount > 0) {
      console.log(`⚠️  ${errorCount} errors occurred`);
    }

    return {
      success: true,
      migratedCount,
      errorCount,
      totalProcessed: migratedCount + errorCount,
    };
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

// Run migration
migrateToAccountSharing()
  .then((result) => {
    console.log('\n📋 Migration Summary:');
    console.log(`   Total users: ${result.totalProcessed}`);
    console.log(`   Migrated: ${result.migratedCount}`);
    console.log(`   Errors: ${result.errorCount}`);
    process.exit(result.errorCount === 0 ? 0 : 1);
  })
  .catch((error) => {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  });
