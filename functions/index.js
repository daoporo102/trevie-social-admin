/*
 * Region: asia-southeast1 (Singapore)
 * to run:
 *    step 1: npm run lint -- --fix
 *    step 2: firebase deploy --only functions
 *    see log: firebase functions:log
 */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const axios = require("axios");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const vision = require("@google-cloud/vision");

// AI Server URL
const AI_SERVER_URL = "https://peripherally-subovoid-doug.ngrok-free.dev/predict";

// Initialize Admin SDK
admin.initializeApp();

// Set global options for all functions
setGlobalOptions({region: "asia-southeast1", maxInstances: 10});

// Initialize Google Vision Client
const visionClient = new vision.ImageAnnotatorClient();

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


/**
 * 7. AI Post's Text Check
 */
// exports.checkPostText = onDocumentCreated("posts/{postId}", async (event) => {
//   const snapshot = event.data;
//   const postId = event.params.postId;

//   // if no snapshot, exit
//   if (!snapshot) {
//     return;
//   }

//   // get post data
//   const postData = snapshot.data();
//   // get post text
//   const text = postData.postText || "";

//   // Check if post is a reshare or original post
//   const postType = postData.originalPostId ? "RESHARE" : "POST";

//   // if no text, set status to active
//   if (!text) {
//     return snapshot.ref.update({status: "active"});
//   }

//   // start time
//   const startTime = Date.now();
//   console.log(`[START] [${postType}] Bắt đầu gửi bài ${postId} tới AI...`);

//   try {
//     console.log(`Đang gửi bài ${postId} tới AI Server...`);
//     // call AI server with timeout of 10 seconds
//     const response = await axios.post(AI_SERVER_URL, {
//       text: text,
//     }, {timeout: 10000});

//     // end time
//     const endTime = Date.now();
//     // Calculate execution time
//     const executionTime = endTime - startTime;

//     // Print the log (You will see this in the Console). measured in milliseconds
//     console.log(`[PERFORMANCE] AI phản hồi trong: ${executionTime}ms`);

//     // get AI result
//     const aiResult = response.data;
//     // process AI result
//     if (aiResult.is_toxic === true) {
//       // if toxic, set status to rejected with reason
//       await snapshot.ref.update({
//         status: "rejected",
//         aiReason: aiResult.reason,
//         moderatedBy: "AI",
//         moderatedAt: admin.firestore.Timestamp.now(),
//       });
//       console.log(`AI chặn bài ${postId} vì: ${aiResult.reason} (mất ${executionTime}ms)`);
//     } else {
//       // if not toxic, set status to active
//       await snapshot.ref.update({
//         status: "active",
//         aiReason: null,
//         moderatedBy: "AI",
//         moderatedAt: admin.firestore.Timestamp.now(),
//       });
//       console.log(`AI duyệt sạch (mất ${executionTime}ms)`);
//     }
//   } catch (error) {
//     // Measure the time even if there is an error (to know how long it takes to die)
//     // for example, if it takes exactly 10000ms, it's due to a timeout).
//     const errorTime = Date.now() - startTime;
//     console.error(`[ERROR] Lỗi gọi AI Server sau ${errorTime}ms:`, error.message);

//     // On error, Auto-Approve the post to avoid pending content for users
//     await snapshot.ref.update({
//       status: "active",
//       moderatedBy: "system_failover",
//       aiReason: "Dich vụ AI lỗi -> tự động duyệt",
//       moderatedAt: admin.firestore.Timestamp.now(),
//     });
//     console.log(` Đã Auto-Approve bài viết do lỗi.`);
//   }
// });

/**
 * 8. Check Post Update (when user updates post text)
 */
// exports.checkPostUpdate = onDocumentUpdated("posts/{postId}", async (event) => {
//   // Get data before and after the update
//   const beforeDoc = event.data.before;
//   const afterDoc = event.data.after;
//   const postId = event.params.postId;

//   // get data (json contains content)
//   const beforeData = beforeDoc.data();
//   const afterData = afterDoc.data();

//   // Get new text
//   const newText = afterData.postText || "";
//   const oldText = beforeData.postText || "";

