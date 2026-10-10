# MailCorrector

**AI proofreading for Apple Mail.** A native macOS Mail extension that polishes your
email drafts with OpenAI — fixing grammar, spelling, punctuation, and awkward phrasing
while preserving your original meaning, tone, and language.

Bring your own OpenAI API key. No accounts, no servers, no tracking — your key is stored
in the macOS Keychain and requests go directly to OpenAI.

---

## What it does

- Proofreads email text with OpenAI's `gpt-4o-mini` model.
- Corrects **grammar, spelling, punctuation, and clumsy phrasing**.
- **Preserves meaning, tone, register, and language** — it won't translate or rewrite your voice.
- Shows you the **original and corrected text side by side** so you review before applying.
- Stores your API key **securely in the macOS Keychain**, shared only with the extension.

### Example

**Before:**

> hi sara,
>
> i wanted too give you a quick update on were we are at with the projekt. the team have
> finished the first fase and we is now moving onto testing.
>
> can we schedule a call for thursday to discus the next steps? thanks alot.

**After:**

> Hi Sara,
>
> I wanted to give you a quick update on where we are with the project. The team has
> finished the first phase and we are now moving on to testing.
>
> Can we schedule a call for Thursday to discuss the next steps? Thank you.

---

## How it works

MailCorrector is a **MailKit compose extension** that appears as a button in Apple Mail's
compose window. When clicked, it opens a small panel that proofreads your text and shows
the corrected version.

### Why you copy and paste

Apple's MailKit does **not** give a compose extension access to the live draft you're
typing (the draft body is `nil` while composing, and there's no API to request it). So
instead of reading your draft directly, MailCorrector reads whatever text you've **copied
to the clipboard**. You paste the corrected result back yourself. It's one extra step, but
it's the only reliable way a Mail extension can work with your draft on current macOS.

---

## Requirements

- macOS 26 or later
- An [OpenAI API key](https://platform.openai.com/api-keys)
- Xcode 16 or later (to build from source)
- An Apple ID (a free account is enough to build and run locally)

---

## Setup

### 1. Add your OpenAI API key

1. Build and run the **MailCorrector** app (see *Build from source* below).
2. In the app window, paste your OpenAI API key and click **Save**.
   - The key is stored in your macOS Keychain and never written to disk in plain text.

### 2. Enable the extension in Mail

1. Open **Mail ▸ Settings ▸ Extensions**.
2. Turn on **MailCorrector**.
3. Restart Mail and open a compose window.

---

## Usage

1. Write (or open) an email in Mail's compose window.
2. Select your draft text and **copy it** (⌘A, then ⌘C).
3. Click the **MailCorrector** button in the compose window toolbar.
4. Click **Proofread**.
5. Review the **Original** vs **Corrected** text in the panel.
6. Click **Copy corrected text**, then paste (⌘V) back over your draft.

---

## Build from source

```bash
git clone https://github.com/lups2000/MailCorrector.git
cd MailCorrector
```

This project keeps personal signing values out of version control via an `.xcconfig`
file. Set up yours before building:

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig
```

Then edit `Config/Developer.xcconfig` and fill in:

```
DEVELOPMENT_TEAM = YOURTEAMID        // from Xcode > Settings > Accounts
BUNDLE_ID_PREFIX = com.yourname      // any reverse-DNS prefix you control
```

`Config/Developer.xcconfig` is gitignored, so your values stay local.

Open `MailCorrector.xcodeproj` in Xcode, make sure both targets have a signing **Team**
selected under *Signing & Capabilities*, and build & run the **MailCorrector** scheme.

---

## Privacy

- Your API key is stored in the **macOS Keychain** — never on disk as plain text.
- Email text is sent **directly to OpenAI** and nowhere else.
- No analytics, no telemetry, no data collection.

---

## Known limitations

- **Copy/paste required.** MailKit doesn't expose the live draft to the extension, so you
  copy your text in and paste the result back (see *How it works*).
- **macOS only.** This targets Apple Mail on macOS 26 and later.
- **Distribution needs signing.** Running the extension on another Mac requires the app to
  be signed and notarized (a paid Apple Developer Program membership). Building from source
  with a free Apple ID works for personal use.

---

## Project structure

```
MailCorrector/              Host app (API-key settings UI)
MailCorrectorExtension/     The MailKit compose extension
Shared/                     Shared code (OpenAI client, Keychain store)
Config/                     Build configuration (signing via xcconfig)
```

---

## License

See [LICENSE](LICENSE).
