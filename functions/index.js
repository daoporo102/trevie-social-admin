/**
 * index.js - Viết lại chuẩn Cloud Functions v2
 * Region: asia-southeast1 (Singapore)
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Khởi tạo Admin SDK
admin.initializeApp();

// CẤU HÌNH CHUNG: Ép toàn bộ functions chạy ở Singapore
setGlobalOptions({region: "asia-southeast1", maxInstances: 10});

/**
 * 1. Set Admin Claim
 */
exports.setAdminClaim = onCall(async (request) => {
  // Trong v2: data và auth nằm trong biến 'request'
  const {data, auth} = request;

  // Check đăng nhập
  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }

  // Check quyền (Admin hoặc SuperAdmin mới được tạo Admin khác)
  if (!auth.token.admin && !auth.token.superAdmin) {
    throw new HttpsError("permission-denied", "Chỉ quản trị viên mới có thể tạo quản trị viên khác");
  }

  const {email} = data;

  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  }

  try {
    const user = await admin.auth().getUserByEmail(email);

    // Set admin: true
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});

    console.log(`Admin claim set for user ${email} (UID: ${user.uid})`);

    return {
      success: true,
      message: `Quyền quản trị viên đã được cấp cho ${email}`,
      uid: user.uid,
    };
  } catch (error) {
    console.error("Error setting admin claim:", error);
    throw new HttpsError("internal", `Không thể thiết lập quyền: ${error.message}`);
  }
});

/**
 * 2. Remove Admin Claim
 */
exports.removeAdminClaim = onCall(async (request) => {
  const {data, auth} = request;

  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }

  // Chỉ Super Admin mới được xóa quyền
  if (!auth.token.superAdmin) {
    throw new HttpsError("permission-denied", "Chỉ super admin mới có thể xóa quyền quản trị viên");
  }

  const {email} = data;

  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  }

  try {
    const user = await admin.auth().getUserByEmail(email);

    // Set admin: false (xóa quyền)
    await admin.auth().setCustomUserClaims(user.uid, {admin: false});

    console.log(`Admin claim removed for user ${email} (UID: ${user.uid})`);

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
  const {data, auth} = request;

  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }

  const {email} = data;

  try {
    // Nếu không gửi email lên thì lấy email của người đang gọi
    const emailToCheck = email || auth.token.email;

    const user = await admin.auth().getUserByEmail(emailToCheck);
    const userRecord = await admin.auth().getUser(user.uid);
    const customClaims = userRecord.customClaims || {};

    console.log(`Kiểm tra quyền cho: ${emailToCheck}`);
    console.log(`Claims hiện tại:`, JSON.stringify(customClaims));

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
  const {data} = request; // Không bắt buộc auth vì dùng secret key
  const {email, secretKey} = data;

  // Secret key mặc định (Bạn nên đổi cái này hoặc dùng .env)
  const expectedSecret = "my_default_secret_key";

  if (secretKey !== expectedSecret) {
    throw new HttpsError("permission-denied", "Secret key không hợp lệ");
  }

  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  }

  try {
    const user = await admin.auth().getUserByEmail(email);

    // Cấp cả Admin và SuperAdmin
    await admin.auth().setCustomUserClaims(user.uid, {
      admin: true,
      superAdmin: true,
    });

    console.log(`Super admin claim set for user ${email} (UID: ${user.uid})`);

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
  const {data, auth} = request;

  if (!auth) {
    throw new HttpsError("permission-denied", "Bạn phải đăng nhập để thực hiện hành động này");
  }

  // Chỉ Super Admin mới được tạo user
  if (!auth.token.superAdmin) {
    throw new HttpsError("permission-denied", "Chỉ super admin mới có thể tạo người dùng mới");
  }

  const {email, password, displayName, bio, dateOfBirth, photoUrl} = data;

  // Validation
  if (!email || typeof email !== "string") throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ");
  if (!password || password.length < 6) throw new HttpsError("invalid-argument", "Mật khẩu phải có ít nhất 6 ký tự");
  if (!displayName) throw new HttpsError("invalid-argument", "Tên hiển thị không được để trống");
  if (!photoUrl) throw new HttpsError("invalid-argument", "Ảnh đại diện là bắt buộc");

  try {
    // Tạo user bên Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
      photoURL: photoUrl,
    });

    // Tạo user bên Firestore
    const userDoc = {
      uid: userRecord.uid,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      bio: bio || "",
      // Chuyển đổi ngày tháng
      dateOfBirth: dateOfBirth ? admin.firestore.Timestamp.fromDate(new Date(dateOfBirth)) : null,
      createdAt: admin.firestore.Timestamp.now(),
      followers: [],
      following: [],
      isSuspended: false,
      suspendedAt: null,
      isDeleted: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(userRecord.uid)
        .set(userDoc);

    console.log(`User created: ${email} by super admin ${auth.token.email}`);

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