//   // If text hasn't changed, exit
//   if (newText === oldText) {
//     console.log(`Bài ${postId} cập nhật nhưng không thay đổi nội dung văn bản. Bỏ qua kiểm tra AI.`);
//     return;
//   }

//   // If previous update was failed due to AI rollback, skip check to avoid loop
//   if (afterData.status === "active"
// && afterData.updateStatus === "failed"
// && afterData.moderatedBy === "AI_Rollback") {
//     console.log(`Bỏ qua check vì đây là thao tác Rollback của hệ thống.`);
//     return;
//   }

//   // If text changed, proceed to check with AI
//   console.log(`[UPDATE] Bài ${postId} đã thay đổi nội dung văn bản. Gửi lại tới AI để kiểm tra...`);

//   if (!newText) {
//     return afterDoc.ref.update({status: "active"});
//   }

//   // start time
//   const startTime = Date.now();
//   console.log(`[START] Bắt đầu gửi bài ${postId} tới AI...`);

//   try {
//     console.log(`Đang gửi bài ${postId} tới AI Server...`);
//     // call AI server with timeout of 10 seconds
//     const response = await axios.post(AI_SERVER_URL, {
//       text: newText,
//     }, {timeout: 10000});

//     // end time
//     const endTime = Date.now();
//     // Calculate execution time
//     const executionTime = endTime - startTime;

//     // Print the log (You will see this in the Console). measured in milliseconds
//     console.log(`[PERFORMANCE] AI phản hồi trong: ${executionTime}ms`);

//     // get AI result
//     const aiResult = response.data;
//     // process AI result
//     if (aiResult.is_toxic === true) {
//       // if toxic, rollback to old text and set status to active
//       console.log(`AI phát hiện nội dung độc hại khi Update: ${aiResult.reason}`);

//       await afterDoc.ref.update({
//         postText: oldText,
//         status: "active",
//         // update failed
//         updateStatus: "failed",
//         updateError: `${aiResult.reason}`,
//         attemptedUpdateText: newText,
//         // get old time
//         lastDateModified: beforeData.lastDateModified,
//         dateUpdated: beforeData.dateUpdated,
//         // Update time check
//         moderatedAt: admin.firestore.Timestamp.now(),
//         moderatedBy: "AI_Rollback",
//       });
//       console.log(`AI chặn bài ${postId} vì: ${aiResult.reason} (mất ${executionTime}ms)`);
//       console.log(`Đã khôi phục bài viết về trạng thái cũ an toàn.`);
//     } else {
//       // if not toxic, set status to active
//       await afterDoc.ref.update({
//         status: "active",
//         aiReasonText: null,
//         updateStatus: "success",
//         updateError: null,
//         attemptedUpdateText: null,
//         moderatedBy: "AI_Update",
//         moderatedAt: admin.firestore.Timestamp.now(),
//       });
//       console.log(`AI duyệt sạch (mất ${executionTime}ms)`);
//     }
//   } catch (error) {
//     // Measure the time even if there is an error (to know how long it takes to die)
//     // for example, if it takes exactly 10000ms, it's due to a timeout).
//     const errorTime = Date.now() - startTime;
//     console.error(`[ERROR] Lỗi gọi AI Server sau ${errorTime}ms:`, error.message);

//     // On error, Auto-Approve the post to avoid pending content for users
//     await afterDoc.ref.update({
//       status: "active",
//       moderatedBy: "system_failover",
//       aiReasonText: "Dich vụ AI lỗi -> tự động duyệt",
//       moderatedAt: admin.firestore.Timestamp.now(),
//     });
//     console.log(` Đã Auto-Approve bài viết do lỗi.`);
//   }
// });

/**
 * 9. AI Check Content (Text & Image)
 */
