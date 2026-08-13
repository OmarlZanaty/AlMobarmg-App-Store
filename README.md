# Al Mobarmg — App Store

Static product pages for Al Mobarmg's apps, in the style of an App Store
listing. No build step: each app is a folder of plain HTML/CSS/JS that can be
served from anywhere, or dropped into the existing site.

```
samafox/    SamaFox — social voice chat (com.almobarmg.samafox)
```

## Adding an app

Copy an existing folder and edit it. Each page is self-contained and namespaces
its CSS, so pages never collide with each other or with a host site's styles.

## Download buttons

Apps distributed through Google Play **closed testing** cannot use a plain link:
a closed-test app 404s on the Play website and is invisible in the store app to
anyone who isn't on the tester list. Those pages carry an activation flow
instead — the visitor's Google address is enrolled, held while Play propagates,
and only then handed off to the Play Store app.

Each app page's own README documents what it needs. See `samafox/README.md`.
