#include <WiFi.h>
#include <FirebaseESP32.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include <Keypad.h>
#include <time.h>

#define WIFI_SSID     "DT"
#define WIFI_PASS     "00008888"
#define DB_SECRET     "DiMtA0HgszGGWV0leE8tRQPGrGb9BF14ZhI7twT4"
#define DATABASE_URL  "smarthomedoorlock-e9b6d-default-rtdb.asia-southeast1.firebasedatabase.app"

#define PATH_ADMIN_PWD  "/config/admin_password"
#define PATH_DOOR_PWD   "/config/door_password"
#define PATH_SYS_CMD    "/system_command"
#define PATH_APP_CMD    "/app_command"
#define PATH_OTP        "/current_otp"
#define PATH_OTP_USED   "/otp_used"
#define PATH_EXPIRY     "/expiry_time"
#define PATH_DOOR_ST    "/door_status"
#define PATH_LAST_ID    "/last_id"

#define PIN_RFID_SS   5
#define PIN_RFID_RST  4
#define PIN_SERVO     17
#define PIN_LED_GREEN 16
#define PIN_LED_RED   2
#define PIN_BUZZER    15

const byte ROWS = 4, COLS = 4;
char keys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};
byte rowPins[ROWS] = {13, 14, 27, 12};
byte colPins[COLS] = {26, 25, 33, 32};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

MFRC522           rfid(PIN_RFID_SS, PIN_RFID_RST);
LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo             doorServo;
FirebaseData      fbData;
FirebaseConfig    fbConfig;
FirebaseAuth      fbAuth;

String inputPwd  = "";
String adminPwd  = "123456";
String doorPwd   = "123456";

bool  sysLocked  = false;
int   failCount  = 0;
// const int MAX_FAIL = 3;
unsigned long currentLockDuration = 30000;
bool requireAdminCard = false;

bool          doorOpen     = false;
unsigned long doorOpenTime = 0;
const unsigned long DOOR_OPEN_MS = 5000;

unsigned long lockStartTime = 0;
// const unsigned long LOCK_DURATION_MS = 30000;

String lastOTP    = "___NONE___";
String lastSysCmd = "idle";
String lastAppCmd = "idle";

unsigned long lastFbCheck = 0;
const unsigned long FB_INTERVAL = 2000;

// OTP flag - tranh WDT reset
bool   pendingOTPCheck = false;
String pendingOTPInput = "";

// Theo doi door_status tu app
int lastDoorStatusFromApp = 0;

// ---------------------------------------------------
// FIREBASE HELPERS
// ---------------------------------------------------
String fbGetStr(const char* path) {
  if (Firebase.getString(fbData, path)) return fbData.stringData();
  return "";
}
bool fbGetBool(const char* path, bool fallback = true) {
  if (Firebase.getBool(fbData, path)) return fbData.boolData();
  return fallback;
}
double fbGetDouble(const char* path) {
  if (Firebase.getDouble(fbData, path)) return fbData.doubleData();
  if (Firebase.getInt(fbData, path))    return (double)fbData.intData();
  return 0;
}
void fbSetStr(const char* path, String val)  { Firebase.setString(fbData, path, val); }
void fbSetBool(const char* path, bool val)   { Firebase.setBool(fbData, path, val); }
void fbSetInt(const char* path, int val)     { Firebase.setInt(fbData, path, val); }

void pushLog(String method, String uid = "") {
  FirebaseJson json;
  json.set("method", method);
  json.set("timestamp/.sv", "timestamp");
  if (uid.length() > 0) json.set("uid", uid);
  Firebase.pushJSON(fbData, "/logs", json);
}
long getUnixSec() {
  time_t now; time(&now); return (long)now;
}

// ---------------------------------------------------
// BUZZER
// ---------------------------------------------------
void beepOK() {
  tone(PIN_BUZZER, 1000, 150); delay(180);
  tone(PIN_BUZZER, 1500, 150); delay(180);
}
void beepFail() {
  tone(PIN_BUZZER, 400, 300); delay(350);
  tone(PIN_BUZZER, 250, 500); delay(550);
}
void beepLocked() {
  for (int i = 0; i < 3; i++) { tone(PIN_BUZZER, 300, 200); delay(300); }
}
void beepClick() { tone(PIN_BUZZER, 1200, 60); }