exports.checkPostContent = onDocumentCreated("posts/{postId}", async (event) => {
  const snapshot = event.data;
  const postId = event.params.postId;

  // if no snapshot, exit
  if (!snapshot) {
    return;
  }

  // get post data
  const postData = snapshot.data();
  // get post text
  const text = postData.postText || "";

  // check the post is reshare or original
  const isReshare = postData.originalPostId ? true : false;
  // if the post is a reshare, skip checking image
  const image = isReshare ? "" : (postData.postUrl || "");

  // if don't have both text + image -> Active
  if (!text && !image) {
    console.log(`Bài ${postId} không có văn bản và hình ảnh. Bỏ qua kiểm duyệt AI.`);
    return snapshot.ref.update({status: "active"});
  }

  console.log(`[START] Bắt đầu kiểm duyệt bài ${postId}...`);
  const startTime = Date.now();

  // Variables for storing test results
  let isTextToxic = false;
  let textReason = null;

  let isImageUnsafe = false;
  let imageReason = null;

  // RUN BOTH CHECKS SIMULTANEOUSLY (Promise.all)
  // Text & Image are Checked in Parallel

  // Check Text
  const checkTextPromise = async ()=>{
    // text == null => skip
    if (!text) return;

    try {
      console.log(`Checking Text...`);
      // call AI server with timeout of 10 seconds
      const response = await axios.post(AI_SERVER_URL, {text: text}, {timeout: 10000});
      // get AI result
      const aiResult = response.data;

      // process AI result
      // if toxic
      if (aiResult.is_toxic === true) {
        isTextToxic = true;
        textReason = aiResult.reason || "Vi phạm tiêu chuẩn văn bản";
      }
    } catch (error) {
      // If Server text error, log the error
      console.error(`[ERROR] Lỗi server Text: ${error.message}`);
    }
  };

  // Check Image
  const checkImagePromise = async ()=>{
    // image == null => skip
    if (!image) return;

    try {
      console.log(`Checking Image...`);
      // Use Google Vision to check image safety
      const [result] = await visionClient.annotateImage({
        image: {source: {imageUri: image}},
        features: [
          {type: "SAFE_SEARCH_DETECTION"},
          {type: "LABEL_DETECTION", maxResults: 10}, // get 10 labels
        ],
      });

      const safeSearch = result.safeSearchAnnotation;
      const labels = result.labelAnnotations;

      const labelDescriptions = labels.map((l) => l.description).join(", ");
      console.log(`Vision Labels: [${labelDescriptions}]`);
      console.log(`Vision SafeSearch:`, JSON.stringify(safeSearch));

      // Check the likelihood of unsafe content
      // LIKELY: khả năng cao
      // VERY_LIKELY: rất chắc chắn
      // POSSIBLE: có thể/ nghi ngờ
      // UNLIKELY: không có khả năng
      // VERY_UNLIKELY: rất không có khả năng
      // UNKNOWN: không xác định

      // CLASS 1: CHECK SAFE SEARCH
      const isViolenceUnsafe = (likelihood) => {
        return likelihood === "POSSIBLE" || likelihood === "LIKELY"|| likelihood === "VERY_LIKELY";
      };

      const isAdultUnsafe = (likelihood) => {
        return likelihood === "LIKELY" || likelihood === "VERY_LIKELY";
      };

      if (isAdultUnsafe(safeSearch.adult)) imageReason = "Chứa nội dung người lớn (18+)";
      else if (isViolenceUnsafe(safeSearch.violence)) imageReason = "Chứa nội dung bạo lực";
      else if (isAdultUnsafe(safeSearch.racy)) imageReason = "Hình ảnh quá gợi cảm";
      else if (isViolenceUnsafe(safeSearch.medical)) imageReason = "Hình ảnh máu me/y tế";

      // CLASS 2: CHECK KEYWORDS (LABEL)
      // If class 1 hasn't caught it yet, use class 2 to scan for forbidden keywords.
      if (!imageReason && labels) {
        // Define forbidden keywords
        const BLACKLIST_LABELS = [
          "blood", "bleeding", "injury", "wound", // Blood, injury
          "explosion", "bomb", "grenade", // Violence explosion
          "gun", "firearm", "pistol", "rifle", "weapon", "sword", "knife", // Weapons
          "fight", "fighting", "assault", "violence", // Fighting
          "horror", "terror", // Horror
        ];

        // Check if any label is in the blacklist
        for (const label of labels) {
          const labelName = label.description.toLowerCase();
          const score = label.score; // Accuracy (0.0 - 1.0)

          // Check if label is in the blacklist
          if (BLACKLIST_LABELS.some((badWord) => labelName.includes(badWord)) && score > 0.7) {
            imageReason = `Phát hiện vật thể/nội dung cấm: ${label.description} (${Math.round(score*100)}%)`;
            break; // block
          }
        }
      }

      // If any reason found, mark image as unsafe
      if (imageReason) {
        isImageUnsafe = true;
      }
    } catch (error) {
      // If Vision API error, log the error
      console.error(`[ERROR] Lỗi Google Vision: ${error.message}`);
    }
  };
    // Run both checks in parallel
  await Promise.all([checkTextPromise(), checkImagePromise()]);

  // After both checks are done, decide the final status
  const endTime = Date.now();
  const executionTime = endTime - startTime;
  console.log(`[PERFORMANCE] Kiểm duyệt hoàn tất trong: ${executionTime}ms`);

  const isRejected = isTextToxic || isImageUnsafe;
  let finalReason = null;

  // Log the final decision
  if (isRejected) {
    const reasons = [];
    if (isTextToxic) reasons.push(`Văn bản: ${textReason}`);
    if (isImageUnsafe) reasons.push(`Hình ảnh: ${imageReason}`);
    // join text + image reasons
    finalReason = reasons.join(" | ");
    console.log(` [BLOCK] Bài ${postId}, lý do: ${finalReason}`);

    if (isReshare && postData.originalPostId) {
      try {
        await admin.firestore()
            .collection("posts")
            .doc(postData.originalPostId)
            .update({
              reshareCount: admin.firestore.FieldValue.increment(-1),
            });
        console.log(`[ROLLBACK] Đã hoàn tác lượt chia sẻ cho bài gốc ${postData.originalPostId}`);
      } catch (error) {
        console.error(`[ERROR] Lỗi hoàn tác lượt chia sẻ cho bài gốc ${postData.originalPostId}: ${error.message}`);
      }
    }
  } else {
    console.log(`[ACTIVE] Bài ${postId}, Nội dung sạch.`);
  }

  // Update post status based on checks
  try {
    await snapshot.ref.update({
      status: isRejected ? "rejected" : "active",
      aiReasonText: textReason,
      aiReasonImage: imageReason,
      moderatedBy: "AI",
      moderatedAt: admin.firestore.Timestamp.now(),
      imageChecked: !!image, // mark if image was checked
      textChecked: !!text, // mark if text was checked
    });
    console.log(`[DONE] Hoàn tất sau ${executionTime}ms`);
  } catch (error) {
    console.error(`[ERROR] Lỗi cập nhật trạng thái bài ${postId}: ${error.message}`);
  }
});

