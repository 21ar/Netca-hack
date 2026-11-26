# Reach 🖐️ — last-foot object guidance for blind users

> Hold your phone against your reaching arm like a "wrist eye" and say **"cup"**.
> A buzzer on your hand **beeps faster as you aim at the cup and get closer**, and holds
> a steady tone when it's within reach, while the phone says **"left… up… forward… grab it."**

```
 Phone (camera + AI + voice)  ──Wi-Fi (phone hotspot)──►  ESP32 (wrist buzzer + OLED)
  • hears the object name (phone mic)                      • beep rate = warmer / colder
  • finds the object (MediaPipe object detector)            • steady tone = grab it
  • says the direction out loud                            • OLED shows status for judges
```

All the vision AI runs **on the phone**. The ESP32 hosts the web page and drives the buzzer.

**How the phone is held:** upright against the inside of the reaching forearm, near the wrist, with the screen facing you and the back camera pointing where your hand is going. Hold it there with your other hand. Because the camera moves with your arm:
- **Object in the middle of the picture** = your arm is pointing at it
- **Object getting bigger in the picture** = your hand is getting closer

---

## Repo layout

| Path | What it is | Who edits it |
|---|---|---|
| `firmware/Reach/Reach.ino` | ESP32 sketch: Wi-Fi, web server, buzzer, OLED | Hardware person |
| `firmware/Reach/secrets.example.h` | Template for the hotspot name and password. `tools/setup.ps1` creates `secrets.h` from your answers | — |
| `tools/setup.ps1`, `tools/flash.ps1` | One-time laptop setup, then upload and serial monitor | Hardware person |
| `firmware/Reach/page_html.h` | **Generated** copy of the web page. Don't edit it by hand | — |
| `web/index.html` | Phone app: camera, AI, voice, guidance logic. **The single source of truth for the UI** | Coding person |
| `tools/embed_page.py` | Copies `web/index.html` into `page_html.h` | Coding person |

---

## ⏱️ Timeline (about 45 minutes)

| Time | 🔌 Hardware person (H) | 💻 Coding person (C) |
|---|---|---|
| 0–10 min | Wire the OLED and buzzer. Run `tools\\setup.ps1` while you wire | Clone the repo. Turn on the phone hotspot (2.4 GHz). Start laptop dev mode |
| 10–20 min | Run `tools\\flash.ps1`, then the buzzer test | Test the page with the laptop webcam. Check that a cup or bottle is detected |
| 20–30 min | Tape the buzzer to the hand, ESP32 and power bank in a pocket | Set the Chrome flag on the phone. Run it end to end on the phone |
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

**New to hardware?**
- The pin names are printed on the ESP32 next to each pin. Depending on the board, the same pin may be labelled `D21`, `G21`, `IO21` or just `21`. **3V3** may say `3.3V`. Any `GND` pin works.
- Wire everything **before** plugging in USB. If something gets hot or smells, unplug it immediately.
- The OLED pins are labelled on the OLED itself. Their order (GND/VCC/SCL/SDA) differs between boards, so go by the labels, not by position.

Tip: the ESP32 is too wide for the breadboard. Push female-female jumpers straight onto its pins, and use a breadboard rail as the shared GND.

### Software setup (Windows laptop, scripted)
No Arduino IDE needed. Open **PowerShell** and paste:
```powershell
cd ~; if (!(Test-Path Netca-hack)) { git clone git@github.com:21ar/Netca-hack.git }; cd Netca-hack; git pull; powershell -ExecutionPolicy Bypass -File tools\setup.ps1
```
This downloads arduino-cli, installs ESP32 support and the OLED library, asks for the **hotspot name and password** (saved to the git-ignored `secrets.h`), and test-compiles. It takes about 5–10 minutes, mostly downloading.

Then **plug the ESP32 in by USB** and run:
```powershell
powershell -ExecutionPolicy Bypass -File tools\flash.ps1
```
This uploads the firmware and opens the serial monitor. Re-run it after any code change.
- If the upload hangs on `Connecting....`, **hold the BOOT button** on the ESP32 until it starts writing.
- **It worked if** you hear a short beep and the OLED shows `REACH 192.168.x.x`. The monitor also prints `Open on phone: http://...`. **Tell C this IP address.**

