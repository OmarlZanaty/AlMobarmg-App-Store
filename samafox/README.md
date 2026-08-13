# SamaFox — product page for the Al Mobarmg store

An App-Store-style product page for **SamaFox** (`com.almobarmg.samafox`), with a
download button that runs the Google Play **closed-testing activation flow**.

## Drop-in

Copy this folder into your site as `samafox/`:

```
your-site/
└─ samafox/
   ├─ index.html          ← the page (self-contained CSS + JS)
   ├─ samafox-logo.png    ← app icon, taken from the app's own assets
   └─ shots/              ← screenshots: 1.png … 5.png (portrait 9:19.5)
```

Then it's live at `your-site/samafox/`. No build step, no framework, no CDN
except the Cairo webfont and Google's sign-in script.

Everything is namespaced (`.sf-` for the page, `.act-` for the modal) so it will
not collide with your existing stylesheet.

## Where the download button lives

Two positions, **one** button:

- **Hero** — the primary CTA next to the icon, where the App Store puts GET.
- **Sticky bottom bar** — appears on mobile once the hero scrolls away.

Both carry `class="js-play-activate" data-app="samafox"`. That class is the only
wiring needed — add it to any other element and it opens the same modal.

**Do not link anywhere else straight to Play.** A closed-test app 404s on the
Play *website* and is invisible in the store app to anyone not on the tester
list, so every direct link is a "item not available" report. Point the store
grid card, the homepage and social bios at *this page* instead.

## Configure

Top of the `<script>` block in `index.html`:

| Key | Value |
| --- | --- |
| `API_BASE` | `https://api.cairoshuttle-bus.com` — the backend that owns the beta enrollment endpoints. |
| `GOOGLE_CLIENT_ID` | `''` by default → the typed-email field (the reliable path). See below to enable the one-tap picker. |
| `WHATSAPP` | Support number shown if activation stalls. |

### Optional: the one-tap Google account picker

Leaving `GOOGLE_CLIENT_ID` empty is a deliberate default — the picker fails
*silently* on an origin Google doesn't recognise, which looks like a broken
button. To turn it on:

1. Google Cloud → APIs & Services → Credentials → the OAuth **Web** client.
2. Add this page's HTTPS origin to **Authorized JavaScript origins**
   (e.g. `https://almobarmg.com`). A bare IP or plain HTTP is rejected by Google.
3. Paste the client ID into `CONFIG.GOOGLE_CLIENT_ID`.

The typed-email field keeps working either way, and is the *only* path inside
in-app browsers (WhatsApp, Instagram, Facebook) — Google blocks its sign-in UI
there, which is exactly where most shared links get opened.

## ⚠️ The one Play Console step this depends on

The flow enrolls the visitor's address into the **`csb-web`** email list. That
list is **account-level** in Play Console — one list, shared by every app on the
developer account (this is why Cairo Shuttle Bus's customer and captain apps
both work off a single sync pass).

So this page works **only if**:

1. SamaFox is published under the **same Play Console developer account** as
   Cairo Shuttle Bus. The shared `com.almobarmg.*` namespace strongly suggests it
   is — but a namespace is not proof, so check.
2. SamaFox's **closed-testing track → Testers** is pointed at the **`csb-web`**
   email list (not a different list, and not individually-typed emails).

If SamaFox lives on a *different* developer account, it needs its own list and
its own entry in the desktop daemon's `apps` array in `infra/beta-sync/sync.js`
— the code already anticipates a per-app `listName`, but the current config
carries only one.

## What still needs your input

- **Screenshots.** `shots/1.png` … `shots/5.png`. Missing files fall back to a
  styled placeholder, so the page never shows a broken image — but it does look
  unfinished until they're in.
- **Description and feature copy.** Written as a first draft from the app's own
  feature set (voice rooms, mic seats, gifts, frames, relations, follow). Read it
  and make it yours.
- **No star rating is shown** — the app is in closed testing and has no public
  Play rating, and inventing one on your own store page would be a lie. The first
  meta cell says "NEW / Beta" instead; swap it for a real rating once Play
  reports one.

## Behaviour worth knowing

- Timings are wall-clock, not a decrementing counter — a phone that backgrounds
  the tab throttles timers, and the flow catches up when the user returns.
- On Android the page never auto-launches Play on a timer: Chrome only hands off
  to another app on a fresh tap, so the handoff is spent on the user's own tap of
  the "افتح Google Play" button, which opens the store app directly.
- If the desktop sync daemon is down, the backend reports `delayed` and the page
  says so immediately rather than spinning for 90 seconds first.
- If Play refuses an address (not a Google account), the page says so and lets
  the user try another instead of waiting forever.
