#!/usr/bin/env python3
"""Builds localized Google Play listing drafts from the English master copy.

Short descriptions are hand-written; the long description is machine-translated
and should get a human read before publishing. Run from the repo root:

    python3 tools/build_store_listings.py
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_locale_csv import protect, request_batch, restore  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LISTING = os.path.join(ROOT, "docs", "store_listing")
EN = os.path.join(LISTING, "en.md")

SHORT = {
    "pt_BR": "Conquiste territórios base por base. Estratégia rápida, offline e sem anúncios.",
    "fr": "Conquérez des territoires base par base. Stratégie rapide, hors ligne, sans pub.",
    "de": "Erobere Gebiete Basis für Basis. Schnelle Strategie, offline, ohne Werbung.",
    "it": "Conquista territori base dopo base. Strategia veloce, offline, senza pubblicità.",
    "ru": "Захватывайте территории база за базой. Быстрая стратегия, офлайн, без рекламы.",
    "tr": "Bölgeleri üs üs fethedin. Hızlı strateji, çevrimdışı, reklamsız.",
    "ar": "اغزو الأراضي قاعدة بقاعدة. استراتيجية سريعة، دون اتصال، بلا إعلانات.",
    "hi": "एक-एक बेस जीतकर इलाके फतह करें। तेज़ रणनीति, ऑफ़लाइन, बिना विज्ञापन।",
    "id": "Taklukkan wilayah basis demi basis. Strategi cepat, offline, tanpa iklan.",
    "vi": "Chinh phục từng căn cứ. Chiến thuật nhanh, ngoại tuyến, không quảng cáo.",
    "zh_CN": "逐个基地征服领土。快节奏策略，离线可玩，无广告。",
    "ja": "拠点を一つずつ奪って領土を征服。高速ストラテジー、オフライン対応、広告なし。",
    "ko": "기지를 하나씩 점령해 영토를 정복하세요. 빠른 전략, 오프라인, 광고 없음.",
}
HEAD = {
    "pt_BR": ("Nome do app", "Descrição curta", "Descrição completa"),
    "fr": ("Nom de l'application", "Description courte", "Description complète"),
    "de": ("App-Name", "Kurzbeschreibung", "Vollständige Beschreibung"),
    "it": ("Nome dell'app", "Descrizione breve", "Descrizione completa"),
    "ru": ("Название приложения", "Краткое описание", "Полное описание"),
    "tr": ("Uygulama adı", "Kısa açıklama", "Tam açıklama"),
    "ar": ("اسم التطبيق", "الوصف المختصر", "الوصف الكامل"),
    "hi": ("ऐप का नाम", "छोटा विवरण", "पूरा विवरण"),
    "id": ("Nama aplikasi", "Deskripsi singkat", "Deskripsi lengkap"),
    "vi": ("Tên ứng dụng", "Mô tả ngắn", "Mô tả đầy đủ"),
    "zh_CN": ("应用名称", "简短说明", "完整说明"),
    "ja": ("アプリ名", "短い説明", "詳細な説明"),
    "ko": ("앱 이름", "짧은 설명", "전체 설명"),
}
TITLE = {
    "pt_BR": "Google Play (Português do Brasil)",
    "fr": "Google Play (Français)",
    "de": "Google Play (Deutsch)",
    "it": "Google Play (Italiano)",
    "ru": "Google Play (Русский)",
    "tr": "Google Play (Türkçe)",
    "ar": "Google Play (العربية)",
    "hi": "Google Play (हिन्दी)",
    "id": "Google Play (Bahasa Indonesia)",
    "vi": "Google Play (Tiếng Việt)",
    "zh_CN": "Google Play（简体中文）",
    "ja": "Google Play（日本語）",
    "ko": "Google Play (한국어)",
}


def fenced_blocks(text: str) -> list[str]:
    return re.findall(r"```[^\n]*\n(.*?)```", text, re.S)


def main() -> int:
    en = open(EN, encoding="utf-8").read()
    blocks = fenced_blocks(en)
    if len(blocks) < 3:
        raise SystemExit("English listing must contain app name, short and full blocks")
    full_en = blocks[2].strip()
    for lang, short in SHORT.items():
        if len(short) > 80:
            raise SystemExit("short description for %s exceeds 80 characters" % lang)
        protected, values = protect(full_en)
        full = restore(request_batch([protected], "en", lang)[0], values).strip()
        if len(full) > 4000:
            raise SystemExit("full description for %s exceeds 4000 characters" % lang)
        head = HEAD[lang]
        out = (
            f"# invade.io — {TITLE[lang]}\n\n"
            f"## {head[0]} (9/30)\n\n```\ninvade.io\n```\n\n"
            f"## {head[1]}\n\n```\n{short}\n```\n\n"
            f"## {head[2]}\n\n```\n{full}\n```\n"
        )
        path = os.path.join(LISTING, f"{lang}.md")
        if os.path.exists(path) and "--force" not in sys.argv:
            print("skip (already reviewed)", path)
            continue
        open(path, "w", encoding="utf-8").write(out)
        print("wrote", path, len(full), "chars")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
