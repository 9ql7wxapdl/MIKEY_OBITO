'use strict';

/**
 * Button + AIRich — CJS port of Nixel's Button v2.0
 * Original: wa.me/6282139672290
 * Converted: ESM → CJS, baileys → socketon
 */

const { generateWAMessageFromContent, prepareWAMessageMedia } = require('socketon');
const crypto = require('crypto');

// ─────────────────────────────────────────────────────────────────────────────
// Button — interactive message dengan berbagai jenis tombol
// ─────────────────────────────────────────────────────────────────────────────

class Button {
    constructor() {
        this._title    = '';
        this._subtitle = '';
        this._body     = '';
        this._footer   = '';
        this._beton    = [];
        this._data     = undefined;
        this._contextInfo           = {};
        this._currentSelectionIndex = -1;
        this._currentSectionIndex   = -1;
        this._type     = 0;
        this._betonOld = [];
        this._params   = {};
    }

    // ── Media ──────────────────────────────────────────────────────────────

    setVideo(path, options = {}) {
        if (!path) return new Error('Url or buffer needed');
        Buffer.isBuffer(path)
            ? this._data = { video: path, ...options }
            : this._data = { video: { url: path }, ...options };
        return this;
    }

    setImage(path, options = {}) {
        if (!path) return new Error('Url or buffer needed');
        Buffer.isBuffer(path)
            ? this._data = { image: path, ...options }
            : this._data = { image: { url: path }, ...options };
        return this;
    }

    setDocument(path, options = {}) {
        if (!path) return new Error('Url or buffer needed');
        Buffer.isBuffer(path)
            ? this._data = { document: path, ...options }
            : this._data = { document: { url: path }, ...options };
        return this;
    }

    setMedia(obj) {
        if (typeof obj === 'object' && !Array.isArray(obj)) {
            this._data = obj;
        } else {
            return 'Type of media must be an Object';
        }
        return this;
    }

    // ── Teks ──────────────────────────────────────────────────────────────

    setTitle(title)       { this._title    = title;    return this; }
    setSubtitle(subtitle) { this._subtitle = subtitle; return this; }
    setBody(body)         { this._body     = body;     return this; }
    setFooter(footer)     { this._footer   = footer;   return this; }

    // ── Metadata ──────────────────────────────────────────────────────────

    setContextInfo(obj) {
        if (typeof obj === 'object' && !Array.isArray(obj)) {
            this._contextInfo = obj;
        } else {
            return 'Type of contextInfo must be an Object';
        }
        return this;
    }

    setParams(obj) {
        if (typeof obj === 'object' && !Array.isArray(obj)) {
            this._params = obj;
        } else {
            return 'Type of params must be an Object';
        }
        return this;
    }

    setVariabel(name, value) {
        if (!Object.prototype.hasOwnProperty.call(this, name))
            return `Cannot find variabel ${name}, try getVariabelList()`;
        this[name] = value;
        return this;
    }

    getVariabel(name) {
        if (!Object.prototype.hasOwnProperty.call(this, name))
            return `Cannot find variabel ${name}, try getVariabelList()`;
        return this[name];
    }

    getVariabelList() { return Object.keys(this); }

    // ── Tombol raw ────────────────────────────────────────────────────────

    setButton(name, params) {
        this._beton.push({ name, buttonParamsJson: JSON.stringify(params) });
        return this;
    }

    setButtonV2(params) {
        this._betonOld.push(params);
        return this;
    }

    // ── List / Selection ──────────────────────────────────────────────────

    /** Dropdown list button. Lanjutkan dengan makeSections() + makeRow() */
    addSelection(title) {
        this._beton.push({ name: 'single_select', buttonParamsJson: JSON.stringify({ title, sections: [] }) });
        this._currentSelectionIndex = this._beton.length - 1;
        this._currentSectionIndex   = -1;
        return this;
    }

    makeSections(title = '', highlight_label = '') {
        if (this._currentSelectionIndex === -1)
            throw new Error('You need to create a selection first');
        const bp = JSON.parse(this._beton[this._currentSelectionIndex].buttonParamsJson);
        bp.sections.push({ title, highlight_label, rows: [] });
        this._currentSectionIndex = bp.sections.length - 1;
        this._beton[this._currentSelectionIndex].buttonParamsJson = JSON.stringify(bp);
        return this;
    }

