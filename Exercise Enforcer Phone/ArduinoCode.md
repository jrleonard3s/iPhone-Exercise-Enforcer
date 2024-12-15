#include <Arduino.h>


#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

#include<WiFi.h>

#include "PinDefinitionsAndMore.h"
#include <IRremote.hpp>

#if !defined(ARDUINO_ESP32C3_DEV) // This is due to a bug in RISC-V compiler, which requires unused function sections :-(.
#define DISABLE_CODE_FOR_RECEIVER // Disables static receiver code like receive timer ISR handler and static IRReceiver and irparams data. Saves 450 bytes program memory and 269 bytes RAM if receiving functions are not required.
#endif

#define IR_SEND_PIN 4

// BLE MAC address of my Heart Rate Monitor
static String HrmMacAddress("ec:dd:42:96:26:c3");

//WIFI & Volume server info
const char* ssid = "V!";
const char* password =  "passwordistaco";
 
const uint16_t port = 8000;
const char * host = "10.0.0.117";

// Heart Rate Monitoring service
static BLEUUID serviceUUID((uint16_t)0x180D);
// Heart Rate characteristic
static BLEUUID charUUID((uint16_t)0x2A37);
static boolean connected = false;
static BLERemoteCharacteristic *pRemoteCharacteristic;
// Bluetooth Scan
BLEScan *pBLEScan;
const int SCAN_TIME = 5;

#define BUZZER_PIN 19
#define MIN_HEART_RATE TARGET_ZONE_1
#define MAX_HEART_RATE TARGET_ZONE_MAX
#define HR_THRESHOLD_BUFFER 10

#define TEST_MODE 0
#if TEST_MODE
  const uint TARGET_ZONE_MAX = 130;
  const uint TARGET_ZONE_0 = 0;
  const uint TARGET_ZONE_1 = 80;
  const uint TARGET_ZONE_2 = 90;
  const uint TARGET_ZONE_3 = 100;
  const uint TARGET_ZONE_4 = 110;
  const uint TARGET_ZONE_5 = 120;
  const bool DISABLE_IR = true;
  const bool DISABLE_BUZZER = true;
  const bool DISABLE_MUTE = true;
#else
  const uint TARGET_ZONE_MAX = 187;
  const uint TARGET_ZONE_0 = 0;
  const uint TARGET_ZONE_1 = uint(TARGET_ZONE_MAX * 0.5);
  const uint TARGET_ZONE_2 = uint(TARGET_ZONE_MAX * 0.6);
  const uint TARGET_ZONE_3 = uint(TARGET_ZONE_MAX * 0.7);
  const uint TARGET_ZONE_4 = uint(TARGET_ZONE_MAX * 0.8);
  const uint TARGET_ZONE_5 = uint(TARGET_ZONE_MAX * 0.9);
  const bool DISABLE_IR = false;
  const bool DISABLE_BUZZER = false;
  const bool DISABLE_MUTE = false;
#endif

#define DEBUG 0    // SET TO 0 OUT TO REMOVE TRACES

#if DEBUG
  #define D_printf(...)    Serial.printf(__VA_ARGS__)
  #define D_print(...)    Serial.print(__VA_ARGS__)
  #define D_println(...)    Serial.println(__VA_ARGS__)
#else
  #define D_printf(...)
  #define D_print(...)
  #define D_println(...)
#endif
 

#define IR_HDMI_1  0x2
#define IR_HDMI_2  0x4
#define IR_HDMI_3  0x6

#define IR_LED_PIN 4

#define RGB_LED_RED_PIN 18
#define RGB_LED_GREEN_PIN 15
#define RGB_LED_BLUE_PIN 2

const byte PWM_CHNS[] = {0, 1, 2}; //define the pwm channels

#define IR_REPEATS 10

byte progressBarPins[] = {23, 22, 32, 33, 25, 26, 27, 14, 12, 13};
int progressBarCount;



unsigned long lastPassSeconds = 0;
unsigned long lastFailSeconds = 0;
uint lastFailHeartRate = 0;

int goalMinutes = 40;
int goalSeconds = goalMinutes * 60;
int goalMillis = goalSeconds * 1000;
int millisInTargetZone = 0;

uint current_heart_rate = 0;
uint current_heart_rate_zone = 0;

bool finishedWithWorkout = false;

