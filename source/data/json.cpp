#include "data/json.h"

#include <cmath>
#include <cstdio>
#include <cstring>

namespace folio {

namespace {

const Json kNull;

void escapeTo(std::string& out, const std::string& s) {
    out.push_back('"');
    for (char c : s) {
        switch (c) {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (static_cast<unsigned char>(c) < 0x20) {
                    char buf[8];
                    std::snprintf(buf, sizeof(buf), "\\u%04x", c);
                    out += buf;
                } else {
                    out.push_back(c);
                }
        }
    }
    out.push_back('"');
}

void numberTo(std::string& out, double v) {
    if (!std::isfinite(v)) {
        out += "0";
        return;
    }
    if (v == std::floor(v) && std::fabs(v) < 1e15) {
        char buf[32];
        std::snprintf(buf, sizeof(buf), "%lld", static_cast<long long>(v));
        out += buf;
        return;
    }
    char buf[40];
    std::snprintf(buf, sizeof(buf), "%.10g", v);
    out += buf;
}

void dumpTo(std::string& out, const Json& v, int indent, int depth) {
    const std::string pad(static_cast<size_t>(indent) * (depth + 1), ' ');
    const std::string padEnd(static_cast<size_t>(indent) * depth, ' ');
    switch (v.type()) {
        case Json::Type::Null: out += "null"; break;
        case Json::Type::Bool: out += v.asBool() ? "true" : "false"; break;
        case Json::Type::Number: numberTo(out, v.asNumber()); break;
        case Json::Type::String: escapeTo(out, v.asString()); break;
        case Json::Type::Array: {
            if (v.items().empty()) {
                out += "[]";
                break;
            }
            out += "[";
            bool first = true;
            for (const auto& item : v.items()) {
                if (!first) out += ",";
                first = false;
                if (indent > 0) {
                    out += "\n";
                    out += pad;
                }
                dumpTo(out, item, indent, depth + 1);
            }
            if (indent > 0) {
                out += "\n";
                out += padEnd;
            }
            out += "]";
            break;
        }
        case Json::Type::Object: {
            if (v.members().empty()) {
                out += "{}";
                break;
            }
            out += "{";
            bool first = true;
            for (const auto& kv : v.members()) {
                if (!first) out += ",";
                first = false;
                if (indent > 0) {
                    out += "\n";
                    out += pad;
                }
                escapeTo(out, kv.first);
                out += indent > 0 ? ": " : ":";
                dumpTo(out, kv.second, indent, depth + 1);
            }
            if (indent > 0) {
                out += "\n";
                out += padEnd;
            }
            out += "}";
            break;
        }
    }
}

struct Parser {
    const char* s;
    const char* end;
    bool ok = true;

