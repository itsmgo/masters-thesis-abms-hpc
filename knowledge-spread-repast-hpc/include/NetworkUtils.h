#ifndef NETWORK_UTILS
#define NETWORK_UTILS

#include <fstream>
#include <iostream>
#include <sstream>
#include <unordered_set>
#include <vector>

const int FLUID_COMMUNITIES_MAX_ITER = 100;
const int FLUID_COMMUNITIES_SEED = 42;

inline void parseCsvFile(const std::string& filename,
                         std::vector<std::pair<int, int>>& nodes,
                         std::vector<std::pair<int, int>>& edges) {
    nodes.clear();
    edges.clear();

    std::ifstream file(filename);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + filename);
    }

    std::string line;

    // Skip header
    std::getline(file, line);

    std::unordered_set<int> uniqueNodes;

    while (std::getline(file, line)) {
        if (line.empty()) {
            continue;
        }
        std::stringstream ss(line);
        std::string id1Str, id2Str;
        if (!std::getline(ss, id1Str, ',')) {
            continue;
        }
        if (!std::getline(ss, id2Str)) {
            continue;
        }

        int id1 = std::stoi(id1Str);
        int id2 = std::stoi(id2Str);

        edges.emplace_back(id1, id2);
        uniqueNodes.insert(id1);
        uniqueNodes.insert(id2);
    }

    for (int id : uniqueNodes) {
        nodes.emplace_back(id, id);
    }
}

#endif