enum FeedbackColor { GREY, BLUE, GREEN, YELLOW, ORANGE, RED };

typedef struct { 
  uint heart_rate_floor;
  FeedbackColor led_color;
  float effort_multiplier;
} HeartRateZone;

const HeartRateZone heartRateZones[]{
  {TARGET_ZONE_0, FeedbackColor::RED , 0.0},
  {TARGET_ZONE_1, FeedbackColor::GREY , 0.5},
  {TARGET_ZONE_2, FeedbackColor::BLUE , 1.0},
  {TARGET_ZONE_3, FeedbackColor::GREEN , 2.0},
  {TARGET_ZONE_4, FeedbackColor::YELLOW , 2.0},
  {TARGET_ZONE_5, FeedbackColor::ORANGE , 1.0},
  {TARGET_ZONE_MAX, FeedbackColor::RED , 0.0},
};

const int heartRateZonesCount = sizeof(heartRateZones)/sizeof(heartRateZones[0]);

void setup() {
  Serial.begin(115200);
  while (!Serial)
        ; // Wait for Serial to become available. Is optimized away for some cores.
  D_println("Starting Board...");
  Serial.printf("Target Heart Rate Zones\n1: %d, 2: %d, 3: %d, 4: %d, 5: %d, Max: %d\n", TARGET_ZONE_1, TARGET_ZONE_2, TARGET_ZONE_3, TARGET_ZONE_4, TARGET_ZONE_5, TARGET_ZONE_MAX);

  BLEDevice::init("");

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    D_println("...");
  }
  D_print("WiFi connected with IP: ");
  D_println(WiFi.localIP());

  IrSender.begin(false, IR_LED_PIN); // Start with IR_SEND_PIN -which is defined in PinDefinitionsAndMore.h- as send pin and enable feedback LED at default feedback LED pin
  // setup progress bar
  progressBarCount = sizeof(progressBarPins);
  for (int i = 0; i <progressBarCount; i++){
    pinMode(progressBarPins[i], OUTPUT);
  }
  // setup other GPIO pins
  pinMode(BUZZER_PIN, OUTPUT);
  
  ledcAttachChannel(RGB_LED_RED_PIN, 1000, 8, PWM_CHNS[0]);
  ledcAttachChannel(RGB_LED_GREEN_PIN, 1000, 8, PWM_CHNS[1]);
  ledcAttachChannel(RGB_LED_BLUE_PIN, 1000, 8, PWM_CHNS[2]);
}

void loop() {
  if(finishedWithWorkout){
    celebrateProgressBar();
    return;
  }
  if(millisInTargetZone >= goalMillis){
    //celebrate!!
    finishedWithWorkout = true;
    rewardUser();
  }
  else{
    updateEnforcer();
    updateProgressBar();
    printScoreboard();
  }
  if (!connected) {
    // try to reconnect
    if(connectToServer()){
      Serial.println(" - Reconnected to BLE Server");
    }
    else{
      Serial.println("BLE Server failed to connect.");
    }
  }

  delay(1000);  // Delay between loops
}

void printScoreboard(){
  int time_remaining_seconds = (goalMillis - millisInTargetZone)/1000;

  //Clear the console
  Serial.printf("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");

  //Print Heart Rate
  Serial.printf("\t      HEART RATE\n\t\t%d bpm\n\n", current_heart_rate);

  //Print Heart Rate Zone Graphic
  Serial.println("\t\t ZONE\n");
  Serial.println("  0      1      2      3      4      5     MAX");
  for(int i = 0; i < current_heart_rate_zone; i ++){
    Serial.printf("[   ]  ");
  }
  
  Serial.printf("[XXX]  ", current_heart_rate_zone);
  for(int i = current_heart_rate_zone + 1; i < heartRateZonesCount; i ++){
    Serial.printf("[   ]  ");
  }
  Serial.println("");

  for(int i = 0; i<heartRateZonesCount ; i++){
    Serial.printf(" %1.1f   ", heartRateZones[i].effort_multiplier);
  }
  Serial.println("");

  Serial.printf("\n\t   EFFORT MULTIPLIER\n\t\t%.2f\n\n", heartRateZones[current_heart_rate_zone].effort_multiplier);

  Serial.printf("\t   WORKOUT PROGRESS\nPercent Finished: %.2f%% -- Time Remaining: %d:%02d", getPercentComplete() * 100, time_remaining_seconds / 60, time_remaining_seconds % 60);
  Serial.printf("\n\n");
  Serial.flush();
}