    makeRow(header = '', title = '', description = '', id = '') {
        if (this._currentSelectionIndex === -1 || this._currentSectionIndex === -1)
            throw new Error('You need to create a selection and a section first');
        const bp = JSON.parse(this._beton[this._currentSelectionIndex].buttonParamsJson);
        bp.sections[this._currentSectionIndex].rows.push({ header, title, description, id });
        this._beton[this._currentSelectionIndex].buttonParamsJson = JSON.stringify(bp);
        return this;
    }

    // ── Jenis-jenis tombol ────────────────────────────────────────────────

    /** Tombol balas teks — kirim pesan teks otomatis saat diklik */
    addReply(display_text = '', id = '') {
        this._beton.push({ name: 'quick_reply', buttonParamsJson: JSON.stringify({ display_text, id }) });
        return this;
    }

    /** Versi lama quick reply (format button lama) */
    addReplyV2(displayText = 'Button', buttonId = 'btn') {
        this._betonOld.push({ buttonId, buttonText: { displayText }, type: 1 });
        this._type = 1;
        return this;
    }

    /** Tombol telepon — langsung dial nomor */
    addCall(display_text = '', id = '') {
        this._beton.push({ name: 'cta_call', buttonParamsJson: JSON.stringify({ display_text, id }) });
        return this;
    }

    /** Tombol buka URL — buka link di browser */
    addUrl(display_text = '', url = '', webview_interaction = false) {
        this._beton.push({
            name: 'cta_url',
            buttonParamsJson: JSON.stringify({ display_text, url, webview_interaction }),
        });
        return this;
    }

    /** Tombol salin teks — copy_code otomatis masuk clipboard */
    addCopy(display_text = '', copy_code = '', id = '') {
        this._beton.push({ name: 'cta_copy', buttonParamsJson: JSON.stringify({ display_text, copy_code, id }) });
        return this;
    }

    /** Tombol pengingat */
    addReminder(display_text = '', id = '') {
        this._beton.push({ name: 'cta_reminder', buttonParamsJson: JSON.stringify({ display_text, id }) });
        return this;
    }

    /** Tombol batalkan pengingat */
    addCancelReminder(display_text = '', id = '') {
        this._beton.push({ name: 'cta_cancel_reminder', buttonParamsJson: JSON.stringify({ display_text, id }) });
        return this;
    }

    /** Tombol minta alamat pengguna */
    addAddress(display_text = '', id = '') {
        this._beton.push({ name: 'address_message', buttonParamsJson: JSON.stringify({ display_text, id }) });
        return this;
    }

    /** Tombol kirim lokasi pengguna */
    addLocation() {
        this._beton.push({ name: 'send_location', buttonParamsJson: '' });
        return this;
    }

    /** Daftar struktur params yang bisa dipakai di setParams() */
    paramsList() {
        return {
            limited_time_offer: {
                text           : 'string',
                url            : 'string',
                copy_code      : 'string',
                expiration_time: 'number',
            },
            bottom_sheet: {
                in_thread_buttons_limit: 'number',
                divider_indices        : ['number'],
                list_title             : 'string',
                button_title           : 'string',
            },
            tap_target_configuration: {
                title       : 'string',
                description : 'string',
                canonical_url: 'string',
                domain      : 'string',
                buttonIndex : 'number',
            },
        };
    }

    // ── Kirim ──────────────────────────────────────────────────────────────