// ---------------------------------------------------
// LCD
// ---------------------------------------------------
void lcdShow(const char* r1, const char* r2) {
  lcd.clear();
  lcd.setCursor(0,0); lcd.print(r1);
  lcd.setCursor(0,1); lcd.print(r2);
}
void showIdle() {
  inputPwd = "";
  if (sysLocked) return;
  lcdShow(" QUET THE / NHAP", " MAT KHAU  [#]  ");
}
void showPassInput() {
  lcd.clear();
  lcd.setCursor(0,0); lcd.print("  NHAP MAT KHAU ");
  String stars = "";
  for (unsigned int i = 0; i < inputPwd.length(); i++) stars += "*";
  lcd.setCursor((16 - (int)stars.length()) / 2, 1);
  lcd.print(stars);
}

// ---------------------------------------------------
// MO / DONG CUA
// ---------------------------------------------------
void openDoor(String method, String uid = "") {
  if (doorOpen) return;
  delay(800);
  doorServo.write(90);
  digitalWrite(PIN_LED_GREEN, HIGH);
  digitalWrite(PIN_LED_RED,   LOW);
  doorOpen     = true;
  doorOpenTime = millis();
  lcdShow("  CHAO MUNG!    ", "  CUA DANG MO   ");
  beepOK();
  yield();
  fbSetInt(PATH_DOOR_ST, 1);
  yield();
  lastDoorStatusFromApp = 1;
  pushLog(method, uid);
  Serial.println("[DOOR] Mo: " + method);
}

void closeDoor() {
  doorServo.write(0);
  digitalWrite(PIN_LED_GREEN, LOW);
  digitalWrite(PIN_LED_RED, sysLocked ? HIGH : LOW);
  doorOpen = false;
  fbSetInt(PATH_DOOR_ST, 0);
  lastDoorStatusFromApp = 0;
  pushLog("door_close");
  if (!sysLocked) showIdle();
  Serial.println("[DOOR] Dong cua");
}

// ---------------------------------------------------
// KHOA / MO KHOA
// ---------------------------------------------------
void lockSystem(String reason) {
  sysLocked     = true;
  failCount     = 0;
  lockStartTime = millis();
  digitalWrite(PIN_LED_RED,   HIGH);
  digitalWrite(PIN_LED_GREEN, LOW);
  beepLocked();
  fbSetStr(PATH_SYS_CMD, "locked");
  lastSysCmd = "locked";
  pushLog("sys_locked");
  Serial.println("[LOCK] " + reason);
}

// void unlockSystem() {
//   sysLocked     = false;
//   failCount     = 0;
//   lockStartTime = 0;
//   digitalWrite(PIN_LED_RED, LOW);
//   lcdShow("  MO KHOA OK!   ", "  He thong san  ");
//   beepOK();
//   delay(1500);
//   fbSetStr(PATH_SYS_CMD, "idle");
//   lastSysCmd = "idle";
//   lcdShow(" QUET THE / NHAP", " MAT KHAU  [#]  ");
//   Serial.println("[UNLOCK] OK");
// }

void unlockSystem() {
  sysLocked        = false;
  requireAdminCard = false; // Reset lại cờ khóa thẻ Admin
  failCount        = 0;
  lockStartTime    = 0;
  digitalWrite(PIN_LED_RED, LOW);
  lcdShow("  MO KHOA OK!   ", "  He thong san  ");
  beepOK();
  delay(1500);
  fbSetStr(PATH_SYS_CMD, "idle");
  lastSysCmd = "idle";
  lcdShow(" QUET THE / NHAP", " MAT KHAU  [#]  ");
  Serial.println("[UNLOCK] OK");
}


