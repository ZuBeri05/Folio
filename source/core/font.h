#pragma once

#include <string>
#include <unordered_map>
#include <vector>

#include "core/math.h"

struct stbtt_fontinfo;

namespace folio {

/** Decodes one UTF-8 codepoint, advancing the pointer. Invalid bytes yield U+FFFD. */
uint32_t utf8Next(const char*& s, const char* end);

/** A glyph rendered at one pixel size. */
struct Glyph {
    int w = 0;
    int h = 0;
    int bearingX = 0;
    int bearingY = 0;
    float advance = 0.f;
    std::vector<uint8_t> coverage;  // 8-bit alpha
};

/**
 * One TTF (Regular or Bold) plus a cache of glyphs at several pixel sizes.
 * stb_truetype can render the same face at any scale, so the file is loaded
 * once and only the small per-size bitmaps accumulate.
 */
class FontFace {
public:
    ~FontFace();

    bool loadFile(const char* path);
    bool loadMemory(const void* data, size_t size);
    bool loaded() const { return info_ != nullptr; }

    float ascent(float pixelSize) const;
    float descent(float pixelSize) const;
    float advance(uint32_t codepoint, float pixelSize);
    const Glyph* glyph(uint32_t codepoint, float pixelSize);

private:
    ::stbtt_fontinfo* info_ = nullptr;
    unsigned char* data_ = nullptr;
    std::unordered_map<uint64_t, Glyph> cache_;
};

/** App font sizes are quantized to 0.5 px so the glyph cache stays small. */
class FontBook {
public:
    bool load(const char* regularPath, const char* boldPath);
    bool loaded() const { return regular_.loaded(); }

    FontFace& face(bool bold) { return bold ? bold_ : regular_; }
    const FontFace& face(bool bold) const { return bold ? bold_ : regular_; }

    static float quantize(float size) { return std::round(size * 2.f) * 0.5f; }

private:
    FontFace regular_;
    FontFace bold_;
};

}  // namespace folio