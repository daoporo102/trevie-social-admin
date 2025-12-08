// Load environment variables from .env file
require("dotenv").config();

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});


// Read from environment variable (this email must be in Firebase Auth), or default to a placeholder
const SUPER_ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@example.com";

if (SUPER_ADMIN_EMAIL === "admin@example.com") {
  console.error("Please set ADMIN_EMAIL environment variable in .env or edit the script.");
  process.exit(1);
}

async function setFirstSuperAdmin() {
  try {
    console.log(`Looking for user: ${SUPER_ADMIN_EMAIL}...`);

    const user = await admin.auth().getUserByEmail(SUPER_ADMIN_EMAIL);

    console.log(`User found! UID: ${user.uid}`);
    console.log(`Email: ${user.email}`);

    await admin.auth().setCustomUserClaims(user.uid, {
      admin: true,
      superAdmin: true,
    });

    console.log(`Super admin claims set successfully!`);
    console.log(`${SUPER_ADMIN_EMAIL} is now a Super Admin`);

    // Verify the claims were set
    const updatedUser = await admin.auth().getUser(user.uid);
    console.log(`Verified claims:`, updatedUser.customClaims);

    process.exit(0);
  } catch (error) {
    console.error("Error:", error.message);

    if (error.code === "auth/user-not-found") {
      console.error(`\n User with email "${SUPER_ADMIN_EMAIL}" does not exist!`);
      console.error("Please create this user first in Firebase Console or update the email.");
    }

    process.exit(1);
  }
}

setFirstSuperAdmin();
