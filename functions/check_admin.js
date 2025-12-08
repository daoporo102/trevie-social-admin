// check_admin.js
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const email = "daoadmin@gmail.com"; // Email bạn muốn kiểm tra

admin.auth().getUserByEmail(email)
    .then((user) => {
      console.log("--- KẾT QUẢ KIỂM TRA ---");
      console.log(`Email: ${user.email}`);
      console.log(`UID: ${user.uid}`);
      // Đây là phần quan trọng nhất
      console.log("Custom Claims (Quyền):", user.customClaims);

      if (user.customClaims && (user.customClaims.admin || user.customClaims.superAdmin)) {
        console.log("=> KẾT LUẬN: Tài khoản này LÀ ADMIN.");
      } else {
        console.log("=> KẾT LUẬN: Tài khoản này KHÔNG PHẢI admin.");
      }
      process.exit();
    })
    .catch((error) => {
      console.log("Lỗi:", error);
      process.exit(1);
    });
