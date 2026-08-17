# Ritual website

This folder is a dependency-free static website for `ritualapp.nishkamk.com`.

## Preview locally

From the repository root, run:

```sh
python3 -m http.server 8080 --directory web
```

Then visit `http://localhost:8080`.

## Host with GitHub Pages

The repository includes a `Deploy Ritual website` workflow. It deploys automatically whenever files under `/web` are pushed to `main`, and it can also be started manually.

1. In GitHub, open **Settings → Pages** and select **GitHub Actions** as the source.
2. Push this repository to `main`. The website workflow will run automatically. To republish without changing a file, open **Actions → Deploy Ritual website → Run workflow**.
3. At the DNS provider for `nishkamk.com`, add a `CNAME` record named `ritualapp` pointing to `ScoutorcusA.github.io`.
4. In the Pages settings, enter `ritualapp.nishkamk.com` as the custom domain and enable HTTPS after GitHub confirms the DNS record.

GitHub recommends verifying `nishkamk.com` in the account’s Pages settings before adding the custom domain, which helps prevent domain-takeover mistakes.

The site and Android app can live in the same repository. The website deploy validates and uploads only `/web`; it does not package or modify the Flutter app. App-only commits do not trigger a website deployment.

## Translations

The canonical app-and-website catalogs live in `/translations`. Files under `web/assets/i18n/` are generated copies for the static site and should not be edited directly. See the [translation guide](../wiki/Translations-and-Languages.md) for the volunteer workflow.

Other static hosts such as Cloudflare Pages, Netlify, or Vercel can also publish this folder. Set the project root/output directory to `web` and leave the build command empty.

## Brand icons

The site uses the scalable `assets/ritual-logo.svg` for visible brand marks and includes PNG fallbacks, a multi-size favicon, an Apple touch icon, and a web app manifest. These files are generated from the authoritative vector master in `assets/branding/` by `tool/generate_brand_assets.py`; edit the master rather than individual web exports.

## Enable optional sponsorships

The app and website link to `https://github.com/sponsors/ScoutorcusA`. Before publishing the support page:

1. Enroll `ScoutorcusA` in GitHub Sponsors and complete its identity, bank, and tax setup.
2. Offer one-time and optional monthly tiers with no rewards, badges, early access, credits, or app benefits.
3. Confirm the public sponsorship URL works while signed out of GitHub.

Ritual must remain identical for supporters and non-supporters. If GitHub Sponsors is not ready when the website launches, remove or temporarily hide the sponsorship button rather than leaving a broken payment link.
