# Google Doc Converter

A Laravel 11 web tool that converts public Google Docs into PDF, DOCX, ODT, XLSX, HTML, Markdown, and JSON. All downloads are streamed (no export files written to disk), with signed links and per-IP rate limiting.

## Features
- Google Drive export for PDF, DOCX, and ODT
- Local file upload (DOCX, PDF, XLSX) stored in Supabase Storage
- HTML fetch + table parsing to build XLSX
- Markdown + JSON output
- Streaming downloads (no temp export files)
- 5-minute signed URLs + per-IP throttling
- File cache warm-up for faster repeated downloads
- AJAX upload flow with determinate progress and in-place download button
- Two-layer Supabase cleanup for uploads (instant + scheduled sweep)
- Responsive DocFlip UI with externalized CSS/JS assets for faster loads

## Requirements
- PHP 8.2+
- Composer
- Extensions: curl, mbstring, openssl, json, pdo (sqlite or your DB driver), zip (required for XLSX)

## Local Setup
1. Install dependencies:
   ```bash
   composer install
   ```
2. Copy env and generate key:
   ```bash
   copy .env.example .env
   php artisan key:generate
   ```
3. For Google Doc conversion, place your service account JSON at:
   ```
   storage/app/google-auth.json
   ```
   Local file conversion does not require Google credentials.
4. Start the server:
   ```bash
   php artisan serve
   ```

## Service Account Notes
- The target Doc must be public: “Anyone with the link can view.”
- The tool uses the service account JSON key for Drive API authentication.

## Caching
- HTML export and parsed data are cached for 5 minutes using Laravel cache.
- Default cache store is file. You can change CACHE_STORE in .env if desired.

## Supabase Storage (Uploads)
Set these values in .env:
```
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
SUPABASE_STORAGE_BUCKET=uploads
```
Use a private bucket.

Uploads are cleaned in two layers:
- Immediate cleanup after successful upload-download streaming
- Scheduled stale-object sweep for any leftover uploads

Optional env setting:
```
UPLOAD_SWEEP_AGE_MINUTES=60
```

The stale sweep command is:
```bash
php artisan uploads:cleanup
```

Dry run mode:
```bash
php artisan uploads:cleanup --dry-run
```

## Local Upload Support
- DOCX: PDF, XLSX, JSON, MD
- PDF: XLSX, JSON, MD (text-only)
- XLSX: PDF (basic), JSON, MD
- DOC (legacy) is not supported without external tools

## Upload UX
- Uploads use AJAX with a determinate progress bar (upload + conversion states)
- Process button is replaced by Download button when the file is ready
- File and format validation happen both client-side and server-side

## Frontend Assets and Branding
- Main page template: `resources/views/doc-converter.blade.php`
- Externalized frontend assets:
   - `public/assets/docflip/doc-converter.css`
   - `public/assets/docflip/doc-converter.js`
- Branding assets are organized under:
   - `public/assets/global-logos/`

## Deployment (Shared Hosting)
1. Upload project source files (or pull from GitHub). Do not upload `.env`, `vendor`, `node_modules`, or runtime files from `storage`.
2. Point the document root to the public folder.
3. Install PHP dependencies and build the frontend assets:
   ```bash
   composer install --no-dev --optimize-autoloader
   npm install
   npm run build
   ```
4. Copy env and set values:
   ```bash
   copy .env.example .env
   ```
   - APP_URL=https://your-domain.com
   - APP_ENV=production
   - APP_DEBUG=false
5. Generate the app key:
   ```bash
   php artisan key:generate
   ```
6. Ensure storage and bootstrap/cache are writable.
7. Place the service account JSON at:
   ```
   storage/app/google-auth.json
   ```
8. Enable the zip extension to allow XLSX downloads.
9. Optional (faster):
   ```bash
   php artisan config:cache
   php artisan route:cache
   ```
10. Required for scheduled cleanup: configure cron to run Laravel scheduler every minute.
   Example cron:
   ```
   * * * * * php /path/to/project/artisan schedule:run >> /dev/null 2>&1
   ```

