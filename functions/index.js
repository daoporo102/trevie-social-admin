/**
 * Region: asia-southeast1 (Singapore)
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Initialize Admin SDK
admin.initializeApp();

// Set global options for all functions
setGlobalOptions({region: "asia-southeast1", maxInstances: 10});

/**
 * 1. Set Admin Claim
 */
exports.setAdminClaim = onCall(async (request) => {
  // Extract data and auth from the request
  const {data, auth} = request;

  // Check if the user is authenticated
  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }

  // Check if the user has admin or superAdmin privileges
  if (!auth.token.admin && !auth.token.superAdmin) {
    throw new HttpsError("permission-denied", "Chỉ quản trị viên mới có thể tạo quản trị viên khác");
  }

  // Extract email from the data
  const {email} = data;

  // check if email is provided and valid
  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  }

  try {
    // Get user by email 
    const user = await admin.auth().getUserByEmail(email);
    // Set custom user claims to make the user an admin
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});
    console.log(`Admin claim set for user ${email} (UID: ${user.uid})`);
    // Return success response
    return {
      success: true,
      message: `Quyền quản trị viên đã được cấp cho ${email}`,
      uid: user.uid,
    };
  } catch (error) {
    // Handle errors
    console.error("Error setting admin claim:", error);
    throw new HttpsError("internal", `Không thể thiết lập quyền: ${error.message}`);
  }
});

/**
 * 2. Remove Admin Claim
 */
exports.removeAdminClaim = onCall(async (request) => {
  // Extract data and auth from the request
  const {data, auth} = request;

  // Check if the user is authenticated
  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }

  // Check if the user has superAdmin privileges
  if (!auth.token.superAdmin) {
    throw new HttpsError("permission-denied", "Chỉ super admin mới có thể xóa quyền quản trị viên");
  }

  // Extract email from the data
  const {email} = data;
  // check if email is provided and valid
  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  }

  try {
    // Get user by email
    const user = await admin.auth().getUserByEmail(email);
    // Remove admin claim
    await admin.auth().setCustomUserClaims(user.uid, {admin: false});
    console.log(`Admin claim removed for user ${email} (UID: ${user.uid})`);
    // Return success response
    return {
      success: true,
      message: `Đã xóa quyền quản trị viên của ${email}`,
      uid: user.uid,
    };
  } catch (error) {
    console.error("Error removing admin claim:", error);
    throw new HttpsError("internal", `Không thể xóa quyền: ${error.message}`);
  }
});

/**
 * 3. Check Admin Status
 */
exports.checkAdminStatus = onCall(async (request) => {
  // Extract data and auth from the request
  const {data, auth} = request;
  // Check if the user is authenticated
  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }
  // Extract email from the data
  const {email} = data;

  try {
    // Get user by email (or use auth email if not provided)
    const emailToCheck = email || auth.token.email;
    // Fetch user and their custom claims
    const user = await admin.auth().getUserByEmail(emailToCheck);
    // Get user record to access custom claims
    const userRecord = await admin.auth().getUser(user.uid);
    // Extract custom claims
    const customClaims = userRecord.customClaims || {};

    console.log(`Kiểm tra quyền cho: ${emailToCheck}`);
    console.log(`Claims hiện tại:`, JSON.stringify(customClaims));

    // Return admin status
    return {
      isAdmin: customClaims.admin === true,
      isSuperAdmin: customClaims.superAdmin === true,
      email: user.email,
    };
  } catch (error) {
    console.error("Error checking admin status:", error);
    throw new HttpsError("internal", `Không thể kiểm tra quyền: ${error.message}`);
  }
});

/**
 * 4. Set Super Admin Claim (Dùng Secret Key)
 */
exports.setSuperAdminClaim = onCall(async (request) => {
  // Extract data from the request
  const {data} = request;
  const {email, secretKey} = data;
  const expectedSecret = "my_default_secret_key";

  // Validate secret key
  if (secretKey !== expectedSecret) {
    throw new HttpsError("permission-denied", "Secret key không hợp lệ");
  }
  // Validate email
  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  }

  try {
    // Get user by email
    const user = await admin.auth().getUserByEmail(email);
    // Set super admin claim
    await admin.auth().setCustomUserClaims(user.uid, {
      admin: true,
      superAdmin: true,
    });
    console.log(`Super admin claim set for user ${email} (UID: ${user.uid})`);
    // Return success response
    return {
      success: true,
      message: `Đã cấp quyền super admin cho ${email}`,
      uid: user.uid,
    };
  } catch (error) {
    console.error("Error setting super admin claim:", error);
    throw new HttpsError("internal", `Không thể cấp quyền: ${error.message}`);
  }
});

/**
 * 5. Create User (Only Super Admin)
 */
exports.createUser = onCall(async (request) => {
  // Extract data and auth from the request
  const {data, auth} = request;
  // Check if the user is authenticated
  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }
  // Check if the user has superAdmin privileges
  if (!auth.token.superAdmin) {
    throw new HttpsError("permission-denied", "Chỉ super admin mới có thể tạo người dùng mới");
  }
  // Extract user details from the data
  const {email, password, displayName, bio, dateOfBirth, photoUrl} = data;
  // Validate input
  if (!email || typeof email !== "string") throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  if (!password || password.length < 6) throw new HttpsError("invalid-argument", "Mật khẩu phải có ít nhất 6 ký tự");
  if (!displayName) throw new HttpsError("invalid-argument", "Tên hiển thị không được để trống");
  if (!photoUrl) throw new HttpsError("invalid-argument", "Ảnh đại diện là bắt buộc");

  try {
    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
      photoURL: photoUrl,
    });
    // Prepare user document for Firestore
    const userDoc = {
      uid: userRecord.uid,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      bio: bio || "",
      dateOfBirth: dateOfBirth ? admin.firestore.Timestamp.fromDate(new Date(dateOfBirth)) : null,
      createdAt: admin.firestore.Timestamp.now(),
      followers: [],
      following: [],
      isSuspended: false,
      suspendedAt: null,
      isDeleted: false,
    };
    // Save user document to Firestore
    await admin.firestore()
        .collection("users")
        .doc(userRecord.uid)
        .set(userDoc);

    console.log(`User created: ${email} by super admin ${auth.token.email}`);
    // Return success response
    return {
      success: true,
      message: `Đã tạo người dùng thành công: ${email}`,
      uid: userRecord.uid,
      user: userDoc,
    };
  } catch (error) {
    console.error("Error creating user:", error);
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Email đã được sử dụng");
    }
    throw new HttpsError("internal", `Không thể tạo người dùng: ${error.message}`);
  }
});

/** * 6. Hard Delete User
 */
exports.deleteUserAuth = onCall(async (request) => {
  // Extract data and auth from the request
  const {data, auth} = request;
  // Check if the user is authenticated
  if (!auth || !auth.token.superAdmin) {
    throw new HttpsError("permission-denied", "Only super admin can delete users");
  }
  const {uid} = data;
  try {
    // Delete user from Firebase Auth
    await admin.auth().deleteUser(uid);
    return {success: true, message: "User deleted from Auth"};
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});
