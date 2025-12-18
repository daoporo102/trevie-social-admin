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

const VIETNAMESE_LABELS = {
  "blood": "máu",
  "bleeding": "chảy máu",
  "injury": "thương tích",
  "wound": "vết thương",
  "explosion": "chất nổ",
  "bomb": "bom",
  "grenade": "lựu đạn",
  "gun": "súng",
  "firearm": "súng",
  "pistol": "súng lục",
  "rifle": "súng trường",
  "weapon": "vũ khí",
  "sword": "kiếm",
  "knife": "dao",
  "fight": "đánh nhau",
  "fighting": "đánh nhau",
  "assault": "tấn công",
  "violence": "bạo lực",
  "horror": "kinh dị",
  "terror": "khủng bố",
  "air gun": "súng",
};

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
 * AI Check Content (Text & Image)
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
  let textScore = 0.0;

  let isImageUnsafe = false;
  let imageReason = null;
  let imageScore = 0.0;

  // Violation Labels
  const violationLabels = [];

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

      console.log(`[AI RESULT] Toxic: ${aiResult.is_toxic}, Score: ${aiResult.confidence_score}`);

      // process AI result
      // if toxic
      if (aiResult.is_toxic === true) {
        isTextToxic = true;
        textReason = aiResult.reason || "Vi phạm tiêu chuẩn văn bản";
        textScore = aiResult.confidence_score || 0.97; // Fixed score for now
        violationLabels.push("toxic_text");
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

      // CLASS 1: SCORING SAFE SEARCH
      const adultScore = getVisionScore(safeSearch.adult);
      const violenceScore = getVisionScore(safeSearch.violence);
      const sexualScore = getVisionScore(safeSearch.racy);
      const medicalScore = getVisionScore(safeSearch.medical);

      // Blocking threshold
      const THRESHOLD_LIKELY = 0.75;
      const THRESHOLD_POSSIBLE = 0.50;

      // Determine if image is unsafe based on scores & push violation labels
      if (adultScore >= THRESHOLD_LIKELY) {
        imageReason = "Chứa nội dung người lớn (18+)";
        violationLabels.push("adult");
      } else if (violenceScore >= THRESHOLD_POSSIBLE) {
        imageReason = "Chứa nội dung bạo lực";
        violationLabels.push("violence");
      } else if (sexualScore >= THRESHOLD_LIKELY) {
        imageReason = "Hình ảnh quá gợi cảm";
        violationLabels.push("sexual/racy");
      } else if (medicalScore >= THRESHOLD_POSSIBLE) {
        imageReason = "Hình ảnh máu me/y tế";
        violationLabels.push("medical/blood");
      }

      // CLASS 2: CHECK KEYWORDS (LABEL)
      // If class 1 hasn't caught it yet, use class 2 to scan for forbidden keywords.

      // Calculate label score
      let labelMaxScore = 0.0;
      if (labels) {
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

          // Find if label matches any bad word
          const matchedBadWords= BLACKLIST_LABELS.find((badWord) => labelName.includes(badWord));

          // Check if label is in the blacklist
          if (matchedBadWords && score > 0.7) {
            // If found, set reason and score
            if (!imageReason) {
              const translatedLabel = VIETNAMESE_LABELS[matchedBadWords] || label.description;
              imageReason = `Phát hiện vật thể/nội dung cấm: ${translatedLabel}`;
            }

            // Always push the log so the admin knows there are guns/knives... even if blocked for other reasons.
            violationLabels.push(`banned_object:${label.description}`);

            // Update max label score
            if (score > labelMaxScore) {
              labelMaxScore = score;
            }
          }
        }
      }

      // Final image score is the max of safe search and label score
      const maxSafeSearchScore = Math.max(adultScore, violenceScore, sexualScore, medicalScore);
      imageScore = Math.max(maxSafeSearchScore, labelMaxScore);

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
    finalReason = reasons.join("\n");
    console.log(` [BLOCK] Bài ${postId}, lý do: ${finalReason}`);

    // Log violation to violation_logs collection
    await logViolation({
      uid: postData.uid,
      targetId: postId,
      targetType: "post",
      parentId: null,
      actionType: isReshare ? "reshare" : "create",

      moderatedBy: "AI",
      violationLabels: violationLabels,

      aiConfidence: Math.max(textScore, imageScore),
      textScore: textScore,
      imageScore: imageScore,

      reason: finalReason,
      toxicText: text || null,
      toxicImageUrl: image || null,

    });

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
  let textScore=0.0;

  let isImageUnsafe = false;
  let imageReason = null;
  let imageScore=0.0;

  const violationLabels = [];
  let checkError=null;

  // Check Text if changed
  const checkTextPromise = async ()=>{
    if (!isTextChanged || !newText) return;

    try {
      console.log(`Checking Updated Text...`);
      // call AI server with timeout of 10 seconds
      const response = await axios.post(AI_SERVER_URL, {text: newText}, {timeout: 10000});
      const aiResult = response.data;

      console.log(`[AI RESULT] Toxic: ${aiResult.is_toxic}, Score: ${aiResult.confidence_score}`);

      // Check if toxic
      if (aiResult.is_toxic === true) {
        isTextToxic = true;
        textReason = aiResult.reason || "Văn bản vi phạm tiêu chuẩn";
        textScore = aiResult.confidence_score || 0.97; // Fixed score for now
        violationLabels.push("toxic_text");
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

      // Calculate scores from SafeSearch
      const adultScore = getVisionScore(safeSearch.adult);
      const violenceScore = getVisionScore(safeSearch.violence);
      const sexualScore = getVisionScore(safeSearch.racy);
      const medicalScore = getVisionScore(safeSearch.medical);

      // thresholds blocking
      const THRESHOLD_LIKELY = 0.75;
      const THRESHOLD_POSSIBLE = 0.50;

      //
      if (adultScore >= THRESHOLD_LIKELY) {
        imageReason = "Chứa nội dung người lớn (18+)";
        violationLabels.push("adult");
      } else if (violenceScore >= THRESHOLD_POSSIBLE) {
        imageReason = "Chứa nội dung bạo lực";
        violationLabels.push("violence");
      } else if (sexualScore >= THRESHOLD_LIKELY) {
        imageReason = "Hình ảnh quá gợi cảm";
        violationLabels.push("racy/sexual");
      } else if (medicalScore >= THRESHOLD_POSSIBLE) {
        imageReason = "Hình ảnh máu me/y tế";
        violationLabels.push("medical_gore");
      }

      // Check keywords (Labels)
      let labelMaxScore = 0.0;
      if (labels) {
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

          // Find if label matches any bad word
          const matchedBadWords= BLACKLIST_LABELS.find((badWord) => labelName.includes(badWord));

          if (matchedBadWords && score > 0.7) {
            if (!imageReason) { // Only set if not already set
              const translatedLabel = VIETNAMESE_LABELS[matchedBadWords] || label.description;
              imageReason = `Phát hiện vật thể/nội dung cấm: ${translatedLabel}`;
            }
            // Log the violation label
            violationLabels.push(`banned_object:${label.description}`);
            // Update max label score
            if (score > labelMaxScore) {
              labelMaxScore = score;
            }
          }
        }
      }

      // Calculate Image Final
      const maxSafeSearchScore = Math.max(adultScore, violenceScore, sexualScore, medicalScore);
      imageScore = Math.max(maxSafeSearchScore, labelMaxScore);

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

  // IF REJECTED -> BLOCK & ROLLBACK TO OLD CONTENT
  if (isRejected) {
    // Summary of reasons for displaying
    const reasons = [];

    if (isTextToxic) reasons.push(`Văn bản: ${textReason}`);
    if (isImageUnsafe) reasons.push(`Hình ảnh: ${imageReason}`);
    const finalReason = reasons.join("\n");
    const finalConfidence = Math.max(textScore, imageScore);

    console.log(` [BLOCK] UPDATE Bài ${postId} sau cập nhật, lý do: ${finalReason}`);
    console.log(`Đang Rollback về nội dung an toàn trước đó...`);

    // Log violations to violation_logs collection
    await logViolation({
      uid: afterData.uid,
      targetId: postId,
      targetType: "post",
      parentId: null,
      actionType: "update",

      moderatedBy: "AI_Rollback",
      violationLabels: violationLabels,
      aiConfidence: finalConfidence,
      textScore: textScore,
      imageScore: imageScore,

      reason: finalReason,
      toxicText: isTextChanged ? newText : null,
      toxicImageUrl: isImageChanged ? newImage : null,
    });

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


// Log Violation Utility Function
async function logViolation(data) {
  try {
    const violationRef = admin.firestore().collection("violation_logs").doc();
    await violationRef.set({
      logId: violationRef.id,
      uid: data.uid,

      targetId: data.targetId, // could be postId, commentId, or userId
      targetType: data.targetType, // "post", "comment", "user"
      parentId: data.parentId || null, // for comments, the postId it belongs to

      actionType: data.actionType, // 'create' 'update','reshare', 'delete'

      moderatedBy: data.moderatedBy || "AI", // AI, Admin, System
      violationLabels: data.violationLabels || [], // array of labels detected

      aiConfidence: data.aiConfidence || 0.0, // confidence score from AI

      reason: data.reason, // reason for violation
      textScore: data.textScore || 0.0, // text toxicity score
      imageScore: data.imageScore || 0.0, // image safety score

      toxicText: data.toxicText || null,
      toxicImageUrl: data.toxicImageUrl || null,

      createdAt: admin.firestore.Timestamp.now(),
      isRead: false,
    });
    console.log(`[AUDIT] Đã ghi log ${data.targetType} cho User ${data.uid}`);
  } catch (error) {
    console.error(`[AUDIT ERROR] Không thể ghi log: ${error.message}`);
  }
}

function getVisionScore(likelihood) {
  switch (likelihood) {
    case "VERY_LIKELY": return 0.95; // Most likely a violation
    case "LIKELY": return 0.75; // Likely a violation
    case "POSSIBLE": return 0.50; // Possible violation
    case "UNLIKELY": return 0.25; // Unlikely violation
    case "VERY_UNLIKELY": return 0.05; // Very unlikely violation
    default: return 0.0; // No violation
  }
}
