// Reach — last-foot object guidance for blind and low-vision users.
// Phone camera finds the object + the user's hand; the ESP32 wrist buzzer
// beeps faster as the hand gets closer and holds a steady tone on target.
//
// Phone UI source: web/index.html (embedded via tools/embed_page.py)
// Board: "ESP32 Dev Module"   Libraries: Adafruit SSD1306 (+ Adafruit GFX)
// Wiring: OLED VCC->3V3 GND->GND SCL->D22 SDA->D21 | Active buzzer + ->D25, - ->GND

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#include "secrets.h"    // copy secrets.example.h -> secrets.h and fill in your hotspot
#include "page_html.h"  // generated from web/index.html by tools/embed_page.py

const int PIN_BUZZER = 25;
const unsigned long STALE_MS = 1000;  // silence buzzer if phone stops sending

Adafruit_SSD1306 oled(128, 64, &Wire, -1);
WebServer server(80);

int guideDist = -1;            // -1 = no guidance, 0 = on target, 1..100 = far
String targetName = "-";
unsigned long lastUpdateMs = 0;


// ------------------------------------------------------------------

void handleRoot() { server.send_P(200, "text/html", PAGE); }

void handleGuide() {
  if (!server.hasArg("d")) { server.send(400, "text/plain", "missing d"); return; }
  guideDist = constrain(server.arg("d").toInt(), -1, 100);
  if (server.hasArg("t")) targetName = server.arg("t");
  lastUpdateMs = millis();
  server.sendHeader("Access-Control-Allow-Origin", "*");  // allow the laptop-hosted page
  server.send(200, "text/plain", "ok");
}

int currentDist() {
  return (millis() - lastUpdateMs > STALE_MS) ? -1 : guideDist;
}

// Parking-sensor style: silent, then faster beeps as distance shrinks, steady tone on target.
void updateBuzzer() {
  int d = currentDist();
  bool on;
  if (d < 0) on = false;
  else if (d == 0) on = true;
  else {
    unsigned long period = map(d, 1, 100, 120, 900);
    on = (millis() % period) < 40;
  }
  digitalWrite(PIN_BUZZER, on ? HIGH : LOW);
}

void drawOled() {
  static unsigned long lastDraw = 0;
  if (millis() - lastDraw < 200) return;
  lastDraw = millis();

  int d = currentDist();
  oled.clearDisplay();
  oled.setTextColor(SSD1306_WHITE);
  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.print("REACH ");
  oled.print(WiFi.localIP());
  oled.setCursor(0, 14);
  oled.print("Target: ");
  oled.print(targetName);
  oled.setTextSize(2);
  oled.setCursor(0, 34);
  if (d < 0) oled.print("--");
  else if (d == 0) oled.print("GRAB IT");
  else { oled.print("Dist "); oled.print(d); }
  oled.display();
}

void halt(const char* msg) {
  Serial.println(msg);
  oled.clearDisplay();
  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.println(msg);
  oled.display();
  while (true) delay(1000);
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);

  if (!oled.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED not found at 0x3C - check SDA=21 SCL=22 wiring");
    while (true) delay(1000);
  }
  oled.clearDisplay();
  oled.setTextColor(SSD1306_WHITE);
  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.print("WiFi: ");
  oled.println(WIFI_SSID);
  oled.display();

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > 20000) halt("WiFi FAILED.\nCheck name/password\nand 2.4 GHz hotspot.");
    delay(250);
  }
  Serial.print("Open on phone: http://");
  Serial.println(WiFi.localIP());

  server.on("/", handleRoot);
  server.on("/g", handleGuide);
  server.begin();

  // Startup chirp so you know the buzzer works
  digitalWrite(PIN_BUZZER, HIGH); delay(100); digitalWrite(PIN_BUZZER, LOW);
}

void loop() {
  server.handleClient();
  updateBuzzer();
  drawOled();
}
