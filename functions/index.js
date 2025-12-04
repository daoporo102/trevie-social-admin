const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function to set admin custom claim
 * Only callable by existing admins or super admins
 */
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Check if the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Bạn phải đăng nhập để thực hiện hành động này",
    );
  }

  // Check if requester is an admin
  if (!context.auth.token.admin && !context.auth.token.superAdmin) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Chỉ quản trị viên mới có thể tạo quản trị viên khác",
    );
  }

  const {email} = data;

  // Validate email parameter
  if (!email || typeof email !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Địa chỉ email không hợp lệ",
    );
  }

  try {
    // Get user by email
    const user = await admin.auth().getUserByEmail(email);

    // Set custom claim 'admin' to true
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});

    // Log the action
    const logMessage = `Admin claim set for user ${email}`;
    console.log(`${logMessage} (UID: ${user.uid})`);

    return {
      success: true,
      message: `Quyền quản trị viên đã được cấp cho ${email}`,
      uid: user.uid,
    };
  } catch (error) {
    console.error("Error setting admin claim:", error);
    const errorMessage = `Không thể thiết lập quyền: ${error.message}`;
    throw new functions.https.HttpsError("internal", errorMessage);
  }
});

/**
 * Cloud Function to remove admin custom claim
 * Only callable by super admins
 */
exports.removeAdminClaim = functions.https.onCall(
    async (data, context) => {
      // Check if the user is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Bạn phải đăng nhập để thực hiện hành động này",
        );
      }

      // Only super admins can remove admin status
      if (!context.auth.token.superAdmin) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Chỉ super admin mới có thể xóa quyền quản trị viên",
        );
      }

      const {email} = data;

      // Validate email parameter
      if (!email || typeof email !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Địa chỉ email không hợp lệ",
        );
      }

      try {
        // Get user by email
        const user = await admin.auth().getUserByEmail(email);

        // Remove custom claim 'admin'
        await admin.auth().setCustomUserClaims(user.uid, {admin: false});

        // Log the action
        const logMessage = `Admin claim removed for user ${email}`;
        console.log(`${logMessage} (UID: ${user.uid})`);

        return {
          success: true,
          message: `Đã xóa quyền quản trị viên của ${email}`,
          uid: user.uid,
        };
      } catch (error) {
        console.error("Error removing admin claim:", error);
        const errorMessage = `Không thể xóa quyền: ${error.message}`;
        throw new functions.https.HttpsError("internal", errorMessage);
      }
    },
);

/**
 * Cloud Function to check if user is admin
 * Callable by any authenticated user
 */
exports.checkAdminStatus = functions.https.onCall(
    async (data, context) => {
      // Check if the user is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Bạn phải đăng nhập để thực hiện hành động này",
        );
      }

      const {email} = data;

      try {
        // Get user by email or from token
        const emailToCheck = email || context.auth.token.email;
        const user = await admin.auth().getUserByEmail(emailToCheck);
        // Get user record
        const userRecord = await admin.auth().getUser(user.uid);

        // Safely check custom claims
        const customClaims = userRecord.customClaims || {};

        return {
          isAdmin: customClaims.admin === true,
          isSuperAdmin: customClaims.superAdmin === true,
          email: user.email,
        };
      } catch (error) {
        console.error("Error checking admin status:", error);
        const errorMessage = `Không thể kiểm tra quyền: ${error.message}`;
        throw new functions.https.HttpsError("internal", errorMessage);
      }
    },
);

/**
 * Cloud Function to set super admin claim
 * Can only be called once manually with a secret key
 */
exports.setSuperAdminClaim = functions.https.onCall(
    async (data, context) => {
      const {email, secretKey} = data;

      // Get secret from Firebase config INSIDE the function
      let expectedSecret = "my_default_secret_key";
      try {
        const config = functions.config();
        if (config.superadmin && config.superadmin.secret) {
          expectedSecret = config.superadmin.secret;
        }
      } catch (configError) {
        console.warn("Could not load Firebase config, using default secret");
      }

      // Validate secret key
      if (secretKey !== expectedSecret) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Secret key không hợp lệ",
        );
      }

      // Validate email
      if (!email || typeof email !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Địa chỉ email không hợp lệ",
        );
      }

      try {
        // Get user by email
        const user = await admin.auth().getUserByEmail(email);

        // Set custom claim 'superAdmin' to true
        await admin.auth().setCustomUserClaims(user.uid, {
          admin: true,
          superAdmin: true,
        });

        const logMessage = `Super admin claim set for user ${email}`;
        console.log(`${logMessage} (UID: ${user.uid})`);

        return {
          success: true,
          message: `Đã cấp quyền super admin cho ${email}`,
          uid: user.uid,
        };
      } catch (error) {
        console.error("Error setting super admin claim:", error);
        const errorMessage = `Không thể cấp quyền: ${error.message}`;
        throw new functions.https.HttpsError("internal", errorMessage);
      }
    },
);
