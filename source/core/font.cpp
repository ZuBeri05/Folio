#include "core/font.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>

#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"

namespace folio {

uint32_t utf8Next(const char*& s, const char* end) {
    if (s >= end) return 0;
    const unsigned char c0 = static_cast<unsigned char>(*s);
    if (c0 < 0x80) {
        ++s;
        return c0;
    }
    int extra = 0;
    uint32_t cp = 0;
    if ((c0 & 0xE0) == 0xC0) {
        extra = 1;
        cp = c0 & 0x1Fu;
    } else if ((c0 & 0xF0) == 0xE0) {
        extra = 2;
        cp = c0 & 0x0Fu;
    } else if ((c0 & 0xF8) == 0xF0) {
        extra = 3;
        cp = c0 & 0x07u;
    } else {
        ++s;
        return 0xFFFD;
    }
    if (s + extra >= end) {
        s = end;
        return 0xFFFD;
    }
    for (int i = 1; i <= extra; ++i) {
        const unsigned char ci = static_cast<unsigned char>(s[i]);
        if ((ci & 0xC0) != 0x80) {
            s += i;
            return 0xFFFD;
        }
        cp = (cp << 6) | (ci & 0x3Fu);
    }
    s += extra + 1;
    return cp;
}

FontFace::~FontFace() {
    delete info_;
    std::free(data_);
}

bool FontFace::loadMemory(const void* data, size_t size) {
    if (data == nullptr || size == 0) return false;
    std::unique_ptr<unsigned char, decltype(&std::free)> loaded(
        static_cast<unsigned char*>(std::malloc(size)), &std::free);
    if (!loaded) return false;
    std::memcpy(loaded.get(), data, size);
    auto info = std::make_unique<::stbtt_fontinfo>();
    if (stbtt_InitFont(info.get(), loaded.get(), 0) == 0) return false;
    delete info_;
    std::free(data_);
    cache_.clear();
    data_ = loaded.release();
    info_ = info.release();
    return true;
}

bool FontFace::loadFile(const char* path) {
    std::unique_ptr<FILE, decltype(&std::fclose)> file(std::fopen(path, "rb"), &std::fclose);
    if (!file) return false;
    if (std::fseek(file.get(), 0, SEEK_END) != 0) return false;
    const long size = std::ftell(file.get());
    if (size <= 0 || std::fseek(file.get(), 0, SEEK_SET) != 0) return false;
    std::unique_ptr<unsigned char, decltype(&std::free)> loaded(
        static_cast<unsigned char*>(std::malloc(static_cast<size_t>(size))), &std::free);
    if (!loaded) return false;
    if (std::fread(loaded.get(), 1, size, file.get()) != static_cast<size_t>(size)) return false;
    auto info = std::make_unique<::stbtt_fontinfo>();
    if (stbtt_InitFont(info.get(), loaded.get(), 0) == 0) return false;
    delete info_;
    std::free(data_);
    cache_.clear();
    data_ = loaded.release();
    info_ = info.release();
    return true;
}

float FontFace::ascent(float pixelSize) const {
    // ArkUI fontSize is the em size, so map em -> pixels (not the taller
    // ascent+descent box, which would render every glyph ~30% too small).
    if (info_ == nullptr) return pixelSize * 0.88f;
    int a = 0, d = 0, g = 0;
    stbtt_GetFontVMetrics(info_, &a, &d, &g);
    return a * stbtt_ScaleForMappingEmToPixels(info_, pixelSize);
}

float FontFace::descent(float pixelSize) const {
    if (info_ == nullptr) return pixelSize * 0.22f;
    int a = 0, d = 0, g = 0;
    stbtt_GetFontVMetrics(info_, &a, &d, &g);
    return -d * stbtt_ScaleForMappingEmToPixels(info_, pixelSize);
}

float FontFace::advance(uint32_t codepoint, float pixelSize) {
    if (info_ == nullptr) return pixelSize * 0.5f;
    int advance = 0, bearing = 0;
    stbtt_GetCodepointHMetrics(info_, static_cast<int>(codepoint), &advance, &bearing);
    return advance * stbtt_ScaleForMappingEmToPixels(info_, pixelSize);
}

const Glyph* FontFace::glyph(uint32_t codepoint, float pixelSize) {
    const uint64_t key = (static_cast<uint64_t>(static_cast<int>(pixelSize * 4.f)) << 32) |
                         static_cast<uint64_t>(codepoint);
    auto it = cache_.find(key);
    if (it != cache_.end()) return it->second.w > 0 ? &it->second : nullptr;
    if (info_ == nullptr) return nullptr;

    const float scale = stbtt_ScaleForMappingEmToPixels(info_, pixelSize);
    int x0 = 0, y0 = 0, x1 = 0, y1 = 0;
    stbtt_GetCodepointBitmapBox(info_, static_cast<int>(codepoint), scale, scale, &x0, &y0, &x1, &y1);
    int advance = 0, bearing = 0;
    stbtt_GetCodepointHMetrics(info_, static_cast<int>(codepoint), &advance, &bearing);

    Glyph g;
    g.advance = advance * scale;
    g.bearingX = x0;
    g.bearingY = -y0;
    g.w = x1 - x0;
    g.h = y1 - y0;
    if (g.w > 0 && g.h > 0) {
        g.coverage.resize(static_cast<size_t>(g.w) * g.h);
        stbtt_MakeCodepointBitmap(info_, g.coverage.data(), g.w, g.h, g.w, scale, scale,
                                  static_cast<int>(codepoint));
    }
    auto res = cache_.emplace(key, std::move(g));
    return res.first->second.w > 0 ? &res.first->second : nullptr;
}

bool FontBook::load(const char* regularPath, const char* boldPath) {
    const bool okRegular = regular_.loadFile(regularPath);
    const bool okBold = bold_.loadFile(boldPath);
    return okRegular && okBold;
}

}  // namespace folio
