#pragma once

#include <map>
#include <memory>
#include <string>
#include <vector>

namespace folio {

/** Tiny JSON value used for the app's save file. */
class Json {
public:
    enum class Type { Null, Bool, Number, String, Array, Object };

    Json() = default;
    static Json boolean(bool v);
    static Json number(double v);
    static Json string(const std::string& v);
    static Json array();
    static Json object();

    Type type() const { return type_; }
    bool isObject() const { return type_ == Type::Object; }
    bool isArray() const { return type_ == Type::Array; }

    double asNumber(double fallback = 0.0) const { return type_ == Type::Number ? num_ : fallback; }
    bool asBool(bool fallback = false) const { return type_ == Type::Bool ? bool_ : fallback; }
    const std::string& asString() const { return str_; }
    std::string asString(const std::string& fallback) const { return type_ == Type::String ? str_ : fallback; }

    /** Object access; returns a shared Null value when missing. */
    const Json& operator[](const char* key) const;
    const Json& operator[](const std::string& key) const { return (*this)[key.c_str()]; }
    Json& operator[](const char* key);
    Json& operator[](const std::string& key) { return (*this)[key.c_str()]; }
    bool has(const char* key) const;

    void push(const Json& value);
    size_t size() const { return items_.size(); }
    const Json& at(size_t i) const;
    const std::vector<Json>& items() const { return items_; }
    const std::vector<std::pair<std::string, Json>>& members() const { return members_; }

    std::string dump(int indent = 0) const;
    static Json parse(const std::string& text, bool* ok = nullptr);

private:
    Type type_ = Type::Null;
    bool bool_ = false;
    double num_ = 0.0;
    std::string str_;
    std::vector<Json> items_;
    std::vector<std::pair<std::string, Json>> members_;
};

}  // namespace folio