void updateEnforcer(){
  // Has been passing for >= HR_THRESHOLD_BUFFER/3 seconds
  // Making the pass criteria shorter than the fail so the positive feedback happens quickly
  if(lastPassSeconds >= lastFailSeconds + int(HR_THRESHOLD_BUFFER/3))
  {
    rewardUser();
  }
  // Has been failing for >= HR_THRESHOLD_BUFFER seconds
  else if(lastFailSeconds >= lastPassSeconds + HR_THRESHOLD_BUFFER)
  {
    punishUser();
  }
}

void updateProgressBar(){
  int currProgress  = calculateProgressBar();
  // All finished
  if(currProgress >= progressBarCount){
    for(int i = 0; i < progressBarCount ; i++){
      digitalWrite(progressBarPins[i], i < currProgress ? HIGH : LOW );
    }    
    return;
  }
  // Still working
  // -- clear everything
  for(int i = 0; i < progressBarCount ; i++){
    digitalWrite(progressBarPins[i], i < LOW );
  }
  // -- light up finished segments
  for(int i = 0; i < currProgress ; i++){
    digitalWrite(progressBarPins[i], HIGH );
  }
  // -- blink upcoming segment
  digitalWrite(progressBarPins[currProgress], HIGH);
  delay(100);
  digitalWrite(progressBarPins[currProgress], LOW);
}

void celebrateProgressBar(){
  for(int i = 0; i < progressBarCount ; i++){
    digitalWrite(progressBarPins[i], HIGH);
    delay(100);
    digitalWrite(progressBarPins[i], LOW);
  }
}

class MyClientCallback : public BLEClientCallbacks {
  void onConnect(BLEClient *pclient) {}

  void onDisconnect(BLEClient *pclient) {
    connected = false;
    Serial.println("disconnected from heart rate monitor");
  }
};

BLEAdvertisedDevice getHrmDevice(){
  while(true){
    pBLEScan = BLEDevice::getScan();

    Serial.println("Scanning...");
    pBLEScan->setActiveScan(true);

    BLEScanResults *foundDevices = pBLEScan->start(SCAN_TIME, false);
    D_println("Scan Completed");
    D_printf("Found %d devices\n", foundDevices->getCount());
    for (int i = 0; i < foundDevices->getCount(); i++) {
      String tempName = foundDevices->getDevice(i).getName().c_str();
      if (foundDevices->getDevice(i).getAddress().toString() == HrmMacAddress) {
        return foundDevices->getDevice(i);
      }
    }
  }
}

bool connectToServer() {
  D_print("Connecting to ");
  D_println(HrmMacAddress);

  BLEClient *pClient = BLEDevice::createClient();
  D_println(" - Created client");

  pClient->setClientCallbacks(new MyClientCallback());

  BLEAdvertisedDevice myDevice = getHrmDevice();
  // Connect to the remove BLE Server.
  pClient->connect(&myDevice);  // if you pass BLEAdvertisedDevice instead of address, it will be recognized type of peer device address (public or private)
  Serial.println(" - Connected to heart rate monitor");
  pClient->setMTU(517);  //set client to request maximum MTU from server (default is 23 otherwise)

  // Obtain a reference to the service we are after in the remote BLE server.
  BLERemoteService *pRemoteService = pClient->getService(serviceUUID);
  if (pRemoteService == nullptr) {
    Serial.print("Failed to find our service UUID: ");
    Serial.println(serviceUUID.toString().c_str());
    pClient->disconnect();
    return false;
  }
  D_println(" - Found our service");

  // Obtain a reference to the characteristic in the service of the remote BLE server.
  pRemoteCharacteristic = pRemoteService->getCharacteristic(charUUID);
  if (pRemoteCharacteristic == nullptr) {
    Serial.print("Failed to find our characteristic UUID: ");
    Serial.println(charUUID.toString().c_str());
    pClient->disconnect();
    return false;
  }
  D_println(" - Found our characteristic");

  // Read the value of the characteristic.
  if (pRemoteCharacteristic->canRead()) {
    String value = pRemoteCharacteristic->readValue();
    D_print("The characteristic value was: ");
    D_println(value.c_str());
  }

  if (pRemoteCharacteristic->canNotify()) {
    pRemoteCharacteristic->registerForNotify(notifyCallback);
  }

  connected = true;
  return true;
}

