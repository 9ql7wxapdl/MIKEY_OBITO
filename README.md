<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=28&pause=1000&color=25D366&center=true&vCenter=true&width=600&lines=🤖+WILY+BOT;WhatsApp+Multi-Fitur+Bot;Powered+by+Baileys+%2B+Node.js" alt="Typing SVG" />

<br/>

[![Node.js](https://img.shields.io/badge/Node.js-20%2B-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![WhatsApp](https://img.shields.io/badge/WhatsApp-Baileys-25D366?style=for-the-badge&logo=whatsapp&logoColor=white)](https://github.com/WhiskeySockets/Baileys)
[![License](https://img.shields.io/badge/License-FREE-blue?style=for-the-badge)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=for-the-badge)]()

<br/>

> **WhatsApp Bot multi-fitur berbasis [Baileys](https://github.com/WhiskeySockets/Baileys)**
> Script ini **FREE** — tidak untuk diperjualbelikan!

<br/>

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/Wilykun1994/wily-bot)
&nbsp;
[![Deploy on Fly.io](https://img.shields.io/badge/Deploy%20ke-Fly.io-8B5CF6?style=for-the-badge&logo=fly.io&logoColor=white)](https://fly.io/docs/launch/)

</div>

---

## 📋 Daftar Isi

- [✨ Fitur Unggulan](#-fitur-unggulan)
- [🚀 Deploy ke Railway](#-deploy-ke-railway)
- [✈️ Deploy ke Fly.io (Gratis + Volume)](#️-deploy-ke-flyio-gratis--volume)
- [📦 Instalasi Manual](#-instalasi-manual)
- [⚙️ Konfigurasi](#️-konfigurasi)
- [📖 Daftar Command](#-daftar-command)
- [🎬 YouTube Downloader](#-youtube-downloader)
- [🤖 Jadibot (Multi-Session)](#-jadibot-multi-session)
- [🛡️ Fitur Keamanan](#️-fitur-keamanan)
- [📝 Kredit](#-kredit)

---

## ✨ Fitur Unggulan

<table>
  <tr>
    <td align="center">🎵</td>
    <td><b>YouTube Downloader</b><br/>Download audio MP3 & video MP4 dari YouTube dengan thumbnail real-time</td>
  </tr>
  <tr>
    <td align="center">🤖</td>
    <td><b>Jadibot (Multi-Session)</b><br/>Clone bot ke nomor WhatsApp lain via pairing code</td>
  </tr>
  <tr>
    <td align="center">🧠</td>
    <td><b>Auto Simi (AI Chat)</b><br/>Balas pesan otomatis menggunakan AI Groq/Llama-3.1</td>
  </tr>
  <tr>
    <td align="center">👁️</td>
    <td><b>Auto Read Story</b><br/>Otomatis lihat & react story WhatsApp kontak</td>
  </tr>
  <tr>
    <td align="center">🛡️</td>
    <td><b>Anti-Delete</b><br/>Simpan & kirim ulang pesan yang dihapus</td>
  </tr>
  <tr>
    <td align="center">📵</td>
    <td><b>Anti-Call</b><br/>Tolak panggilan suara/video otomatis dengan pesan custom</td>
  </tr>
  <tr>
    <td align="center">📥</td>
    <td><b>Multi Downloader</b><br/>TikTok, Instagram, Facebook, YouTube dalam satu bot</td>
  </tr>
  <tr>
    <td align="center">🖼️</td>
    <td><b>Sticker Tools</b><br/>Buat sticker dari gambar, konversi sticker ke gambar</td>
  </tr>
  <tr>
    <td align="center">📲</td>
    <td><b>View-Once Bypass</b><br/>Ambil & simpan media view-once sebelum menghilang</td>
  </tr>
  <tr>
    <td align="center">📡</td>
    <td><b>Telegram Integration</b><br/>Forward story/log WhatsApp ke Telegram bot</td>
  </tr>
</table>

---

## 🚀 Deploy ke Railway

> Railway adalah platform hosting cloud gratis (ada free tier) yang bisa jalankan bot kamu 24 jam tanpa perlu VPS.

<div align="center">

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/Wilykun1994/wily-bot)

</div>

<details>
<summary><b>🔽 Klik untuk panduan lengkap deploy ke Railway (Bahasa Indonesia)</b></summary>

<br/>

### Apa itu Railway?
Railway adalah layanan cloud hosting yang memungkinkan kamu menjalankan bot Node.js secara online tanpa perlu menyewa VPS sendiri. Bot kamu akan jalan 24/7 selama ada koneksi internet.

---

### Langkah-Langkah Deploy

#### 1. Siapkan Repository GitHub
Sebelum deploy, pastikan kode bot kamu sudah ada di GitHub:
```bash
git init
git add .
git commit -m "first commit"
git remote add origin https://github.com/USERNAME/wily-bot.git
git push -u origin main
```

#### 2. Buat Akun Railway
- Buka [railway.com](https://railway.com) dan daftar dengan akun GitHub
- Verifikasi akun kamu (penting untuk bisa deploy)

#### 3. Buat Proyek Baru
- Klik tombol **"Deploy on Railway"** di atas, **ATAU**
- Masuk ke dashboard Railway → klik **"New Project"** → pilih **"Deploy from GitHub repo"**
- Pilih repository `wily-bot` kamu

#### 4. Atur Environment Variables (Wajib!)
Setelah proyek dibuat, pergi ke tab **Variables** di Railway dan tambahkan variabel berikut:

| Variabel | Nilai | Keterangan |
|---|---|---|
| `BOT_NUMBER_PAIR` | `6281234567890` | Nomor WA bot (tanpa +, pakai kode negara) |
| `BOT_SESSION_NAME` | `hisoka` | Nama sesi bot (bebas) |
| `BOT_LOGGER_LEVEL` | `silent` | Level log (biarkan silent) |
| `BOT_LOG_MESSAGE` | `true` | Log pesan masuk |
| `BOT_MAX_RETRIES` | `5` | Maksimal reconnect otomatis |
| `BOT_PREFIX` | `.` | Prefix command bot |
| `BOT_ALLOWED_NO_PREFIX` | `true` | Izinkan command tanpa prefix |

> ⚠️ **`BOT_NUMBER_PAIR` wajib diisi** — ini nomor WhatsApp yang akan dipairing dengan bot.

#### 5. Tambahkan Volume (WAJIB — Agar Sesi Tidak Hilang!)

> ⚠️ **Tanpa Volume, setiap kali Railway restart bot → sesi WhatsApp HILANG → harus pairing ulang dari awal!**

Cara pasang Volume di Railway:

1. Buka **service** bot kamu di Railway dashboard
2. Klik tab **"Volumes"** (di sebelah Variables, Settings)
3. Klik tombol **"Create Volume"** / **"Add Volume"**
4. Tambahkan **3 volume** berikut satu per satu:

| No | Isi kolom **Mount Path** | Isi kolom **Volume Name** |
|---|---|---|
| 1 | `/app/sessions` | `sessions` |
| 2 | `/app/jadibot` | `jadibot` |
| 3 | `/app/data` | `data` |

5. Klik **"Add"** / **"Save"** untuk setiap volume
6. Railway akan otomatis redeploy setelah volume ditambahkan

> ✅ Setelah volume dipasang, sesi login WhatsApp akan **tetap tersimpan** meskipun bot restart berkali-kali — tidak perlu pairing ulang.

#### 6. Deploy & Lihat Log
- Railway otomatis build menggunakan **Dockerfile** yang sudah ada
- Buka tab **"Logs"** untuk lihat proses deployment
- Tunggu sampai muncul **Pairing Code** di log

#### 7. Pairing WhatsApp
Saat bot pertama kali jalan, Railway akan tampilkan **Pairing Code** di log, contoh:
```
📌 Kode Pairing: ABCD-1234
```
Cara masukkan kode:
1. Buka **WhatsApp** di HP
2. Ketuk **⋮** (titik tiga) → **Perangkat Tertaut**
3. Pilih **Tautkan Perangkat** → **Tautkan dengan Nomor Telepon**
4. Masukkan kode pairing dari log Railway

#### 8. Bot Siap Digunakan! 🎉
Setelah pairing berhasil, bot akan online dan bisa menerima command.

---

### File Penting untuk Railway

| File | Fungsi |
|---|---|
| `Dockerfile` | Instruksi untuk Railway build lingkungan bot (Node.js 20 + FFmpeg) |
| `railway.toml` | Konfigurasi build dan restart otomatis jika bot crash |
| `.env` | **Jangan diupload!** Gunakan Variables di Railway dashboard |

---

### Tips & Catatan
- **Free tier Railway** memberikan $5 kredit/bulan, cukup untuk bot ringan
- Jika bot tiba-tiba mati, Railway akan **restart otomatis** (sudah dikonfigurasi)
- Sesi login tersimpan di volume, jadi **tidak perlu pairing ulang** setelah restart
- Jika volume belum diatur, sesi akan hilang setiap kali Railway restart container

</details>

---

## ✈️ Deploy ke Fly.io (Gratis + Volume)

> Fly.io adalah pilihan terbaik jika ingin **gratis selamanya** dengan **Volume permanen** (sesi tidak hilang saat restart). Mendukung Docker langsung — `Dockerfile` yang sudah ada langsung bisa dipakai.

<div align="center">

[![Deploy on Fly.io](https://img.shields.io/badge/Deploy%20ke-Fly.io-8B5CF6?style=for-the-badge&logo=fly.io&logoColor=white)](https://fly.io/docs/launch/)

</div>

<details>
<summary><b>🔽 Klik untuk panduan lengkap deploy ke Fly.io (Bahasa Indonesia)</b></summary>

<br/>

### Apa itu Fly.io?
Fly.io adalah platform cloud yang menjalankan container Docker di server global. Free tier-nya memberikan **3 VM gratis** dan **3GB Volume storage gratis** — cukup untuk menjalankan bot WhatsApp 24/7 tanpa bayar.

---

### Persyaratan
- Akun Fly.io (daftar di [fly.io](https://fly.io))
- `flyctl` (CLI Fly.io) terinstal di komputer

---

### Langkah-Langkah Deploy

#### 1. Install flyctl (CLI Fly.io)

**Windows:**
```powershell
iwr https://fly.io/install.ps1 -useb | iex
```

**Linux / Mac:**
```bash
curl -L https://fly.io/install.sh | sh
```

#### 2. Login ke Fly.io
```bash
fly auth login
```
Browser akan terbuka → login dengan akun Fly.io kamu.

#### 3. Clone & Masuk Folder Bot
```bash
git clone https://github.com/USERNAME/wily-bot.git
cd wily-bot
```

#### 4. Buat App di Fly.io
```bash
fly launch --no-deploy
```
- Saat ditanya nama app, ketik: `wily-bot` (atau nama lain)
- Saat ditanya region, pilih: **Singapore (sin)** — paling dekat ke Indonesia
- File `fly.toml` sudah tersedia, pilih **"Yes"** jika ditanya pakai yang ada

#### 5. Buat Volume (Gratis 3GB)
Jalankan perintah berikut **satu per satu**:
```bash
fly volumes create sessions_vol --size 1 --region sin
fly volumes create jadibot_vol  --size 1 --region sin
fly volumes create data_vol     --size 1 --region sin
```

> ✅ Volume ini **gratis** dan **permanen** — sesi WhatsApp tidak akan hilang meskipun bot restart berkali-kali.

#### 6. Set Environment Variables (Wajib!)
```bash
fly secrets set BOT_NUMBER_PAIR=6281234567890
fly secrets set BOT_SESSION_NAME=hisoka
fly secrets set BOT_PREFIX=.
fly secrets set BOT_MAX_RETRIES=5
fly secrets set BOT_LOG_MESSAGE=true
```

> ⚠️ Ganti `6281234567890` dengan nomor WhatsApp bot kamu (tanpa +, pakai kode negara).

#### 7. Deploy Bot
```bash
fly deploy
```
Fly.io akan build Docker image dan jalankan bot. Tunggu sampai selesai.

#### 8. Lihat Log & Ambil Pairing Code
```bash
fly logs
```
Tunggu sampai muncul **Pairing Code** di log, contoh:
```
📌 Kode Pairing: ABCD-1234
```

#### 9. Pairing WhatsApp
1. Buka **WhatsApp** di HP
2. Ketuk **⋮** (titik tiga) → **Perangkat Tertaut**
3. Pilih **Tautkan Perangkat** → **Tautkan dengan Nomor Telepon**
4. Masukkan kode pairing dari log Fly.io

#### 10. Bot Siap! 🎉
Setelah pairing berhasil, bot akan online 24/7.

---

### Perintah Berguna

| Perintah | Fungsi |
|---|---|
| `fly logs` | Lihat log bot secara real-time |
| `fly status` | Cek status bot |
| `fly deploy` | Update bot setelah edit kode |
| `fly ssh console` | Masuk langsung ke dalam container |
| `fly apps restart wily-bot` | Restart bot |

---

### File Penting untuk Fly.io

| File | Fungsi |
|---|---|
| `Dockerfile` | Sudah ada — dipakai langsung oleh Fly.io |
| `fly.toml` | Konfigurasi app, volume, dan region Fly.io |
| `.env` | **Jangan diupload!** Gunakan `fly secrets set` |

---

### Tips & Catatan
- **Free tier Fly.io** memberikan 3 VM + 3GB storage gratis selamanya
- Volume `sessions_vol`, `jadibot_vol`, `data_vol` sudah dikonfigurasi di `fly.toml`
- Region **sin (Singapore)** dipilih karena paling dekat ke Indonesia → koneksi lebih stabil
- Jika bot crash, Fly.io akan **restart otomatis**

</details>

---

## 📦 Instalasi Manual

<details>
<summary><b>🔽 Klik untuk melihat langkah instalasi lengkap</b></summary>

<br/>

### Persyaratan
- **Node.js** v18 atau lebih baru
- **npm** v8+
- **ffmpeg** (untuk YouTube audio/video)
- **yt-dlp** (sudah disertakan di folder `tmp/`)

### Langkah-langkah

```bash
# 1. Clone repositori
git clone https://github.com/username/wily-bot.git
cd wily-bot

# 2. Install dependensi
npm install

# 3. Pastikan yt-dlp bisa dieksekusi
chmod +x tmp/yt-dlp

# 4. Edit konfigurasi (lihat bagian Konfigurasi)
nano config.json

# 5. Jalankan bot
node index.js
```

### Pairing Bot
Saat pertama kali dijalankan, bot akan meminta nomor WhatsApp untuk mendapatkan **Pairing Code**. Masukkan kode tersebut di WhatsApp:

> **Perangkat Tertaut → Tautkan Perangkat → Tautkan dengan Nomor Telepon**

</details>

---

## ⚙️ Konfigurasi

<details>
<summary><b>🔽 Klik untuk melihat panduan konfigurasi config.json</b></summary>

<br/>

Edit file `config.json` sesuai kebutuhan:

```json
{
  "owners": ["6281234567890"],

  "autoOnline": {
    "enabled": true,
    "intervalSeconds": 15
  },

  "autoReadStory": {
    "enabled": true,
    "autoReaction": true,
    "randomDelay": true,
    "delayMinMs": 1000,
    "delayMaxMs": 20000
  },

  "antiDelete": {
    "enabled": false,
    "privateChat": true,
    "groupChat": true
  },

  "antiCall": {
    "enabled": false,
    "message": "Maaf, tidak bisa menerima panggilan.",
    "whitelist": []
  },

  "telegram": {
    "enabled": false,
    "token": "BOT_TOKEN_TELEGRAM",
    "chatId": "CHAT_ID_TELEGRAM"
  },

  "autoSimi": {
    "enabled": false,
    "apiKey": "API_KEY_GROQ"
  },

  "sticker": {
    "pack": "Nama Pack",
    "author": "Nama Author"
  }
}
```

| Key | Deskripsi |
|---|---|
| `owners` | Nomor WhatsApp owner (format: 628xxx tanpa +) |
| `autoOnline` | Jaga status online secara berkala |
| `autoReadStory` | Auto lihat & react story |
| `antiDelete` | Simpan pesan yang dihapus |
| `antiCall` | Tolak panggilan otomatis |
| `telegram` | Forward ke Telegram bot |
| `autoSimi` | Balas otomatis dengan AI |

</details>

---

## 📖 Daftar Command

<details>
<summary><b>🔽 Utilitas & Info</b></summary>

<br/>

| Command | Deskripsi |
|---|---|
| `.menu` | Tampilkan semua daftar command |
| `.ping` / `.p` | Cek kecepatan respons bot |
| `.info` | Informasi detail bot |
| `.owner` | Tampilkan kontak owner |
| `.quoted` / `.q` | Ambil isi pesan yang di-quote |

</details>

<details>
<summary><b>🔽 Sticker & Media</b></summary>

<br/>

| Command | Deskripsi |
|---|---|
| `.s` / `.sticker` | Buat sticker dari gambar/video |
| `.toimg` | Konversi sticker ke gambar |
| `.vo` / `.rvo` | Ambil media View-Once |

</details>

<details>
<summary><b>🔽 Downloader</b></summary>

<br/>

| Command | Deskripsi |
|---|---|
| `.tt <link>` | Download video TikTok (tanpa watermark) |
| `.ig <link>` | Download foto/video Instagram |
| `.fb <link>` | Download video Facebook |
| `.play <judul>` | Cari & download audio YouTube (MP3) |
| `.ytmp3 <link>` | Download audio YouTube (MP3) via URL |
| `.ytmp4 <link>` | Download video YouTube (MP4, 360p) via URL |

</details>

<details>
<summary><b>🔽 Grup</b></summary>

<br/>

| Command | Deskripsi |
|---|---|
| `.hidetag` / `.ht` | Tag semua anggota grup secara tersembunyi |
| `.all` | Mention semua anggota grup |
| `.group open` | Buka grup (hanya admin) |
| `.group close` | Tutup grup (hanya admin) |

</details>

<details>
<summary><b>🔽 Auto & Fitur Aktif</b></summary>

<br/>

| Command | Deskripsi |
|---|---|
| `.simi on/off` | Aktifkan/nonaktifkan Auto Simi AI |
| `.anticall on/off` | Aktifkan/nonaktifkan tolak panggilan suara |
| `.anticallvid on/off` | Aktifkan/nonaktifkan tolak panggilan video |
| `.antidel on/off` | Aktifkan/nonaktifkan anti-delete |
| `.typing on/off` | Aktifkan/nonaktifkan auto typing |
| `.recording on/off` | Aktifkan/nonaktifkan auto recording |
| `.readsw on/off` | Aktifkan/nonaktifkan auto baca story |

</details>

<details>
<summary><b>🔽 Owner Only</b></summary>

<br/>

| Command | Deskripsi |
|---|---|
| `.eval <kode>` | Jalankan kode JavaScript |
| `.bash <perintah>` | Jalankan perintah terminal |
| `.addowner <nomor>` | Tambah owner baru |
| `.backup` | Backup file session/config |
| `.restart` | Restart bot |

</details>

---

## 🎬 YouTube Downloader

<details>
<summary><b>🔽 Cara penggunaan & contoh hasil</b></summary>

<br/>

Bot menggunakan **yt-dlp** (binary terbaru 2026) sebagai engine download, sehingga akurat dan stabil untuk semua video YouTube terbaru.

### `.play <judul lagu>`
Cari dan download audio dari YouTube berdasarkan kata kunci.

```
.play shape of you ed sheeran
.play faded alan walker
```

**Alur:**
1. 🔍 Bot cari video yang paling relevan
2. 📸 Thumbnail + info video langsung muncul
3. ⬇️ Audio MP3 dikirim ke chat
4. ✅ Selesai

---

### `.ytmp3 <url>`
Download audio MP3 dari link YouTube langsung.

```
.ytmp3 https://youtu.be/JGwWNGJdvx8
.ytmp3 https://www.youtube.com/watch?v=JGwWNGJdvx8
```

---

### `.ytmp4 <url>`
Download video MP4 (kualitas 360p) dari link YouTube.

```
.ytmp4 https://youtu.be/dQw4w9WgXcQ
.ytmp4 https://www.youtube.com/watch?v=dQw4w9WgXcQ
```

---

**Info yang ditampilkan di setiap thumbnail:**

```
╭═══〔 🎵 YTMP3 DOWNLOADER 〕═══╮
│
│ 📌 Shape of You
│ ⏱️ Durasi  : 3:53
│ 👁️ Views   : 6.692.687.758
│ 👤 Channel : Ed Sheeran
│ 👍 Likes   : 35.415.358
│ 🔗 Link    : https://youtu.be/JGwWNGJdvx8
│
│ ⬇️ Sedang mengunduh audio MP3...
╰══════════════════════════════╯
```

**Batas durasi:**
- `.play` & `.ytmp3` → maksimal **10 menit**
- `.ytmp4` → maksimal **5 menit**

</details>

---

## 🤖 Jadibot (Multi-Session)

<details>
<summary><b>🔽 Cara menggunakan fitur Jadibot</b></summary>

<br/>

Fitur Jadibot memungkinkan siapa saja untuk "meminjam" bot ke nomor WhatsApp mereka sendiri menggunakan pairing code.

### Cara Pakai

```
.jadibot
```

Bot akan mengirim **Pairing Code** 8 digit. Masukkan kode tersebut di WhatsApp:
> **Perangkat Tertaut → Tautkan dengan Nomor Telepon → masukkan kode**

### Command Jadibot

| Command | Deskripsi |
|---|---|
| `.jadibot` | Mulai sesi jadibot untuk nomormu |
| `.stopbot` | Hentikan sesi jadibot |
| `.listbot` | Lihat daftar jadibot yang aktif |

> **Catatan:** Setiap session jadibot tersimpan di folder `jadibot/` dan tetap aktif meskipun bot di-restart.

</details>

---

## 🛡️ Fitur Keamanan

<details>
<summary><b>🔽 Detail fitur keamanan bot</b></summary>

<br/>

### Anti-Delete
Saat seseorang menghapus pesan, bot mendeteksinya dan mengirim ulang isi pesan ke chat yang sama.

```
.antidel on   → aktifkan
.antidel off  → nonaktifkan
```

### Anti-Call
Bot otomatis menolak panggilan masuk dan membalas dengan pesan custom.

```
.anticall on    → tolak panggilan suara
.anticallvid on → tolak panggilan video
```

### Crash Guard
Bot dilengkapi sistem perlindungan crash global yang mencegah bot mati akibat error tak terduga.

### Memory Monitor
Bot memantau penggunaan RAM secara berkala dan dapat auto-restart jika melebihi batas yang dikonfigurasi.

### Auto Cleaner
File temporary (hasil download) dibersihkan otomatis setiap 6 jam.

</details>

---

## 📝 Kredit

<div align="center">

| Peran | Nama |
|---|---|
| 🛠️ Pengembang Utama | **Bang Wily (Wilykun)** |
| 🙏 Base Script | **Bang Dika Ardnt** |
| 📚 Library | [Baileys (WhiskeySockets)](https://github.com/WhiskeySockets/Baileys) |
| 🎬 YouTube Engine | [yt-dlp](https://github.com/yt-dlp/yt-dlp) |

<br/>

> ⚠️ **Script ini GRATIS dan tidak untuk diperjualbelikan!**
> Jika kamu menemukannya dijual, itu adalah penipuan.

<br/>

[![WhatsApp](https://img.shields.io/badge/Hubungi_Owner-WhatsApp-25D366?style=for-the-badge&logo=whatsapp&logoColor=white)](https://wa.me/6289681008411)

<br/>

**Made with ❤️ by Bang Wily**

</div>
