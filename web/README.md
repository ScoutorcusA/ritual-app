# Ritual website

This folder is a dependency-free static website for `ritualapp.nishkamk.com`.

## Preview locally

From the repository root, run:

```sh
python3 -m http.server 8080 --directory web
```

Then visit `http://localhost:8080`.

## Host with GitHub Pages

The repository includes a manually triggered `Deploy Ritual website` workflow.

1. In GitHub, open **Settings → Pages** and select **GitHub Actions** as the source.
2. Open **Actions → Deploy Ritual website → Run workflow**.
3. In the Pages settings, enter `ritualapp.nishkamk.com` as the custom domain and enable HTTPS.
4. At the DNS provider for `nishkamk.com`, add a `CNAME` record named `ritualapp` pointing to `ScoutorcusA.github.io`.

GitHub recommends verifying `nishkamk.com` in the account’s Pages settings before adding the custom domain, which helps prevent domain-takeover mistakes.

The site and Android app can live in the same repository. The website deploy only uploads `/web`; it does not package or modify the Flutter app.

Other static hosts such as Cloudflare Pages, Netlify, or Vercel can also publish this folder. Set the project root/output directory to `web` and leave the build command empty.