## Security
- Service account key is excluded from version control via .gitignore.
- Signed links expire in 5 minutes.
- Download endpoint is rate limited per IP.
- Production `.env` files, local databases, sessions, logs, compiled views, and framework caches are excluded from version control.
- Keep `SESSION_SECURE_COOKIE=true` in HTTPS production deployments.
- If a production `APP_KEY` or Supabase service-role key may have been exposed, rotate it deliberately after reviewing the impact: changing `APP_KEY` can invalidate encrypted data and existing sessions.

```
doc-converter
├─ .editorconfig
├─ .htaccess
├─ app
│  ├─ Console
│  │  └─ Commands
│  │     └─ CleanupSupabaseUploads.php
│  ├─ Http
│  │  └─ Controllers
│  │     ├─ Controller.php
│  │     └─ DocConvertController.php
│  ├─ Models
│  │  └─ User.php
│  ├─ Providers
│  │  └─ AppServiceProvider.php
│  └─ Services
│     ├─ GoogleDocConverter.php
│     ├─ LocalFileConverter.php
│     └─ SupabaseStorageService.php
├─ artisan
├─ bootstrap
│  ├─ app.php
│  ├─ cache
│  │  ├─ config.php
│  │  ├─ packages.php
│  │  ├─ routes-v7.php
│  │  └─ services.php
│  └─ providers.php
├─ composer.json
├─ composer.lock
├─ config
│  ├─ app.php
│  ├─ auth.php
│  ├─ cache.php
│  ├─ database.php
│  ├─ filesystems.php
│  ├─ logging.php
│  ├─ mail.php
│  ├─ queue.php
│  ├─ services.php
│  └─ session.php
├─ database
│  ├─ factories
│  │  └─ UserFactory.php
│  ├─ migrations
│  │  ├─ 0001_01_01_000000_create_users_table.php
│  │  ├─ 0001_01_01_000001_create_cache_table.php
│  │  └─ 0001_01_01_000002_create_jobs_table.php
│  └─ seeders
│     └─ DatabaseSeeder.php
├─ package-lock.json
├─ package.json
├─ phpunit.xml
├─ public
│  ├─ .htaccess
│  ├─ assets
│  │  ├─ brand
│  │  │  └─ headerlogo.png
│  │  ├─ docflip
│  │  │  ├─ doc-converter.css
│  │  │  └─ doc-converter.js
│  │  └─ global-logos
│  │     ├─ favicon
│  │     │  ├─ favicon-16x16.png
│  │     │  ├─ favicon-32x32.png
│  │     │  ├─ favicon-48x48.png
│  │     │  └─ favicon.ico
│  │     ├─ header
│  │     │  ├─ header-120x36.png
│  │     │  ├─ header-160x48.png
│  │     │  ├─ header-180x54.png
│  │     │  ├─ header-220x66.png
│  │     │  ├─ header-240x72.png
│  │     │  └─ header-280x84.png
│  │     ├─ hero
│  │     │  ├─ hero-600x180.png
│  │     │  └─ hero-640x192.png
│  │     ├─ icon
│  │     │  ├─ icon-128x128.png
│  │     │  ├─ icon-180x180.png
│  │     │  ├─ icon-192x192.png
│  │     │  └─ icon-64x64.png
│  │     ├─ README.md
│  │     └─ site.webmanifest
│  ├─ favicon.ico
│  ├─ fonts
│  │  ├─ NotoSansBengali-VariableFont_wdth,wght.ttf
│  │  ├─ OFL.txt
│  │  ├─ README.txt
│  │  └─ static
│  │     ├─ installed-fonts.json
│  │     ├─ NotoSansBengali-Black.ttf
│  │     ├─ NotoSansBengali-Bold.ttf
│  │     ├─ NotoSansBengali-ExtraBold.ttf
│  │     ├─ NotoSansBengali-ExtraLight.ttf
│  │     ├─ NotoSansBengali-Light.ttf
│  │     ├─ NotoSansBengali-Medium.ttf
│  │     ├─ NotoSansBengali-Regular.ttf
│  │     ├─ NotoSansBengali-SemiBold.ttf
│  │     ├─ NotoSansBengali-Thin.ttf
│  │     ├─ notosansbengali_bold_fba57e321a82edce87187a80c2eff250.ttf
│  │     ├─ notosansbengali_bold_fba57e321a82edce87187a80c2eff250.ufm
│  │     ├─ NotoSansBengali_Condensed-Black.ttf
│  │     ├─ NotoSansBengali_Condensed-Bold.ttf
│  │     ├─ NotoSansBengali_Condensed-ExtraBold.ttf
│  │     ├─ NotoSansBengali_Condensed-ExtraLight.ttf
│  │     ├─ NotoSansBengali_Condensed-Light.ttf
│  │     ├─ NotoSansBengali_Condensed-Medium.ttf
│  │     ├─ NotoSansBengali_Condensed-Regular.ttf
│  │     ├─ NotoSansBengali_Condensed-SemiBold.ttf
│  │     ├─ NotoSansBengali_Condensed-Thin.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-Black.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-Bold.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-ExtraBold.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-ExtraLight.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-Light.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-Medium.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-Regular.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-SemiBold.ttf
│  │     ├─ NotoSansBengali_ExtraCondensed-Thin.ttf
│  │     ├─ notosansbengali_normal_4202ef00170450ae50b94ed0ebc6445c.ttf
│  │     ├─ notosansbengali_normal_4202ef00170450ae50b94ed0ebc6445c.ufm
│  │     ├─ NotoSansBengali_SemiCondensed-Black.ttf
│  │     ├─ NotoSansBengali_SemiCondensed-Bold.ttf
│  │     ├─ NotoSansBengali_SemiCondensed-ExtraBold.ttf
│  │     ├─ NotoSansBengali_SemiCondensed-ExtraLight.ttf
│  │     ├─ NotoSansBengali_SemiCondensed-Light.ttf
│  │     ├─ NotoSansBengali_SemiCondensed-Medium.ttf
│  │     ├─ NotoSansBengali_SemiCondensed-Regular.ttf
│  │     ├─ NotoSansBengali_SemiCondensed-SemiBold.ttf
│  │     └─ NotoSansBengali_SemiCondensed-Thin.ttf
│  ├─ index.php
│  └─ robots.txt
├─ README.md
├─ resources
│  ├─ css
│  │  └─ app.css
│  ├─ js
│  │  ├─ app.js
│  │  └─ bootstrap.js
│  └─ views
│     ├─ doc-converter.blade.php
│     └─ welcome.blade.php
├─ routes
│  ├─ console.php
│  └─ web.php
├─ storage
│  ├─ app
│  │  ├─ private
│  │  └─ public
│  ├─ framework
│  │  ├─ cache
│  │  │  ├─ data
│  │  │  │  ├─ 00
│  │  │  │  │  └─ 5a
│  │  │  │  │     └─ 005a29dd253aecb50224f3a8433b89ece490b534
│  │  │  │  ├─ 03
│  │  │  │  │  └─ b6
│  │  │  │  ├─ 07
│  │  │  │  │  └─ 7b
│  │  │  │  │     └─ 077b655ee89f254745b317b337f18f38b801f679
│  │  │  │  ├─ 0b
│  │  │  │  │  └─ 07
│  │  │  │  │     └─ 0b079f7d5d993b721f40bc3ba5418a46ac5d3847
│  │  │  │  ├─ 11
│  │  │  │  │  └─ 51
│  │  │  │  │     └─ 1151dfed0daf4444d425d13d4454a5b16c2b6b93
│  │  │  │  ├─ 24
│  │  │  │  │  └─ 21
│  │  │  │  ├─ 25
│  │  │  │  │  └─ df
│  │  │  │  │     └─ 25df46a248e74ead235e166564c259047e58fb86
│  │  │  │  ├─ 26
│  │  │  │  │  └─ f4
│  │  │  │  │     └─ 26f49515a365eee8fee3ae2b333107d1297a7470
│  │  │  │  ├─ 31
│  │  │  │  │  ├─ e6
│  │  │  │  │  │  └─ 31e6f8295ee3b97fbeae4ceba90ad018926567fd
│  │  │  │  │  └─ e7
│  │  │  │  │     └─ 31e761e196bfade3937c19859440ff0e640b0703
│  │  │  │  ├─ 33
│  │  │  │  │  └─ 95
│  │  │  │  │     └─ 3395d196d68bfb3d569fd05866eabbeb7fcf9d63
│  │  │  │  ├─ 3a
│  │  │  │  │  └─ fb
│  │  │  │  │     └─ 3afbb90634c7c487aaacb08d005b4537049c0513
│  │  │  │  ├─ 3e
│  │  │  │  │  └─ d2
│  │  │  │  │     └─ 3ed28566dce3dee43b025eb0d8c24df1c9a450b0
│  │  │  │  ├─ 42
│  │  │  │  │  └─ d8
│  │  │  │  │     └─ 42d8c0087b44f702139377c0b1eaaafec4e52966
│  │  │  │  ├─ 45
│  │  │  │  │  └─ 8c
│  │  │  │  │     └─ 458cc94f82a41f62e05b63849dfa8ba194b06002
│  │  │  │  ├─ 53
│  │  │  │  │  ├─ 19
│  │  │  │  │  │  └─ 53192c16f628633112a68b4c4e7aac96cd8be0d2
│  │  │  │  │  └─ 36
│  │  │  │  │     └─ 5336c88c1e81ff9321818e5d35e44f2402d0547f
│  │  │  │  ├─ 57
│  │  │  │  │  └─ 32
│  │  │  │  │     └─ 57326928d4d5dc3693a8f79689458576a2e02829
│  │  │  │  ├─ 5c
│  │  │  │  │  └─ b0
│  │  │  │  │     └─ 5cb0ccccee371ba3bf6db49a10b829aa29cb6efb
│  │  │  │  ├─ 5d
│  │  │  │  │  └─ fb
│  │  │  │  │     └─ 5dfb4f573263c6f0b85042d75f19878b3eec9b28
│  │  │  │  ├─ 5e
│  │  │  │  │  └─ c9
│  │  │  │  ├─ 61
│  │  │  │  │  └─ c6
│  │  │  │  │     └─ 61c696101ef0465d4dfd4a254d868721b2ac1b96
│  │  │  │  ├─ 6d
│  │  │  │  │  └─ f7
│  │  │  │  │     └─ 6df7c3d7085cb2b64c21e77326705322011c5cd4
│  │  │  │  ├─ 6e
│  │  │  │  │  ├─ 3b
│  │  │  │  │  │  └─ 6e3b8a33661b54eee396951f002f77eab29aca61
│  │  │  │  │  └─ 43
│  │  │  │  │     └─ 6e436ee8932f3f75b283a57ab918e251ce8a5c97
│  │  │  │  ├─ 6f
│  │  │  │  │  └─ e0
│  │  │  │  │     └─ 6fe074de6637ec19e558963dd21e3e3546d12bec
│  │  │  │  ├─ 7d
│  │  │  │  │  ├─ 54
│  │  │  │  │  └─ ec
│  │  │  │  │     └─ 7dec560a8a21617c3321318ee87d7128e054a38c
│  │  │  │  ├─ 88
│  │  │  │  │  └─ 14
│  │  │  │  │     └─ 881479341306958378a7feb064e1f90f943dbc18
│  │  │  │  ├─ 8a
│  │  │  │  │  └─ d2
│  │  │  │  │     └─ 8ad2e7fbe3fbd94130909fa67f0e5c61ab9faa12
│  │  │  │  ├─ 8c
│  │  │  │  │  └─ c5
│  │  │  │  │     └─ 8cc504912000fe640ef81ef24f562288b348c3e1
│  │  │  │  ├─ 8e
│  │  │  │  │  └─ 97
│  │  │  │  │     └─ 8e97f4c1fd47fcc2a7a16752450e0ba506b3d5ac
│  │  │  │  ├─ 94
│  │  │  │  │  └─ ad
│  │  │  │  │     └─ 94ad3a640d196eb089b35973fe7ceaee4f9b12be
│  │  │  │  ├─ 97
│  │  │  │  │  └─ 51
│  │  │  │  │     └─ 975189ed95f9b3abc7caa4a2340beb2209bf7087
│  │  │  │  ├─ 9a
│  │  │  │  │  └─ ed
│  │  │  │  │     └─ 9aed4540352cf574f0e826ce49bb12137356be45
│  │  │  │  ├─ 9f
│  │  │  │  │  └─ c7
│  │  │  │  │     └─ 9fc7075da60e447ba90cec0d945c33ff829aec25
│  │  │  │  ├─ a1
│  │  │  │  │  └─ 7b
│  │  │  │  │     └─ a17b3a2b924aa5fb6a0cdaf53cc28f8062264dfd
│  │  │  │  ├─ a4
│  │  │  │  │  └─ 9f
│  │  │  │  │     └─ a49f7d9636945ff73c4539461bec42dfe0f2802e
│  │  │  │  ├─ a5
│  │  │  │  │  └─ 5d
│  │  │  │  │     └─ a55de5ce18d10eb39889c2a1a165375bd75f4aa3
│  │  │  │  ├─ a7
│  │  │  │  │  └─ c6
│  │  │  │  │     └─ a7c69504aef7acb9e1c0fd71d30f33ea6d58192a
│  │  │  │  ├─ ba
│  │  │  │  │  └─ 19
│  │  │  │  ├─ bf
│  │  │  │  │  └─ 1e
│  │  │  │  ├─ c4
│  │  │  │  │  └─ 22
│  │  │  │  │     └─ c4226616ded1bb53672a1b30c3ad618355039f52
│  │  │  │  ├─ c9
│  │  │  │  │  └─ df
│  │  │  │  ├─ d0
│  │  │  │  │  └─ 5f
│  │  │  │  │     └─ d05ffededf4441b9cc27f4b1d292dd32e4424ef3
│  │  │  │  ├─ db
│  │  │  │  │  └─ 50
│  │  │  │  │     └─ db50dd0e3c48418f0a2d521e66b4e7eef7cc2c73
│  │  │  │  ├─ de
│  │  │  │  │  └─ c7
│  │  │  │  │     └─ dec71ba3be8c96db95d98f6d619ebf2dbbf011c9
│  │  │  │  ├─ e6
│  │  │  │  │  └─ 37
│  │  │  │  │     └─ e637ce52ee79f4b1b505b28d851f31b418d685d7
│  │  │  │  ├─ e8
│  │  │  │  │  └─ 92
│  │  │  │  │     └─ e892a91f75ebaf6d1e377213e1f17c19c48afa2e
│  │  │  │  ├─ eb
│  │  │  │  │  └─ 76
│  │  │  │  │     └─ eb761d80898e5d11a534ef79a6ca70ce831cbb26
│  │  │  │  ├─ ed
│  │  │  │  │  └─ 26
│  │  │  │  │     └─ ed26e7d2bc1ce130e1a0250b8439f5876e208633
│  │  │  │  ├─ f0
│  │  │  │  │  └─ 7a
│  │  │  │  │     └─ f07ab87f9d90079509f196fe12529e2029064c4e
│  │  │  │  ├─ f3
│  │  │  │  │  └─ 42
│  │  │  │  │     └─ f342935ed9961be36345d5dde53bfdc0d3e80fc6
│  │  │  │  ├─ f6
│  │  │  │  │  └─ 0d
│  │  │  │  │     └─ f60dd57f7e4648bb3c0a889c6c01680318cb7f40
│  │  │  │  └─ ff
│  │  │  │     └─ b9
│  │  │  │        └─ ffb901c611354246c2eecc885b4aa661359c1e9d
│  │  │  ├─ dompdf
│  │  │  │  └─ notosansbengali_normal_4202ef00170450ae50b94ed0ebc6445c.ufm.json
│  │  │  └─ mpdf
│  │  │     └─ mpdf
│  │  │        └─ ttfontdata
│  │  │           ├─ dejavusanscondensed.cw.dat
│  │  │           ├─ dejavusanscondensed.cw127.json
│  │  │           ├─ dejavusanscondensed.GDEFdata.json
│  │  │           ├─ dejavusanscondensed.gid.dat
│  │  │           ├─ dejavusanscondensed.GPOSdata.json
│  │  │           ├─ dejavusanscondensed.GSUB.arab.DFLT.json
│  │  │           ├─ dejavusanscondensed.GSUB.arab.KUR .json
│  │  │           ├─ dejavusanscondensed.GSUB.arab.SND .json
│  │  │           ├─ dejavusanscondensed.GSUB.arab.URD .json
│  │  │           ├─ dejavusanscondensed.GSUB.nko .DFLT.json
│  │  │           ├─ dejavusanscondensed.GSUBdata.json
│  │  │           ├─ dejavusanscondensed.GSUBGPOStables.dat
│  │  │           ├─ dejavusanscondensed.mtx.json
│  │  │           ├─ notosansbengali.cw.dat
│  │  │           ├─ notosansbengali.gid.dat
│  │  │           └─ notosansbengali.mtx.json
│  │  ├─ sessions
│  │  │  ├─ IlLNtP3whAh2dAWHm75SpxFAjPrL2cwV0Nqf5yFJ
│  │  │  ├─ JpLdQwp2JrbPC9OXxLbcaK1AUnbbqcEJZvbftnKE
│  │  │  ├─ mCGnXkF2gg4gTMyPof44u414jKdVDDOUhs0soYr7
│  │  │  ├─ Pp0iGRf9crG61lIpFgatD1oxAbQzryZZCsPmU2r8
│  │  │  ├─ pSs99NimPGafDVOJKYWE6AScLs6OzCLxZNvYSOOw
│  │  │  └─ wu7ImNwAXkwZySXyoCKQo7Psdv99hymEunhQK8If
│  │  ├─ testing
│  │  └─ views
│  │     ├─ 07c6b50b8c56cc15b035b3bc1852aab5.php
│  │     ├─ 19a7ba750edc9f17cccd3cf775f53e62.php
│  │     ├─ 19a9ba39dbf34af382b7d88adf5bf913.php
│  │     ├─ 2f5faff8892981c2f6e0b9aa568ee448.php
│  │     ├─ 3a021cd8f46140437a21f0888c6daa79.php
│  │     ├─ 3b3735b80b4fb073d1d222d38794039b.php
│  │     ├─ 414b0ab9c70314ec685b38a9501374ee.php
│  │     ├─ 4232785e54c89108a358ca67559a8259.php
│  │     ├─ 435cbd99e62c6ab6a2a83b62ccc22083.php
│  │     ├─ 4a4192cd8896c5e73d2c1dd179ec193b.php
│  │     ├─ 647a10f680c0dab30e997e3dd8cb5519.php
│  │     ├─ 7ac480c724dd1338309c6a77484f2ac8.php
│  │     ├─ 8d80cbc98e41637cbd7fe00026fbd595.php
│  │     ├─ a0e648e20c40cc91de589caef1b5e94b.php
│  │     ├─ c3c361d61295b16bb62add306105a9a3.php
│  │     ├─ dabae8c0012e7c0460a198312ad21e6d.php
│  │     ├─ e98e57c1fe615800273eebf5c5e5d9a7.php
│  │     ├─ f0c9519d8cce5b89e333010d64522d4b.php
│  │     └─ fa8182cd37f56dfc60e678e6ba4c3d53.php
│  └─ logs
├─ tests
│  ├─ Feature
│  │  └─ ExampleTest.php
│  ├─ TestCase.php
│  └─ Unit
│     └─ ExampleTest.php
└─ vite.config.js

```