### Buzzer test (no phone or AI needed)
On any device connected to the hotspot, open these addresses in a browser. Each one buzzes for about 1 second:
- `http://<IP>/g?d=90` → slow beeps (far away)
- `http://<IP>/g?d=10` → fast beeps (close)
- `http://<IP>/g?d=0` → steady tone (grab it)

If all three work, the hardware is done ✅

### Demo rig
- Tape the buzzer to the **back of the reaching hand**, using long jumper wires back to the ESP32.
- Power the ESP32 from a **USB power bank** in a pocket. If you don't have one, use the laptop with a long USB cable.
- Practise the phone position: upright against the reaching forearm, screen toward you, back camera pointing forward. Your other hand holds it there.

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
Then H runs `git pull` and `tools\\flash.ps1` again.

### Settings to tune (all in `web/index.html`)
| Setting | Where | Effect |
|---|---|---|
| `SCORE_THRESHOLD = 0.35` | tuning block at the top | Lower it (0.25) if the object isn't found. Raise it if the wrong thing gets picked |
| `GRAB_SIZE = 0.55` | tuning block | How much of the picture the object must fill before "grab it". Lower = says it earlier |
| `CENTER_ZONE = 0.15` | tuning block | Size of the "aimed" zone (yellow box on screen). Bigger = easier to aim |
| `TARGETS` / `ALIASES` | top of the script | Object buttons and spoken synonyms. Names must be COCO object labels, e.g. `cup`, `bottle`, `cell phone`, `remote`, `bowl`, `book`, `scissors`, `apple`, `banana`, `keyboard`, `mouse` |
| `REPEAT_MS = 2500` | tuning block | How often the same spoken direction is repeated |
| `left/right`, `up/down` | `dir` line in `guide()` | Swap the words if the directions come out backwards |
| `map(d, 1, 100, 120, 900)` | `updateBuzzer()` in `Reach.ino` | Beep interval in ms, from closest to farthest (needs a re-upload) |

### How the guidance works
1. You tap the big orange button and say an object. Chrome's speech recognition turns it into a label, such as "cup".
2. Every frame, the object detector looks for that label. The camera sits on your arm, so the object's position in the picture shows where your arm is pointing.
3. **Object off-center** → "left", "right", "up" or "down". **Object centered** → "forward".
4. **Object centered and filling at least `GRAB_SIZE` of the picture** → distance 0 → steady tone and "Grab it".
5. Buzzer: one "warmer/colder" number from 1 to 100, sent about 8 times a second. It gets smaller (faster beeps) as the object gets more centered and bigger.
5. If the phone stops sending for 1 second, the ESP32 goes silent, so it never gets stuck buzzing.

---

## 🎤 Demo script (2 minutes)

1. **Problem (20 s):** "About 43 million people are blind, and that's projected to reach 61 million by 2050.¹ Apps can tell you *there's a cup on the table*. None of them get your hand *to* the cup. So people sweep the table and knock things over."
2. **Live demo (60 s):** Put a cup and a bottle on the table, about an arm's length away. The demo user closes their eyes, holds the phone against their forearm, taps **🎤** and says "cup". They sweep their arm slowly until the phone says "cup found", then follow the beeps and the voice ("left… forward… grab it") and pick up the cup. **Then move the cup and do it again.**
3. **How it works (20 s):** On-device AI on the phone acts as an eye on your arm. A $5 ESP32 turns "how close" into beeps on your hand. Nothing is uploaded to the cloud.
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
| `secrets.h: No such file` when compiling | Run `tools\\setup.ps1`. It creates the file |
| `Start failed: camera blocked on http` | Set up the Chrome flag (Phone mode, steps 1–4) |
| `Start failed: ... fetch` or the models never load | The phone has no internet. Turn on mobile data |
| Red "ESP32 not reachable" | The phone or laptop isn't on the same hotspot, the IP is wrong, or the ESP32 is unpowered |
| The object is never found | Use better light and a plain background. Lower `scoreThreshold`. Cups and bottles are detected most reliably |
| Directions are backwards | Swap `left`/`right` (or `up`/`down`) in the `dir` line of `guide()` |
| It says "grab it" too early or too late | Change `GRAB_SIZE` |
| It keeps losing the object up close | Up close the cup fills the whole picture, so the AI can't tell what it is. Lower `GRAB_SIZE` (try 0.45) |
| No sound from the buzzer | You've used the **passive** buzzer by mistake, or + and − are swapped |
