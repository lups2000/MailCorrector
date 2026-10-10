# MailCorrector

**AI writing assistant for Apple Mail.** A native macOS Mail extension that proofreads and
rewrites your email text with the AI provider and model of your choice — fixing grammar,
changing tone, adjusting length, translating, or applying your own custom instruction.

Bring your own API key. No accounts, no servers, no tracking — your key is stored in the
macOS Keychain and requests go directly to the provider you choose.

---

## What it does

Give it some email text and pick an action:

- **Proofread** — fix grammar, spelling, punctuation, and awkward phrasing while keeping
  your meaning, tone, and language.
- **Rewrite the tone** — Professional, Friendly, or Casual.
- **Change the length** — make it more Concise or Expand it.
- **Translate** into one of several languages.
- **Describe a change** — type any custom instruction (e.g. "make it more apologetic").

Other highlights:

- **Multiple AI providers** — OpenAI, Anthropic (Claude), Google Gemini, and OpenRouter,
  each with a choice of models from cheapest to highest quality.
- **See and edit the text first** — the panel shows the text it will transform (seeded from
  your clipboard) so you can review or tweak it before sending.
- **Review before applying** — shows the original and the result side by side, then you copy
  the result back into your draft.
- **Secure, local key storage** — each provider's API key is stored in the macOS Keychain,
  shared only with the extension.

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
- An API key from a supported provider — [OpenAI](https://platform.openai.com/api-keys),
  [Anthropic](https://console.anthropic.com/settings/keys),
  [Google Gemini](https://aistudio.google.com/apikey), or
  [OpenRouter](https://openrouter.ai/keys)
- Xcode 16 or later (to build from source)
- An Apple ID (a free account is enough to build and run locally)

---

## Setup

### 1. Choose a provider and add your API key

1. Build and run the **MailCorrector** app (see *Build from source* below).
2. Pick your **Provider** (OpenAI, Anthropic, Gemini, or OpenRouter) and a **Model**.
3. Paste that provider's API key and click **Save**.
   - Each provider's key is stored in your macOS Keychain and never written to disk in
     plain text. You can save keys for several providers and switch between them anytime.

### 2. Enable the extension in Mail

1. Open **Mail ▸ Settings ▸ Extensions**.
2. Turn on **MailCorrector**.
3. Restart Mail and open a compose window.

---

## Usage

1. Write (or open) an email in Mail's compose window.
2. Select your draft text and **copy it** (⌘A, then ⌘C).
3. Click the **MailCorrector** button in the compose window toolbar.
4. Review (or edit) the text shown in the panel, then choose an action — **Proofread**,
   a tone (**Professional / Friendly / Casual**), length (**Concise / Expand**),
   **Translate**, or type your own instruction under **Describe a change**.
5. Review the **Original** vs **Result** text in the panel.
6. Click **Copy result**, then paste (⌘V) back over your draft.

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
- Email text is sent **directly to the AI provider you choose** and nowhere else.
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
MailCorrector/              Host app (provider, model, and API-key settings UI)
MailCorrectorExtension/     The MailKit compose extension
Shared/                     Shared code (AI client, providers, Keychain, preferences)
Config/                     Build configuration (signing via xcconfig)
```

---

## License

See [LICENSE](LICENSE).