    void skipWs() {
        while (s < end && (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r')) ++s;
    }

    bool consume(char c) {
        skipWs();
        if (s < end && *s == c) {
            ++s;
            return true;
        }
        return false;
    }

    void appendUtf8(std::string& out, unsigned cp) {
        if (cp < 0x80) {
            out.push_back(static_cast<char>(cp));
        } else if (cp < 0x800) {
            out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else if (cp < 0x10000) {
            out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }

    std::string parseString() {
        std::string out;
        if (!consume('"')) {
            ok = false;
            return out;
        }
        while (s < end) {
            const char c = *s++;
            if (c == '"') return out;
            if (c != '\\') {
                out.push_back(c);
                continue;
            }
            if (s >= end) break;
            const char e = *s++;
            switch (e) {
                case '"': out.push_back('"'); break;
                case '\\': out.push_back('\\'); break;
                case '/': out.push_back('/'); break;
                case 'b': out.push_back('\b'); break;
                case 'f': out.push_back('\f'); break;
                case 'n': out.push_back('\n'); break;
                case 'r': out.push_back('\r'); break;
                case 't': out.push_back('\t'); break;
                case 'u': {
                    unsigned cp = 0;
                    for (int i = 0; i < 4 && s < end; ++i) {
                        const char h = *s++;
                        cp <<= 4;
                        if (h >= '0' && h <= '9') cp |= static_cast<unsigned>(h - '0');
                        else if (h >= 'a' && h <= 'f') cp |= static_cast<unsigned>(h - 'a' + 10);
                        else if (h >= 'A' && h <= 'F') cp |= static_cast<unsigned>(h - 'A' + 10);
                    }
                    appendUtf8(out, cp);
                    break;
                }
                default: ok = false; break;
            }
        }
        ok = false;
        return out;
    }

    Json parseValue(int depth = 0) {
        if (depth > 64) {
            ok = false;
            return Json();
        }
        skipWs();
        if (s >= end) {
            ok = false;
            return Json();
        }
        const char c = *s;
        if (c == '{') {
            ++s;
            Json obj = Json::object();
            skipWs();
            if (consume('}')) return obj;
            while (s < end) {
                const std::string key = parseString();
                if (!ok) return obj;
                if (!consume(':')) {
                    ok = false;
                    return obj;
                }
                obj[key] = parseValue(depth + 1);
                if (!ok) return obj;
                skipWs();
                if (consume(',')) continue;
                if (consume('}')) return obj;
                ok = false;
                return obj;
            }
            ok = false;
            return obj;
        }
        if (c == '[') {
            ++s;
            Json arr = Json::array();
            skipWs();
            if (consume(']')) return arr;
            while (s < end) {
                arr.push(parseValue(depth + 1));
                if (!ok) return arr;
                skipWs();
                if (consume(',')) continue;
                if (consume(']')) return arr;
                ok = false;
                return arr;
            }
            ok = false;
            return arr;
        }
        if (c == '"') return Json::string(parseString());
        if (std::strncmp(s, "true", 4) == 0) {
            s += 4;
            return Json::boolean(true);
        }
        if (std::strncmp(s, "false", 5) == 0) {
            s += 5;
            return Json::boolean(false);
        }
        if (std::strncmp(s, "null", 4) == 0) {
            s += 4;
            return Json();
        }
        char* last = nullptr;
        const double v = std::strtod(s, &last);
        if (last == s) {
            ok = false;
            return Json();
        }
        s = last;
        return Json::number(v);
    }
};

}  // namespace

Json Json::boolean(bool v) {
    Json j;
    j.type_ = Type::Bool;
    j.bool_ = v;
    return j;
}

Json Json::number(double v) {
    Json j;
    j.type_ = Type::Number;
    j.num_ = v;
    return j;
}

Json Json::string(const std::string& v) {
    Json j;
    j.type_ = Type::String;
    j.str_ = v;
    return j;
}

Json Json::array() {
    Json j;
    j.type_ = Type::Array;
    return j;
}

Json Json::object() {
    Json j;
    j.type_ = Type::Object;
    return j;
}

const Json& Json::operator[](const char* key) const {
    for (const auto& kv : members_) {
        if (kv.first == key) return kv.second;
    }
    return kNull;
}

Json& Json::operator[](const char* key) {
    for (auto& kv : members_) {
        if (kv.first == key) return kv.second;
    }
    members_.emplace_back(key, Json());
    return members_.back().second;
}

bool Json::has(const char* key) const {
    for (const auto& kv : members_) {
        if (kv.first == key) return true;
    }
    return false;
}

void Json::push(const Json& value) { items_.push_back(value); }

const Json& Json::at(size_t i) const { return i < items_.size() ? items_[i] : kNull; }

std::string Json::dump(int indent) const {
    std::string out;
    dumpTo(out, *this, indent, 0);
    return out;
}

Json Json::parse(const std::string& text, bool* ok) {
    Parser p{text.c_str(), text.c_str() + text.size()};
    Json value = p.parseValue();
    if (ok != nullptr) *ok = p.ok;
    return value;
}

}  // namespace folio