// void accessDenied(String msg) {
//   failCount++;
//   digitalWrite(PIN_LED_RED, HIGH);
//   lcd.clear();
//   lcd.setCursor(0,0); lcd.print("  TU CHOI!      ");
//   lcd.setCursor(0,1); lcd.print(msg.substring(0,16));
//   beepFail();
//   delay(1500);
//   if (!sysLocked) {
//     if (failCount >= MAX_FAIL) lockSystem("Sai " + String(MAX_FAIL) + " lan");
//     else { digitalWrite(PIN_LED_RED, LOW); showIdle(); }
//   }
// }

// ---------------------------------------------------
// DEM NGUOC LOCKOUT
// ---------------------------------------------------
// void handleLockCountdown() {
//   if (!sysLocked) return;
//   long elapsed   = (long)(millis() - lockStartTime);
//   long remaining = ((long)LOCK_DURATION_MS - elapsed) / 1000;
//   if (remaining <= 0) { unlockSystem(); return; }
//   static long lastShown = -1;
//   if (remaining != lastShown) {
//     lastShown = remaining;
//     char line2[17];
//     snprintf(line2, sizeof(line2), "  Con: %3lds      ", remaining);
//     lcd.setCursor(0,0); lcd.print("!! BI KHOA !!   ");
//     lcd.setCursor(0,1); lcd.print(line2);
//   }
// }

void accessDenied(String msg) {
  failCount++;
  digitalWrite(PIN_LED_RED, HIGH);
  lcd.clear();
  lcd.setCursor(0,0); lcd.print("  TU CHOI!      ");
  lcd.setCursor(0,1); lcd.print(msg.substring(0,16));
  beepFail();
  delay(1000);

  if (!sysLocked) {
    if (failCount == 3) {
      currentLockDuration = 30000; // 30s
      lockSystem("Sai 3 lan -> Khóa 30s");
    } else if (failCount == 4) {
      currentLockDuration = 60000; // 60s
      lockSystem("Sai 4 lan -> Khóa 60s");
    } else if (failCount == 5) {
      currentLockDuration = 120000; // 120s
      lockSystem("Sai 5 lan -> Khóa 120s");
    } else if (failCount >= 6) {
      requireAdminCard = true;     // Khóa vĩnh viễn
      lockSystem("Sai 6 lan -> Khoa vinh vien");
    } else {
      digitalWrite(PIN_LED_RED, LOW);
      showIdle();
    }
  }
}

void handleLockCountdown() {
  if (!sysLocked) return;

  // Nếu bị khóa vĩnh viễn (>= 6 lần), chỉ hiện yêu cầu thẻ Admin, KHÔNG đếm ngược
  if (requireAdminCard) {
    static long lastAdminBlink = 0;
    if (millis() - lastAdminBlink > 1000) {
      lastAdminBlink = millis();
      lcdShow(" HE THONG KHOA! ", " QUET THE ADMIN ");
    }
    return;
  }

  // Đếm ngược bình thường
  long elapsed   = (long)(millis() - lockStartTime);
  long remaining = ((long)currentLockDuration - elapsed) / 1000;

  if (remaining <= 0) {
    unlockSystem();
    return;
  }

  static long lastShown = -1;
  if (remaining != lastShown) {
    lastShown = remaining;
    char line2[17];
    snprintf(line2, sizeof(line2), "  Con: %3lds      ", remaining);
    lcd.setCursor(0,0); lcd.print("!! BI KHOA !!   ");
    lcd.setCursor(0,1); lcd.print(line2);
  }
}


// ---------------------------------------------------
// RFID
// ---------------------------------------------------
String getCardUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

bool isAdminCard(String uid) {
  String v1 = fbGetStr("/admin_cards/admin1/uid");
  if (v1.length() > 0 && v1 == uid) return true;
  String v2 = fbGetStr("/admin_cards/admin2/uid");
  if (v2.length() > 0 && v2 == uid) return true;
  return false;
}

bool isMemberCard(String uid) {
  return (fbGetStr(("/members/" + uid + "/name").c_str()).length() > 0);
}

