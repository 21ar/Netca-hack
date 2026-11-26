# Reach 🖐️ — last-foot object guidance for blind users

> Say **"cup"**. Your phone camera finds the cup and your hand. A buzzer on your wrist
> **beeps faster as your hand gets closer** and holds a steady tone when you're on it,
> while your phone says **"left… forward… grab it."**

```
 Phone (camera + AI + voice)  ──Wi-Fi (phone hotspot)──►  ESP32 (wrist buzzer + OLED)
  • finds the object (MediaPipe object detector)            • beep rate = distance
  • tracks your hand (MediaPipe hand landmarks)             • steady tone = grab it
  • says the direction out loud                            • OLED shows status for judges
```

All the vision AI runs **on the phone**. The ESP32 hosts the web page and drives the buzzer.

---

## Repo layout

| Path | What it is | Who edits it |
|---|---|---|
| `firmware/Reach/Reach.ino` | ESP32 sketch: Wi-Fi, web server, buzzer, OLED | Hardware person |
| `firmware/Reach/secrets.example.h` | Template for the hotspot name and password. Copy it to `secrets.h` | Hardware person |
| `firmware/Reach/page_html.h` | **Generated** copy of the web page. Don't edit it by hand | — |
| `web/index.html` | Phone app: camera, AI, voice, guidance logic. **The single source of truth for the UI** | Coding person |
| `tools/embed_page.py` | Copies `web/index.html` into `page_html.h` | Coding person |

---

## ⏱️ Timeline (about 45 minutes)

| Time | 🔌 Hardware person (H) | 💻 Coding person (C) |
|---|---|---|
| 0–10 min | Wire the OLED and buzzer. Install Arduino IDE, the ESP32 board package and the library | Clone the repo. Turn on the phone hotspot (2.4 GHz). Start laptop dev mode |
| 10–20 min | Create `secrets.h`, upload the sketch, run the buzzer test | Test the page with the laptop webcam. Check that objects and your hand are detected |
| 20–30 min | Wrist mount, phone stand, power bank | Set the Chrome flag on the phone. Run it end to end on the phone |
| 30–40 min | Re-upload if C changed the page | Tune the thresholds. Rehearse the pitch |
| 40–45 min | **Full demo run-through together** | |

---

## 🔌 Hardware person (H)

### Parts (from the ESP32 Basic Starter Kit)
- ESP32 dev board and its micro-USB cable
- 0.96" OLED (I2C, 4 pins)
- **Active** buzzer: the sealed one with a sticker on top. The passive one has its circuit board showing underneath.
- Female-female and female-male jumper wires (use long ones for the buzzer so it reaches the wrist)

You don't need the relay, LEDs, joystick, Arduino shield, Pi, LCD or ultrasonic sensors. Unplug them so they can't cause problems.

### Wiring (USB unplugged while you wire)

| From | To ESP32 pin |
|---|---|
| OLED **VCC** | **3V3** |
| OLED **GND** | **GND** |
| OLED **SCL** | **D22** |
| OLED **SDA** | **D21** |
| Buzzer **+** (longer leg, or the side marked +) | **D25** |
| Buzzer **−** | **GND** |

Tip: the ESP32 is too wide for the breadboard. Push female-female jumpers straight onto its pins, and use a breadboard rail as the shared GND.

### Software setup (Windows laptop)
1. Install **Arduino IDE 2**.
2. Go to *File → Preferences → Additional boards manager URLs* and add
   `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
3. In *Boards Manager*, install **esp32 by Espressif Systems**.
4. In *Library Manager*, install **Adafruit SSD1306**. Click "Install all" so it also installs Adafruit GFX.
5. Create the secrets file. In the repo folder, run:
   ```
   copy firmware\Reach\secrets.example.h firmware\Reach\secrets.h
   ```
   Then put C's phone hotspot name and password in `secrets.h`. This file is git-ignored, so the password is never pushed.
6. Open `firmware/Reach/Reach.ino`. Choose board **ESP32 Dev Module** and the right **COM port**, then click **Upload**.
   - If the upload hangs on `Connecting....`, **hold the BOOT button** on the ESP32 until it starts writing.
7. Open the Serial Monitor at **115200** baud. Within a few seconds you should see:
   - a short beep from the buzzer
   - `REACH 192.168.x.x` on the OLED. **Tell C this IP address.**

### Buzzer test (no phone or AI needed)
On any device connected to the hotspot, open these addresses in a browser. Each one buzzes for about 1 second:
- `http://<IP>/g?d=90` → slow beeps (far away)
- `http://<IP>/g?d=10` → fast beeps (close)
- `http://<IP>/g?d=0` → steady tone (grab it)

If all three work, the hardware is done ✅

### Demo rig
- Tape the buzzer to the inside of the demo user's wrist with long jumper wires. Power the ESP32 from a **USB power bank** in a pocket, or from the laptop.
- Make a **phone stand**: prop the phone at chest height with the back camera looking down at the table, from the user's side. A stack of books or a box works fine. The camera should see the whole table area and the user's hand.

---

## 💻 Coding person (C)

### Setup
1. Clone the repo: `git clone git@github.com:21ar/Netca-hack.git`
2. Turn on your **phone hotspot and set it to 2.4 GHz**. On Samsung: *Hotspot → Configure → Band → 2.4 GHz*. Give H the name and password.
3. Connect the laptop to the same hotspot.