/**
 * Check Post Update (Text & Image Moderation with Rollback)
 */
exports.checkPostContentUpdate = onDocumentUpdated("posts/{postId}", async (event) => {
  // Get data before and after the update
  const beforeDoc = event.data.before;
  const afterDoc = event.data.after;
  const postId = event.params.postId;

  // get data (json contains content)
  const beforeData = beforeDoc.data();
  const afterData = afterDoc.data();

  // Get new text and image
  const newText = afterData.postText || "";
  const oldText = beforeData.postText || "";

  const newImage = afterData.postUrl || "";// With reshare, this could be the link to the original image.
  const oldImage = beforeData.postUrl || "";

  const isTextChanged = newText !== oldText;
  const isImageChanged = newImage !== oldImage;

  // If neither text nor image changed, exit
  if (!isTextChanged && !isImageChanged) {
    console.log(`Bài ${postId} cập nhật nhưng không thay đổi nội dung văn bản hoặc hình ảnh. Bỏ qua kiểm tra AI.`);
    return;
  }

  if (afterData.moderatedBy === "AI_Rollback") {
    console.log(`[SKIP] Bỏ qua kiểm duyệt do đây là thao tác Rollback hệ thống.`);
    return;
  }

  console.log(`[UPDATE] Bài ${postId} có thay đổi. Text: ${isTextChanged}, Img: ${isImageChanged}`);
  const startTime = Date.now();

  // Variables for storing test results
  let isTextToxic = false;
  let textReason = null;

  let isImageUnsafe = false;
  let imageReason = null;

  //
  let checkError=null;

  // Check Text if changed
  const checkTextPromise = async ()=>{
    if (!isTextChanged || !newText) return;

    try {
      console.log(`Checking Updated Text...`);
      // call AI server with timeout of 10 seconds
      const response = await axios.post(AI_SERVER_URL, {text: newText}, {timeout: 10000});
      const aiResult = response.data;

      // Check if toxic
      if (aiResult.is_toxic === true) {
        isTextToxic = true;
        textReason = aiResult.reason || "Văn bản vi phạm tiêu chuẩn";
      }
    } catch (error) {
      checkError=`Lỗi Server AI Text: ${error.message}`;
      console.error(`[ERROR] Lỗi Server AI Text: ${error.message}`);
    }
  };

  // Check Image if changed
  const checkImagePromise = async ()=>{
    if (!isImageChanged || !newImage) return;

    try {
      console.log(`Checking Updated Image...`);
      // Use Google Vision to check image safety
      const [result] = await visionClient.annotateImage({
        image: {source: {imageUri: newImage}},
        features: [
          {type: "SAFE_SEARCH_DETECTION"},
          {type: "LABEL_DETECTION", maxResults: 10},
        ],
      });

      const safeSearch = result.safeSearchAnnotation;
      const labels = result.labelAnnotations;

      console.log(`Vision SafeSearch:`, JSON.stringify(safeSearch));

      // Check likelihoods
      const isViolenceUnsafe = (likelihood) => {
        return likelihood === "POSSIBLE" || likelihood === "LIKELY"|| likelihood === "VERY_LIKELY";
      };

      const isAdultUnsafe = (likelihood) => {
        return likelihood === "LIKELY" || likelihood === "VERY_LIKELY";
      };

      if (isAdultUnsafe(safeSearch.adult)) imageReason = "Chứa nội dung người lớn (18+)";
      else if (isViolenceUnsafe(safeSearch.violence)) imageReason = "Chứa nội dung bạo lực";
      else if (isAdultUnsafe(safeSearch.racy)) imageReason = "Hình ảnh quá gợi cảm";
      else if (isViolenceUnsafe(safeSearch.medical)) imageReason = "Hình ảnh máu me/y tế";

      // Check keywords if class 1 didn't catch anything
      if (!imageReason && labels) {
        const BLACKLIST_LABELS = [
          "blood", "bleeding", "injury", "wound",
          "explosion", "bomb", "grenade",
          "gun", "firearm", "pistol", "rifle", "weapon", "sword", "knife",
          "fight", "fighting", "assault", "violence",
          "horror", "terror",
        ];

        for (const label of labels) {
          const labelName = label.description.toLowerCase();
          const score = label.score;

          if (BLACKLIST_LABELS.some((badWord) => labelName.includes(badWord)) && score > 0.7) {
            imageReason = `Phát hiện vật thể/nội dung cấm: ${label.description} (${Math.round(score*100)}%)`;
            break;
          }
        }
      }

      if (imageReason) {
        isImageUnsafe = true;
      }
    } catch (error) {
      checkError=`Lỗi Google Vision API: ${error.message}`;
      console.error(`[ERROR] Lỗi Google Vision: ${error.message}`);
    }
  };

  // Run checks in parallel
  await Promise.all([checkTextPromise(), checkImagePromise()]);

  // Final decision
  const endTime = Date.now();
  const executionTime = endTime - startTime;
  console.log(`[PERFORMANCE] Kiểm duyệt cập nhật hoàn tất trong: ${executionTime}ms`);

  const isRejected = isTextToxic || isImageUnsafe;

  // IF REJECTED -> ROLLBACK TO OLD CONTENT
  if (isRejected) {
    // Summary of reasons for displaying
    const reasons = [];

    if (isTextToxic) reasons.push(`Văn bản: ${textReason}`);
    if (isImageUnsafe) reasons.push(`Hình ảnh: ${imageReason}`);
    const finalReason = reasons.join("\n");

    console.log(` [BLOCK] UPDATE Bài ${postId} sau cập nhật, lý do: ${finalReason}`);
    console.log(`Đang Rollback về nội dung an toàn trước đó...`);

    try {
      // Rollback to old content
      await afterDoc.ref.update({
        postText: oldText,
        postUrl: oldImage,
        // Keep the status active (because the old post is clean).
        status: "active",
        // Mark the update as failed so the client displays the error.
        updateStatus: "failed",
        updateError: finalReason,

        // Metadata
        moderatedBy: "AI_Rollback",
        moderatedAt: admin.firestore.Timestamp.now(),
        attemptedUpdateText: isTextChanged ? newText : null, // Save the toxic text that the user intends to edit
        attemptedUpdateImage: isImageChanged ? newImage : null, // Save the dirty image that the user intends to edit
        // keep old timestamps
        lastDateModified: beforeData.lastDateModified,
        dateUpdated: beforeData.dateUpdated,
      });
      console.log(`Đã khôi phục bài viết về trạng thái an toàn trước đó.`);
    } catch (error) {
      console.error(`[ERROR] Lỗi rollback bài ${postId}: ${error.message}`);
    }
  } else if (checkError) {
    // IF NOT REJECTED BUT HAD ERRORS DURING AI CHECKING(serveR AI errors,...) => AUTO APPROVE

    // If there was an error during checking, but content is clean
    console.log(`SYSTEM ERROR: ${checkError}. -> Auto-Approve bài ${postId}.`);
    try {
      await afterDoc.ref.update({
        status: "active",
        updateStatus: "success",
        updateError: null,
        // clear attempted updates
        aiReasonText: null,
        aiReasonImage: null,
        attemptedUpdateText: null,
        attemptedUpdateImage: null,

        // Metadata
        moderatedBy: "system_failover",
        moderatedAt: admin.firestore.Timestamp.now(),
        // mark what was checked
        textChecked: !!newText,
        imageChecked: !!newImage,
      });
      console.log(`[AUTO-APPROVE] Hoàn tất sau ${executionTime}ms`);
    } catch (error) {
      console.error(`[ERROR] Lỗi auto-approve bài ${postId} vì: ${error.message}`);
    }
  } else {
    // IF CLEAN CONTENT -> APPROVE
    console.log(`[ACTIVE] Bài ${postId} sau cập nhật, nội dung sạch.`);

    // If image was changed, delete old image from Storage
    if (isImageChanged && oldImage) {
      // Delete old image from Storage to save space
      deleteImageFromStorage(oldImage).catch((error)=>{
        console.error(`[CLEANUP ERROR] Lỗi xóa ảnh cũ sau cập nhật bài ${postId}: ${error.message}`);
      });
    }

    try {
      await afterDoc.ref.update({
        status: "active",
        updateStatus: "success",
        updateError: null,
        // delete old reasons (if any)
        aiReasonText: null,
        aiReasonImage: null,

        // clear attempted updates
        attemptedUpdateText: null,
        attemptedUpdateImage: null,

        // Metadata
        moderatedBy: "AI_Update",
        moderatedAt: admin.firestore.Timestamp.now(),
        // mark what was checked
        textChecked: !!newText,
        imageChecked: !!newImage,
      });
      console.log(`[DONE] Hoàn tất sau ${executionTime}ms`);
    } catch (error) {
      console.error(`[ERROR] Lỗi cập nhật trạng thái đã duyệt cho bài ${postId}: ${error.message}`);
    }
  }
});

// Utility function to delete image from Firebase Storage
async function deleteImageFromStorage(imageUrl) {
  if (!imageUrl) return;

  try {
    // URLs usually look like this: https://firebasestorage.googleapis.com/.../o/posts%2Fabc.jpg?alt=media...
    // Need to get the "posts/abc.jpg" part
    const bucket = admin.storage().bucket();

    // Extract the path after the "/o/"
    const parts = imageUrl.split("/o/");
    if (parts.length < 2) return;

    // Get the path and remove query parameters (?alt=...)
    let filePath = parts[1].split("?")[0];

    // Decode (cuz URLs are encoded from / to %2F)
    filePath = decodeURIComponent(filePath);

    console.log(`[CLEANUP] Đang xóa ảnh cũ: ${filePath}`);
    await bucket.file(filePath).delete();
    console.log(`[CLEANUP] Đã xóa thành công.`);
  } catch (error) {
    // Nếu ảnh không tồn tại hoặc lỗi, chỉ log ra chứ không làm crash app
    console.warn(`[CLEANUP WARNING] Không thể xóa ảnh cũ: ${error.message}`);
  }
}
