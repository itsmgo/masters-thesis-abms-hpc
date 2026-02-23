#ifndef NETWORK_UTILS
#define NETWORK_UTILS

#include <algorithm>
#include <fstream>
#include <iostream>
#include <map>
#include <random>
#include <sstream>
#include <unordered_map>
#include <vector>

const int FLUID_COMMUNITIES_MAX_ITER = 100;
const int FLUID_COMMUNITIES_SEED = 42;

// Parses a .gml network file to fill the nodes and edges structures
inline void parseGmlFile(const std::string& filename,
                         std::vector<std::pair<int, int>>& nodes,
                         std::vector<std::pair<int, int>>& edges) {
    std::basic_ifstream<char> file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: Could not open file " << filename;
        return;
    }

    std::string line;
    bool in_node = false;
    bool in_edge = false;

    // Temporary variables to hold data while inside a block
    int current_id = -1;
    int current_degree = 0;
    int current_source = -1;
    int current_target = -1;

    while (std::getline(file, line)) {
        std::basic_istringstream<char> iss(line);
        std::string key;

        // Skip empty lines or lines with only whitespaces
        if (!(iss >> key))
            continue;

        if (key == "node") {
            in_node = true;
            current_id = -1;
            current_degree = 0; // Reset for the new node
        } else if (key == "edge") {
            in_edge = true;
            current_source = -1;
            current_target = -1; // Reset for the new edge
        } else if (key == "]") {
            // End of a block: save the extracted data into the arrays
            if (in_node) {
                nodes.push_back({current_id, current_degree});
                in_node = false;
            } else if (in_edge) {
                edges.push_back({current_source, current_target});
                in_edge = false;
            }
        }
        // If we are currently inside a node block, look for node attributes
        else if (in_node) {
            if (key == "id") {
                iss >> current_id;
            } else if (key == "degree") {
                iss >> current_degree;
            }
        }
        // If we are currently inside an edge block, look for edge attributes
        else if (in_edge) {
            if (key == "source") {
                iss >> current_source;
            } else if (key == "target") {
                iss >> current_target;
            }
        }
    }
    file.close();

    // Sort by number of edges descending
    std::sort(nodes.begin(), nodes.end(),
              [](const std::pair<int, int>& lhs, const std::pair<int, int>& rhs) {
                  return lhs.second < rhs.second;
              });
}

// Run the Asynchronous Fluid Communities algorithm to find the k distinct clusters
inline std::map<int, int>
fluidCommunities(const std::vector<std::pair<int, int>>& nodes,
                 const std::vector<std::pair<int, int>>& edges, int k,
                 int max_iterations = FLUID_COMMUNITIES_MAX_ITER,
                 unsigned int seed = FLUID_COMMUNITIES_SEED) {
    // 1. Map original Node IDs to contiguous 0-indexed IDs for faster array access
    std::unordered_map<int, int> id_to_index;
    std::vector<int> index_to_id;
    for (const auto& node : nodes) {
        id_to_index[node.first] = index_to_id.size();
        index_to_id.push_back(node.first);
    }
    int num_nodes = index_to_id.size();

    // 2. Build the Adjacency List
    std::vector<std::vector<int>> adj(num_nodes);
    for (const auto& edge : edges) {
        // Ensure both source and target exist in our parsed nodes
        if (id_to_index.count(edge.first) && id_to_index.count(edge.second)) {
            int u = id_to_index[edge.first];
            int v = id_to_index[edge.second];
            adj[u].push_back(v);
            adj[v].push_back(u);
        }
    }

    // 3. Initialize RNG and state arrays
    std::mt19937 gen(seed);

    std::vector<int> communities(num_nodes, -1);
    std::vector<int> comm_sizes(k, 0);

    // 4. Seed k random unique nodes with the k fluids
    std::vector<int> all_indices(num_nodes);
    std::iota(all_indices.begin(), all_indices.end(), 0);
    std::shuffle(all_indices.begin(), all_indices.end(), gen);

    for (int i = 0; i < k; ++i) {
        int seed_node = all_indices[i];
        communities[seed_node] = i;
        comm_sizes[i] = 1;
    }

    // 5. Run the asynchronous updates
    for (int iter = 0; iter < max_iterations; ++iter) {
        bool changed = false;

        // Shuffle the update order of nodes for this iteration (asynchronous aspect)
        std::shuffle(all_indices.begin(), all_indices.end(), gen);

        for (int u : all_indices) {
            int c_old = communities[u];

            // Rule: A fluid cannot disappear. If this node is the last one
            // of its community, we skip it.
            if (c_old != -1 && comm_sizes[c_old] == 1) {
                continue;
            }

            // Count occurrences of each community in the neighborhood
            std::map<int, int> neighbor_counts;
            for (int v : adj[u]) {
                if (communities[v] != -1) {
                    neighbor_counts[communities[v]]++;
                }
            }

            if (neighbor_counts.empty())
                continue;

            // Find the community with the highest density
            double max_density = -1.0;
            std::vector<int> best_comms;

            for (const auto& pair : neighbor_counts) {
                int c = pair.first;
                int count = pair.second;

                // Density formula: (edges connected to community) / (size of
                // community)
                double density = static_cast<double>(count) / comm_sizes[c];

                if (density > max_density) {
                    max_density = density;
                    best_comms.clear();
                    best_comms.push_back(c);
                } else if (density == max_density) {
                    best_comms.push_back(c);
                }
            }

            // Tie-breaking: Pick randomly among the communities tied for max density
            std::uniform_int_distribution<> dist(0, best_comms.size() - 1);
            int c_new = best_comms[dist(gen)];

            // Update state if the node changed community
            if (c_new != c_old) {
                if (c_old != -1)
                    comm_sizes[c_old]--;
                comm_sizes[c_new]++;
                communities[u] = c_new;
                changed = true;
            }
        }

        // Convergence check: If no nodes changed state, we are done
        if (!changed) {
            break;
        }
    }

    // 6. Map back to original IDs and return
    std::map<int, int> result;
    for (int i = 0; i < num_nodes; ++i) {
        result[index_to_id[i]] = communities[i];
    }
    return result;
}

#endif