static void notifyCallback(BLERemoteCharacteristic *pBLERemoteCharacteristic, uint8_t *pData, size_t length, bool isNotify) {
  uint16_t heart_rate_measurement = pData[1];
    if (pData[0] & 1) {
        heart_rate_measurement += (pData[2] << 8);
    }
  uint heartRateInt = uint(heart_rate_measurement);
  D_printf("Heart Rate: %d\n", heartRateInt);
  current_heart_rate = heartRateInt;
  current_heart_rate_zone = calculateHrZone(heartRateInt);

  updateHeartRateHistory(heartRateInt);
  updateFeedbackLed();
}
unsigned long lastUpdateMillis = 0;

static void updateHeartRateHistory(uint heartRate){
  unsigned long currMillis = millis();
  if(heartRate > MIN_HEART_RATE && heartRate < MAX_HEART_RATE){
    // update last passed time
    lastPassSeconds = currMillis / 1000;
    // update total pass time
    millisInTargetZone += (currMillis - lastUpdateMillis) * heartRateZones[current_heart_rate_zone].effort_multiplier;
    warnUser(false);
  }
  else {
    lastFailSeconds = currMillis / 1000;
    lastFailHeartRate = heartRate;
    warnUser(true);
  }
  lastUpdateMillis = currMillis;
}

void warnUser(bool enable){
  // don't warn if we're already finished
  if(finishedWithWorkout){
    digitalWrite(BUZZER_PIN, LOW);
  }
  else{
    digitalWrite(BUZZER_PIN, enable && !DISABLE_BUZZER ? HIGH : LOW);
  }
}

void rewardUser(){
  // Choose good input
  selectHdmiChannel(IR_HDMI_1);
  sendMute(false);
}

void punishUser(){
  // Choose bad input
  D_printf("Punish user\n");
  selectHdmiChannel(IR_HDMI_2);
  sendMute(true);
}

void updateFeedbackLed(){
  switch(heartRateZones[current_heart_rate_zone].led_color){
    case BLUE:
      setRgbLed(0,0,255);
    case GREEN:
      setRgbLed(0,255,0);
      break;
    case GREY:
      setRgbLed(10,10,10);
      break;
    case ORANGE:
      setRgbLed(255,102,0);
      break;
    case RED:
      setRgbLed(255,0,0);
      break;
    case YELLOW:
      setRgbLed(255,255,0);
      break;
    default:
      setRgbLed(255,255,255);
      break;
  }
}

uint calculateHrZone(uint heartRate){
  if(heartRate > TARGET_ZONE_MAX){
    return 6;
  }
  if(heartRate >= TARGET_ZONE_5){
    return 5;
  }
  if(heartRate >= TARGET_ZONE_4){
    return 4;
  }
  if(heartRate >= TARGET_ZONE_3){
    return 3;
  }
  if(heartRate >= TARGET_ZONE_2){
    return 2;
  }
  if(heartRate >= TARGET_ZONE_1){
    return 1;
  }
  return 0;
}

void setRgbLed(byte r, byte g, byte b){
  ledcWrite(RGB_LED_RED_PIN, 255 - r);
  ledcWrite(RGB_LED_GREEN_PIN, 255 - g);
  ledcWrite(RGB_LED_BLUE_PIN, 255 - b);
}

void selectHdmiChannel(int ir_hdmi_address){
  D_printf("Sending IR: %x\n", ir_hdmi_address);
  if(!DISABLE_IR){
    IrSender.sendNEC(0x80, ir_hdmi_address, IR_REPEATS);
  }
}

// Calculate how many lights to light up on the progress bar
static int calculateProgressBar()
{
  return min(int(getPercentComplete() * progressBarCount), progressBarCount);
}

static float getPercentComplete(){
  return float(millisInTargetZone) / goalMillis;
}

bool sendMute(bool mute){
  WiFiClient client;
 
  D_println("Connecting to volume server...");
  if (!client.connect(host, port)) {

      Serial.println("Connection to volume server failed");

      delay(1000);
      return false;
  }
  D_printf("Sending %s\n", mute ? "mute" : "unmute");
  if(!DISABLE_MUTE){
    client.print(mute ? "mute" : "unmute");
  }

  D_println("Disconnecting...");
  client.stop();
  return true;
}