    async run(jid, conn, quoted = '', options = {}) {
        if (this._type === 0) {
            const message = {
                body  : { text: this._body },
                footer: { text: this._footer },
                header: {
                    title             : this._title,
                    subtitle          : this._subtitle,
                    hasMediaAttachment: !!this._data,
                    ...(this._data
                        ? await prepareWAMessageMedia(this._data, { upload: conn.waUploadToServer })
                        : {}),
                },
            };

            const msg = generateWAMessageFromContent(jid, {
                interactiveMessage: {
                    ...message,
                    contextInfo      : this._contextInfo,
                    nativeFlowMessage: {
                        messageParamsJson: JSON.stringify(this._params),
                        buttons          : this._beton,
                    },
                },
            }, { quoted });

            await conn.relayMessage(msg.key.remoteJid, msg.message, {
                messageId      : msg.key.id,
                additionalNodes: [{
                    tag    : 'biz',
                    attrs  : {},
                    content: [{
                        tag    : 'interactive',
                        attrs  : { type: 'native_flow', v: '1' },
                        content: [{ tag: 'native_flow', attrs: { v: '9', name: 'mixed' } }],
                    }],
                }],
                ...options,
            });

            return msg;
        } else {
            return await conn.sendMessage(jid, {
                ...(this._data ? this._data : {}),
                [this._data ? 'caption' : 'text']: this._body,
                title      : this._data ? null : this._title,
                footer     : this._footer,
                viewOnce   : true,
                contextInfo: this._contextInfo,
                buttons    : [
                    ...this._betonOld,
                    ...this._beton.map(b => ({
                        buttonId  : 'btn',
                        buttonText: { displayText: 'btn' },
                        type      : 1,
                        nativeFlowInfo: { name: b.name, paramsJson: b.buttonParamsJson },
                    })),
                ],
            }, { quoted });
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// AIRich — pesan AI-style (teks, kode, tabel, reels, sumber referensi)
// ─────────────────────────────────────────────────────────────────────────────

class AIRich {
    constructor() {
        this._submessages        = [];
        this._sections           = [];
        this._richResponseSources = [];
    }

    /** Tambah blok teks biasa */
    addText(text) {
        this._submessages.push({ messageType: 2, messageText: text });
        this._sections.push({
            view_model: {
                primitive: { text, __typename: 'GenAIMarkdownTextUXPrimitive' },
                __typename: 'GenAISingleLayoutViewModel',
            },
        });
        return this;
    }

    /** Tambah blok kode dengan syntax highlighting */
    addCode(language, code) {
        const meta = this._tokenizer(code, language);
        this._submessages.push({
            messageType  : 5,
            codeMetadata : {
                codeLanguage: language,
                codeBlocks  : meta.codeBlock,
            },
        });
        this._sections.push({
            view_model: {
                primitive: {
                    language,
                    code_blocks: meta.unified_codeBlock,
                    __typename : 'GenAICodeUXPrimitive',
                },
                __typename: 'GenAISingleLayoutViewModel',
            },
        });
        return this;
    }

    /** Tambah tabel — format: [[header1, header2], [row1col1, row1col2], ...] */
    addTable(table) {
        const meta = this._toTableMetadata(table);
        this._submessages.push({
            messageType  : 4,
            tableMetadata: { title: meta.title, rows: meta.rows },
        });
        this._sections.push({
            view_model: {
                primitive: { rows: meta.unified_rows, __typename: 'GenATableUXPrimitive' },
                __typename: 'GenAISingleLayoutViewModel',
            },
        });
        return this;
    }

    /** Tambah sumber referensi — format: [[profile_url, url, text], ...] */
    addSource(sources = []) {
        const source = sources.map(([profile_url, url, text]) => ({
            source_type        : 'THIRD_PARTY',
            source_display_name: text,
            source_subtitle    : 'AI',
            source_url         : url,
            favicon: { url: profile_url, mime_type: 'image/jpeg', width: 16, height: 16 },
        }));
        this._sections.push({
            view_model: {
                primitive: { sources: source, __typename: 'GenAISearchResultPrimitive' },
                __typename: 'GenAISingleLayoutViewModel',
            },
        });
        return this;
    }

    /** Tambah reels/video horizontal scroll */
    addReels(reelsItems = []) {
        this._submessages.push({
            messageType          : 9,
            contentItemsMetadata : {
                contentType  : 1,
                itemsMetadata: reelsItems.map(item => ({
                    reelItem: {
                        title         : item.title,
                        profileIconUrl: item.profileIconUrl,
                        thumbnailUrl  : item.thumbnailUrl,
                        videoUrl      : item.videoUrl,
                    },
                })),
            },
        });

        reelsItems.forEach((item, idx) => {
            this._richResponseSources.push({
                provider        : 'UNKNOWN',
                thumbnailCDNURL : item.thumbnailUrl,
                sourceProviderURL: item.videoUrl,
                sourceQuery     : '',
                faviconCDNURL   : item.profileIconUrl,
                citationNumber  : idx + 1,
                sourceTitle     : item.title,
            });
        });

        this._sections.push({
            view_model: {
                primitives: reelsItems.map(item => ({
                    reels_url  : item.videoUrl,
                    thumbnail_url: item.thumbnailUrl,
                    creator    : item.title,
                    avatar_url : item.profileIconUrl,
                    reels_title: item.reels_title,
                    likes_count : 0,
                    shares_count: 0,
                    view_count  : 0,
                    reel_source : 'IG',
                    is_verified : item.is_verified,
                    __typename  : 'GenAIReelPrimitive',
                })),
                __typename: 'GenAIHScrollLayoutViewModel',
            },
        });

        return this;
    }

    build({ forwarded = true } = {}) {
        const contextInfo = forwarded
            ? { forwardingScore: 1, isForwarded: true, forwardedAiBotMessageInfo: { botJid: '0@bot' }, forwardOrigin: 4 }
            : {};

        return {
            messageContextInfo: {
                deviceListMetadata       : {},
                deviceListMetadataVersion: 2,
                botMetadata: {
                    pluginMetadata            : {},
                    richResponseSourcesMetadata: { sources: this._richResponseSources },
                },
            },
            botForwardedMessage: {
                message: {
                    richResponseMessage: {
                        messageType    : 1,
                        submessages    : this._submessages,
                        unifiedResponse: {
                            data: Buffer.from(JSON.stringify({
                                response_id: crypto.randomUUID(),
                                sections   : this._sections,
                            })).toString('base64'),
                        },
                        contextInfo,
                    },
                },
            },
        };
    }

    async run(chat, conn, { forwarded, ...options } = {}) {
        const payload = this.build({ forwarded });
        return await conn.relayMessage(chat, payload, { ...options });
    }

    // ── Internal helpers ───────────────────────────────────────────────────

    _tokenizer(code, lang = 'javascript') {
        const keywordsMap = {
            javascript: new Set([
                'break','case','catch','continue','debugger','delete','do','else','finally',
                'for','function','if','in','instanceof','new','return','switch','this','throw',
                'try','typeof','var','void','while','with','true','false','null','undefined',
                'class','const','let','super','extends','export','import','yield','static',
                'constructor','async','await','get','set',
            ]),
        };

        const TYPE_MAP = { 0: 'DEFAULT', 1: 'KEYWORD', 2: 'METHOD', 3: 'STR', 4: 'NUMBER', 5: 'COMMENT' };
        const keywords = keywordsMap[lang] || new Set();
        const tokens   = [];
        let i = 0;

        const push = (content, type) => {
            if (!content) return;
            const last = tokens[tokens.length - 1];
            if (last && last.highlightType === type) last.codeContent += content;
            else tokens.push({ codeContent: content, highlightType: type });
        };

        while (i < code.length) {
            const c = code[i];

            if (/\s/.test(c)) {
                let s = i;
                while (i < code.length && /\s/.test(code[i])) i++;
                push(code.slice(s, i), 0);
                continue;
            }

            if (c === '/' && code[i + 1] === '/') {
                let s = i; i += 2;
                while (i < code.length && code[i] !== '\n') i++;
                push(code.slice(s, i), 5);
                continue;
            }

            if (c === '"' || c === "'" || c === '`') {
                let s = i; const q = c; i++;
                while (i < code.length) {
                    if (code[i] === '\\' && i + 1 < code.length) i += 2;
                    else if (code[i] === q) { i++; break; }
                    else i++;
                }
                push(code.slice(s, i), 3);
                continue;
            }

            if (/[0-9]/.test(c)) {
                let s = i;
                while (i < code.length && /[0-9.]/.test(code[i])) i++;
                push(code.slice(s, i), 4);
                continue;
            }

            if (/[a-zA-Z_$]/.test(c)) {
                let s = i;
                while (i < code.length && /[a-zA-Z0-9_$]/.test(code[i])) i++;
                const word = code.slice(s, i);
                let type = 0;
                if (keywords.has(word)) {
                    type = 1;
                } else {
                    let j = i;
                    while (j < code.length && /\s/.test(code[j])) j++;
                    if (code[j] === '(') type = 2;
                }
                push(word, type);
                continue;
            }

            push(c, 0);
            i++;
        }

        return {
            codeBlock       : tokens,
            unified_codeBlock: tokens.map(t => ({ content: t.codeContent, type: TYPE_MAP[t.highlightType] })),
        };
    }

    _toTableMetadata(arr) {
        if (!Array.isArray(arr) || arr.length < 2)
            throw new Error('Format tabel salah — harus array minimal 2 baris: [header, ...rows]');

        const [header, ...rows] = arr;
        const maxLen = Math.max(header.length, ...rows.map(r => r.length));
        const normalize = r => [...r, ...Array(maxLen - r.length).fill('')];

        const unified_rows = [
            { is_header: true,  cells: normalize(header) },
            ...rows.map(r => ({ is_header: false, cells: normalize(r) })),
        ];

        const rowsMeta = unified_rows.map(r => ({
            items: r.cells,
            ...(r.is_header ? { isHeading: true } : {}),
        }));

        return { title: '', rows: rowsMeta, unified_rows };
    }
}

// ─────────────────────────────────────────────────────────────────────────────

module.exports = { Button, AIRich };