String getMemberName(String uid) {
  return fbGetStr(("/members/" + uid + "/name").c_str());
}

void handleRFID() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;
  String uid = getCardUID();
  Serial.println("[RFID] UID: " + uid);

  String sysCmd = fbGetStr(PATH_SYS_CMD);
  if (sysCmd == "scan_mode") {
    fbSetStr(PATH_LAST_ID, uid);
    lcdShow("  DA QUET THE!  ", "  Xem tren app  ");
    beepOK();
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    delay(2000);
    if (!sysLocked) showIdle();
    return;
  }
  if (sysLocked) {
    if (isAdminCard(uid)) {
      lcdShow("    ADMIN OK    ", "  Mo khoa HT... ");
      delay(600);
      rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
      unlockSystem();
    } else {
      beepFail();
      rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    }
    return;
  }
  if (isAdminCard(uid)) {
    failCount = 0;
    lcdShow("    ADMIN       ", "  Chao mung!    ");
    delay(400);
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    openDoor("card_admin", uid);
    return;
  }
  if (isMemberCard(uid)) {
    failCount = 0;
    String name = getMemberName(uid);
    lcd.clear();
    lcd.setCursor(0,0); lcd.print("  CHAO MUNG!    ");
    lcd.setCursor(0,1);
    String line = "  " + (name.length() > 0 ? name : "THANH VIEN");
    if (line.length() > 16) line = line.substring(0,16);
    lcd.print(line);
    delay(400);
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    openDoor("card_member", uid);
    return;
  }
  rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
  pushLog("card_unknown", uid);
  accessDenied("The khong hop le");
}

// ---------------------------------------------------
// KEYPAD - KHONG goi Firebase, chi set flag
// FIX WDT: neu goi Firebase o day se bi reset
// ---------------------------------------------------
void handleKeypad() {
  char key = keypad.getKey();
  if (!key) return;
  if (key == 'A' || key == 'B' || key == 'C' || key == 'D') return;

  beepClick();
  Serial.println("[KEY] '" + String(key) + "'");
  if (sysLocked) return;

  if (key == '#') {
    if (inputPwd.length() == 0) { showIdle(); return; }

    // Mat khau thuong: check ngay, khong can Firebase
    if (inputPwd == doorPwd || inputPwd == adminPwd) {
      failCount = 0;
      String cur = inputPwd;
      inputPwd   = "";
      if (cur == adminPwd) openDoor("password_admin");
      else                 openDoor("password_door");
    } else {
      // Co the la OTP: luu flag, xu ly trong loop() sau 2 giay
      // TUYET DOI khong goi Firebase o day
      pendingOTPInput = inputPwd;
      pendingOTPCheck = true;
      inputPwd        = "";
      lcdShow("  Dang kiem tra ", "      ...       ");
      Serial.println("[KEY] pending OTP: '" + pendingOTPInput + "'");
    }

  } else if (key == '*') {
    if (inputPwd.length() > 0) {
      inputPwd.remove(inputPwd.length() - 1);
      if (inputPwd.length() == 0) showIdle();
      else showPassInput();
    }
  } else {
    if (inputPwd.length() < 8) {
      inputPwd += key;
      showPassInput();
    }
  }
}