### Laptop dev mode (fastest way to iterate, no re-uploading)
The laptop can serve the page itself. `localhost` counts as a secure address, so the webcam works without any flags:
```
cd web
python -m http.server 8000
```
Open `http://localhost:8000/?esp=<ESP32 IP>` in Chrome.
- Edit `web/index.html`, then refresh the page. The buzzer still responds, because the ESP32 accepts requests from the laptop page.
- Before the ESP32 is ready, everything still works except the buzzer. You'll see a red "ESP32 not reachable" message, which is expected.

### Phone mode (the real demo)
A page served from the ESP32 is plain `http`, and Chrome blocks the camera on plain `http` by default. To allow it **once**:
1. In Chrome on the phone, open `chrome://flags`
2. Search for **"Insecure origins treated as secure"**
3. Enable it and type `http://<ESP32 IP>` in the box
4. Tap **Relaunch**
5. Open `http://<ESP32 IP>`, tap **Start camera** and allow camera access. The first load downloads the AI models (a few MB) over mobile data.

This needs **Android Chrome**; iPhone Safari has no such flag. If the IP changes, update the flag.
If you only have an iPhone, use laptop mode for the demo instead.

### Getting page changes onto the ESP32
```
python tools/embed_page.py      # web/index.html -> firmware/Reach/page_html.h
git add -A && git commit -m "page: ..." && git push
```
Then H runs `git pull` and clicks Upload again.

### Settings to tune (all in `web/index.html`)
| Setting | Where | Effect |
|---|---|---|
| `scoreThreshold: 0.35` | `ObjectDetector.createFromOptions` | Lower it (0.25) if the object isn't found. Raise it if the wrong thing gets picked |
| `TARGETS` / `ALIASES` | top of the script | Object buttons and spoken synonyms. Names must be COCO object labels, e.g. `cup`, `bottle`, `cell phone`, `remote`, `bowl`, `book`, `scissors`, `apple`, `banana`, `keyboard`, `mouse` |
| `* 150` in `guide()` | distance scale | Bigger number = beeps speed up sooner |
| `2500` in `say()` | speech repeat (ms) | How often the same direction is repeated |
| `left/right/forward/back` | `dir` line in `guide()` | Swap the words if the phone faces the opposite way |
| `map(d, 1, 100, 120, 900)` | `updateBuzzer()` in `Reach.ino` | Beep interval in ms, from closest to farthest (needs a re-upload) |

### How the guidance works
1. The object detector finds the target and **remembers its position**, because your hand often covers it while you reach.
2. The hand tracker follows the center of your palm (landmark 9).
3. Vector from palm to object → spoken direction along the bigger axis, plus a distance value from 1 to 100 sent to the ESP32 about 8 times a second.
4. Palm inside the object's box → distance 0 → steady tone and "Grab it".
5. If the phone stops sending for 1 second, the ESP32 goes silent, so it never gets stuck buzzing.

---

## 🎤 Demo script (2 minutes)

1. **Problem (20 s):** "About 43 million people are blind, and that's projected to reach 61 million by 2050.¹ Apps can tell you *there's a cup on the table*. None of them get your hand *to* the cup. So people sweep the table and knock things over."
2. **Live demo (60 s):** Put a cup and a bottle on the table. The demo user closes their eyes and taps **🎤** (or a button): "cup". The phone says "Cup found, reach out." They follow the beeps and voice and pick it up. **Then move the cup and do it again.**
3. **How it works (20 s):** On-device AI on the phone finds both the object and the hand. A $5 ESP32 gives feedback you can feel on your wrist. Nothing is uploaded to the cloud.
4. **What's next (20 s):** A vibration motor instead of a buzzer, a glasses-mounted camera, voice-only setup, and more object types (keys, medication bottles).

¹ Global Burden of Disease / Vision Loss Expert Group, *The Lancet Global Health*, 2021: 43.3 million people blind in 2020, 61 million projected by 2050.

**Before you present:** check the phone battery, turn on mobile data for the first model download, turn the phone volume up, and make sure the table is well lit and plain (no clutter behind the cup).

---

## 🧯 Troubleshooting

| What you see | Fix |
|---|---|
| OLED stays blank and Serial says `OLED not found` | Check that SDA→D21 and SCL→D22 aren't swapped, and that VCC goes to **3V3** |
| OLED says `WiFi FAILED` | Wrong name or password in `secrets.h`, or the hotspot is on 5 GHz. Switch it to 2.4 GHz |
| Upload gets stuck at `Connecting...` | Hold **BOOT** while it connects. Try another USB cable, since some only carry power |
| `secrets.h: No such file` when compiling | You skipped step 5 of the hardware setup |
| `Start failed: camera blocked on http` | Set up the Chrome flag (Phone mode, steps 1–4) |
| `Start failed: ... fetch` or the models never load | The phone has no internet. Turn on mobile data |
| Red "ESP32 not reachable" | The phone or laptop isn't on the same hotspot, the IP is wrong, or the ESP32 is unpowered |
| The object is never found | Use better light and a plain background. Lower `scoreThreshold`. Cups and bottles are detected most reliably |
| Directions are mirrored | Swap `left`/`right` (and `forward`/`back`) in `guide()` |
| No sound from the buzzer | You've used the **passive** buzzer by mistake, or + and − are swapped |
