'use strict';

/**
 * ═══════════════════════════════════════════════════
 *  AI PROMPT — INSTAGRAM DOWNLOADER
 *  File khusus prompt AI untuk fitur .ig
 *
 *  Fungsi:
 *    1. buildIgVisionPrompt()       → prompt analisis visual thumbnail/cover
 *    2. buildIgCaptionPrompt(data)  → prompt generate caption WhatsApp
 *
 *  Cara kerja:
 *    - Bot ambil cover/thumbnail dari API Instagram
 *    - Dikirim ke Gemini Vision (buildIgVisionPrompt)
 *    - Hasil analisis visual + metadata → buildIgCaptionPrompt
 *    - Caption final dikirim bareng video di WhatsApp
 * ═══════════════════════════════════════════════════
 */

/**
 * Prompt untuk Gemini Vision — menganalisis thumbnail/cover Instagram.
 * Tujuan: deskripsikan ISI KONTEN VISUAL secara akurat, bukan tebak-tebakan.
 *
 * @returns {string} prompt string untuk askWithImage
 */
export function buildIgVisionPrompt() {
    return `Kamu adalah AI yang menganalisis konten visual dari Instagram Reel/Post.

Lihat gambar ini dengan teliti, lalu jawab dengan format berikut (tidak perlu tulis labelnya):
1. Apa yang terjadi atau ditampilkan? (aksi utama, kejadian, atau objek)
2. Siapa yang ada di video? (orang, hewan, karakter — sebutkan ciri khas jika bisa)
3. Di mana setting/latarnya? (dalam ruangan, outdoor, kafe, pantai, dll)
4. Apa vibe/nuansa kontennya? (lucu, menggemaskan, edukatif, dramatis, estetik, dll)

Aturan WAJIB:
- Jawab dalam bahasa Indonesia
- Akurat berdasarkan apa yang BENAR-BENAR terlihat di gambar — jangan mengarang
- Jika ada hewan, sebutkan jenis hewannya secara spesifik (kucing, anjing, tupai, dll)
- Jika ada makanan, sebutkan nama makanannya
- Jika ada orang, deskripsikan apa yang sedang mereka lakukan
- Ringkas tapi informatif: maksimal 3-4 kalimat
- Jangan bilang kamu AI, jangan tulis label "Jawaban:" atau heading apapun`;
}

/**
 * Prompt untuk generate caption WhatsApp setelah analisis visual selesai.
 *
 * @param {object} data
 * @param {string} data.username        - username akun Instagram (@xxx)
 * @param {string} data.caption         - caption asli dari IG (bisa kosong)
 * @param {string} data.likes           - jumlah likes (string, bisa kosong)
 * @param {string} data.comments        - jumlah comments (string, bisa kosong)
 * @param {string} data.mediaType       - 'reel' | 'video' | 'photo' | 'carousel'
 * @param {string} data.visualDesc      - hasil analisis visual dari Gemini Vision
 * @returns {string} prompt string untuk gemini.ask()
 */
export function buildIgCaptionPrompt({
    username = '',
    caption = '',
    likes = '',
    comments = '',
    mediaType = 'reel',
    visualDesc = '',
} = {}) {
    const isReel = mediaType === 'reel' || mediaType === 'video';
    const isPhoto = mediaType === 'photo' || mediaType === 'image';
    const isCarousel = mediaType === 'carousel' || mediaType === 'album';

    const contentTypeLabel = isReel ? 'Reel/Video' : isCarousel ? 'Album/Carousel' : 'Foto';
    const emoji = isReel ? '🎬' : isCarousel ? '🖼️' : '📸';

    const parts = [];
    if (username) parts.push(`Akun: @${username}`);
    if (likes) parts.push(`Likes: ${likes}`);
    if (comments) parts.push(`Comments: ${comments}`);
    if (caption) parts.push(`Caption asli dari IG: "${caption.substring(0, 300)}"`);

    const metaBlock = parts.length > 0
        ? `\nMetadata:\n${parts.map(p => `- ${p}`).join('\n')}`
        : '';

    const visualBlock = visualDesc
        ? `\nAnalisis visual konten (dari AI Vision — INI YANG PALING PENTING):\n"${visualDesc.substring(0, 600)}"`
        : '';

    return `Kamu adalah asisten bot WhatsApp bernama Wily yang cerdas dan natural.
Tugasmu: buat caption WhatsApp untuk ${contentTypeLabel} Instagram yang baru diunduh.
${metaBlock}${visualBlock}

ATURAN CAPTION (WAJIB DIIKUTI):
1. Mulai dengan emoji ${emoji} dan nama akun dalam *bold* (contoh: ${emoji} *@${username || 'instagram'}*)
2. Lanjut 1-2 kalimat yang menggambarkan ISI KONTEN — **WAJIB berdasarkan analisis visual di atas**, bukan tebak-tebakan
3. Jika kontennya lucu/menggemaskan/unik → boleh tambah komentar santai yang nyambung (bisa ngakak dikit, kasual)
4. Jika ada info likes/comments yang banyak → bisa sebut sekilas (opsional, jangan kaku)
5. Bahasa Indonesia santai, natural, tidak kaku — seperti orang ngirim video ke teman
6. DILARANG: mengarang info yang tidak ada di data, menyebut hal yang tidak terlihat di konten
7. DILARANG: caption generik seperti "kompilasi momen indah", "bikin hati adem", atau frasa klise sejenisnya
8. DILARANG: sertakan URL atau link
9. DILARANG: bilang kamu AI
10. Maksimal 4 baris total — ringkas tapi berkarakter

Caption:`;
}

/**
 * Fallback caption sederhana jika Gemini gagal total.
 * Berbasis metadata saja, tidak ada AI.
 *
 * @param {object} data - sama dengan buildIgCaptionPrompt
 * @returns {string}
 */
export function buildIgFallbackCaption({
    username = '',
    likes = '',
    comments = '',
    mediaType = 'reel',
    caption = '',
} = {}) {
    const emoji = mediaType === 'reel' || mediaType === 'video' ? '🎬' : '📸';
    let text = `${emoji} *${username ? '@' + username : 'Instagram'}*\n`;
    if (caption) text += caption.substring(0, 150) + (caption.length > 150 ? '...' : '') + '\n';
    const stats = [];
    if (likes) stats.push(`❤️ ${likes}`);
    if (comments) stats.push(`💬 ${comments}`);
    if (stats.length) text += stats.join('  ');
    return text.trim();
}