// ---------------------------------------------------
// CHECK OTP - chay trong loop() Firebase block
// Khong bao gio bi WDT vi chay ngoai keypad
// ---------------------------------------------------
void checkPendingOTP() {
  if (!pendingOTPCheck) return;

  // Firebase chua san -> giu flag, thu lai chu ky sau (2s)
  if (!Firebase.ready()) {
    Serial.println("[OTP] Firebase not ready -> retry");
    return;
  }

  pendingOTPCheck = false;
  bool matched = false;

  // Doc OTP tu Firebase truoc
  String otp = fbGetStr(PATH_OTP);
  yield();
  Serial.println("[OTP] input='" + pendingOTPInput + "' firebase_otp='" + otp + "'");

  if (otp.length() < 4) {
    Serial.println("[OTP] X OTP trong Firebase rong");
    pendingOTPInput = "";
    accessDenied("Chua co OTP!");
    return;
  }

  // Neu OTP moi (khac lastOTP) thi reset otp_used tren Firebase
  bool isNewOTP = (otp != lastOTP);
  bool otpUsed  = false;

  if (isNewOTP) {
    Serial.println("[OTP] Phat hien OTP moi -> reset otp_used");
    fbSetBool(PATH_OTP_USED, false);
    yield();
    otpUsed = false;
  } else {
    otpUsed = fbGetBool(PATH_OTP_USED, false);
    Serial.println("[OTP] OTP cu, otpUsed=" + String(otpUsed));
    yield();
  }

  if (!otpUsed) {
    double expiry = fbGetDouble(PATH_EXPIRY);
    yield();
    double nowMs  = (double)getUnixSec() * 1000.0;
    bool expired  = (expiry > 1000000000000.0 && nowMs > expiry);

    Serial.println("[OTP] expiry=" + String((long)expiry)
                   + " now=" + String((long)nowMs)
                   + " expired=" + String(expired));

    if (expired) {
      Serial.println("[OTP] X Het han");
    } else if (pendingOTPInput == otp) {
      lastOTP = otp;
      fbSetBool(PATH_OTP_USED, true);
      yield();
      fbSetStr(PATH_OTP, "");
      yield();
      failCount = 0;
      matched   = true;
      Serial.println("[OTP] OK MATCH -> mo cua");
      openDoor("otp");
    } else {
      Serial.println("[OTP] X Sai so: '" + pendingOTPInput + "' != '" + otp + "'");
    }
  } else {
    Serial.println("[OTP] X Da su dung");
  }

  pendingOTPInput = "";

  if (!matched) {
    Serial.println("[OTP] -> accessDenied");
    accessDenied("Sai OTP/MK!");
  }
}

// ---------------------------------------------------
// LENH TU APP
// ---------------------------------------------------
void handleAppCommands() {
  if (!Firebase.ready()) return;

  // Dong bo mat khau
  String ap = fbGetStr(PATH_ADMIN_PWD);
  if (ap.length() >= 4 && ap != adminPwd) adminPwd = ap;
  String dp = fbGetStr(PATH_DOOR_PWD);
  if (dp.length() >= 4 && dp != doorPwd) doorPwd = dp;

  // Poll door_status: xu ly khi app ghi thang vao day
  if (Firebase.getInt(fbData, PATH_DOOR_ST)) {
    int dsApp = fbData.intData();
    if (dsApp == 1 && lastDoorStatusFromApp == 0 && !doorOpen && !sysLocked) {
      Serial.println("[DOOR_ST] App ghi 1 -> mo cua");
      lastDoorStatusFromApp = 1;
      openDoor("app_direct");
    } else {
      lastDoorStatusFromApp = dsApp;
    }
  }

  // system_command
  String cmd = fbGetStr(PATH_SYS_CMD);
  Serial.println("[SYS] poll='" + cmd + "'");

  if (cmd == "open") {
    fbSetStr(PATH_SYS_CMD, "idle");
    lastSysCmd = "idle";
    if (!doorOpen && !sysLocked) openDoor("app_open");

  } else if (cmd == "unlock_admin" || cmd == "unlock") {
    fbSetStr(PATH_SYS_CMD, "idle");
    lastSysCmd = "idle";
    if (sysLocked) unlockSystem();
    else if (!doorOpen) openDoor("app_open");

  } else if (cmd == "locked" && cmd != lastSysCmd) {
    lastSysCmd = cmd;
    if (!sysLocked) lockSystem("App ra lenh khoa");

  } else if (cmd == "scan_mode" && cmd != lastSysCmd) {
    lastSysCmd = cmd;
    lcdShow("APP: QUET THE   ", "CAN THEM...     ");

  } else if (cmd == "idle" && cmd != lastSysCmd) {
    lastSysCmd = cmd;
    if (!doorOpen && !sysLocked) showIdle();
  }

  // app_command
  String appCmd = fbGetStr(PATH_APP_CMD);
  if (appCmd != "idle" && appCmd.length() > 0 && appCmd != lastAppCmd) {
    Serial.println("[APP] cmd='" + appCmd + "'");
    lastAppCmd = appCmd;
    fbSetStr(PATH_APP_CMD, "idle");
    if (appCmd == "scan_card") {
      fbSetStr(PATH_SYS_CMD, "scan_mode");
      lastSysCmd = "scan_mode";
      lcdShow("APP: QUET THE   ", "CAN THEM...     ");
    }
  } else if (appCmd == "idle") {
    lastAppCmd = "idle";
  }
}

