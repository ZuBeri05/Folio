#pragma once

#include <string>

#include "domain/models.h"

namespace folio {

/**
 * Local persistence. The HarmonyOS build used preferences under
 * "app_data_v1"; here it becomes a JSON file on the SD card, with the same
 * field names so a saved file can be eyeballed against the original.
 */
class Store {
public:
    /** Resolves and creates the data directory ("sdmc:/switch/folio"). */
    static bool init();
    static const std::string& path();

    static AppData load();
    static bool save(const AppData& data);
};

/** JSON serialization, exposed for round-trip tests. */
std::string toJson(const AppData& data);
AppData fromJson(const std::string& text);

}  // namespace folio