// ---------------------------------------------------
// TU DONG DONG CUA
// ---------------------------------------------------
void handleAutoClose() {
  if (doorOpen && (millis() - doorOpenTime >= DOOR_OPEN_MS)) closeDoor();
}

// ---------------------------------------------------
// SETUP
// ---------------------------------------------------
void setup() {
  Serial.begin(115200);
  Serial.println("=== BOOT v3 OTP-FLAG ===");

  pinMode(12, INPUT);
  delay(100);

  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_RED,   OUTPUT);
  pinMode(PIN_BUZZER,    OUTPUT);
  digitalWrite(PIN_LED_GREEN, LOW);
  digitalWrite(PIN_LED_RED,   LOW);

  doorServo.attach(PIN_SERVO);
  doorServo.write(0);

  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcdShow("  SMART DOOR    ", "  Khoi dong...  ");

  SPI.begin(18, 19, 23, PIN_RFID_SS);
  rfid.PCD_Init();
  Serial.println("[RFID] OK");

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  lcdShow("  Ket noi WiFi  ", "  ...           ");
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 30) {
    delay(500); Serial.print("."); retry++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] " + WiFi.localIP().toString());
    lcdShow("  WiFi OK!      ", "                ");
    configTime(25200, 0, "pool.ntp.org", "time.nist.gov");
  } else {
    lcdShow("  WiFi THAT BAI ", "  Kiem tra lai! ");
  }
  delay(500);

  fbConfig.database_url               = DATABASE_URL;
  fbConfig.signer.tokens.legacy_token = DB_SECRET;
  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);
  fbData.setResponseSize(4096);

  Serial.print("[Firebase] Cho ready");
  while (!Firebase.ready()) { delay(500); Serial.print("."); }
  Serial.println("\n[Firebase] READY");

  Firebase.setString(fbData, PATH_SYS_CMD, "idle");
  Firebase.setString(fbData, PATH_APP_CMD, "idle");
  Firebase.setInt   (fbData, PATH_DOOR_ST, 0);

  lastSysCmd = "idle";
  lastAppCmd = "idle";
  sysLocked  = false;
  doorOpen   = false;
  lastDoorStatusFromApp = 0;
  pendingOTPCheck = false;
  pendingOTPInput = "";

  String curOTP = fbGetStr(PATH_OTP);
  lastOTP = (curOTP.length() > 0) ? curOTP : "___NONE___";
  Serial.println("[BOOT] OTP cached=" + lastOTP);

  String apCfg = fbGetStr(PATH_ADMIN_PWD); if (apCfg.length() >= 4) adminPwd = apCfg;
  String dpCfg = fbGetStr(PATH_DOOR_PWD);  if (dpCfg.length() >= 4) doorPwd  = dpCfg;
  Serial.println("[CFG] admin=" + adminPwd + " door=" + doorPwd);

  delay(300);
  showIdle();
  beepOK();
  Serial.println("[BOOT] === SAN SANG ===");
}

// ---------------------------------------------------
// LOOP
// ---------------------------------------------------
void loop() {
  handleRFID();
  handleKeypad();
  handleAutoClose();
  handleLockCountdown();

  if (millis() - lastFbCheck >= FB_INTERVAL) {
    lastFbCheck = millis();
    if (Firebase.ready()) {
      checkPendingOTP();
      handleAppCommands();
    } else {
      Firebase.reconnectWiFi(true);
    }
  }
}
