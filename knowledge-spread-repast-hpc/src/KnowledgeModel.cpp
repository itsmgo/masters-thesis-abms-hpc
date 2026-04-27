#include "KnowledgeModel.h"

#include "KnowledgeAgent.h"
#include "repast_hpc/AgentId.h"
#include "repast_hpc/AgentRequest.h"
#include "repast_hpc/Properties.h"
#include "repast_hpc/RepastProcess.h"
#include "repast_hpc/SVDataSetBuilder.h"
#include "repast_hpc/Utilities.h"
#include "repast_hpc/logger.h"

#include <boost/mpi.hpp>
#include <cmath>
#include <map>
#include <string>
#include <vector>

BOOST_CLASS_EXPORT_GUID(repast::SpecializedProjectionInfoPacket<
                            repast::RepastEdgeContent<KnowledgeAgent>>,
                        "SpecializedProjectionInfoPacket_EDGE");

const int NUM_CLUSTERS = 6;
const int CLUSTER_SIZE = 30000;
const double CLUSTER_STD_DEV = 24;
const double CLUSTER_CENTER_SCALE_FACTOR = 0.95;

const double WORLD_X_BOUND = 50.0;
const double WORLD_Y_BOUND = 50.0;

const int NUM_CENTROIDS = 8;

const int NETWORK_NEIGHBOUR_MAX_DEGREE = 3; // Should be 3 but I don't know if network->adjecents() works for non-local agents

const int GRAVITY_SAMPLE_RADIUS = 1;
const int GRAVITY_POPULATION_RADIUS = 5;

const int CONFERENCE_GENERATOR_SEED = 42;
const int CONFERENCE_SIZE = 20;

double distSq(const std::vector<double>& loc1, const std::vector<double>& loc2) {
    double dx = loc1[0] - loc2[0];
    double dy = loc1[1] - loc2[1];
    return dx * dx + dy * dy;
}

std::vector<KnowledgeAgent*> selectAdjacentsByDegree(
    KnowledgeAgent* agent,
    repast::SharedNetwork<KnowledgeAgent, repast::RepastEdge<KnowledgeAgent>,
                          repast::RepastEdgeContent<KnowledgeAgent>,
                          repast::RepastEdgeContentManager<KnowledgeAgent>>* network,
    int maxDegree) {

    std::set<KnowledgeAgent*> agentsAtCurrentDegree;
    std::set<KnowledgeAgent*> allFoundSocialAgents;

    agentsAtCurrentDegree.insert(agent);
    allFoundSocialAgents.insert(agent);

    for (int degree = 1; degree <= maxDegree; ++degree) {
        std::set<KnowledgeAgent*> agentsAtNextDegree;
        bool newAgentsFoundInThisDegree = false;
        for (KnowledgeAgent* currentAgent : agentsAtCurrentDegree) {
            std::vector<KnowledgeAgent*> directNeighboursOfCurrentAgent;
            network->adjacent(currentAgent, directNeighboursOfCurrentAgent);

            for (KnowledgeAgent* neighbour : directNeighboursOfCurrentAgent) {
                if (allFoundSocialAgents.find(neighbour) ==
                    allFoundSocialAgents.end()) {
                    // This neighbour has not been visited yet
                    agentsAtNextDegree.insert(neighbour);
                    allFoundSocialAgents.insert(neighbour);
                    newAgentsFoundInThisDegree = true;
                }
            }
        }
        if (!newAgentsFoundInThisDegree) {
            // No new agents found at this degree, so no more further degrees can be
            // explored
            break;
        }
        agentsAtCurrentDegree = agentsAtNextDegree;
    }

    // Exclude the original agent from the selection pool
    allFoundSocialAgents.erase(agent);

    // Convert the set of unique agents into a vector for random selection
    std::vector<KnowledgeAgent*> selectableAgents(allFoundSocialAgents.begin(),
                                                  allFoundSocialAgents.end());
    return selectableAgents;
}

struct ScientificPaper {
    std::vector<double> location;
    Color color;

    ScientificPaper(std::vector<double> loc)
        : location(loc)
        , color(BLACK) {}
};

struct KnowledgeCentroid {
    std::vector<double> location;
    Color color;

    KnowledgeCentroid(std::vector<double> loc, Color c)
        : location(loc)
        , color(c) {}
};

KnowledgeAgentPackageProvider::KnowledgeAgentPackageProvider(
    repast::SharedContext<KnowledgeAgent>* agentPtr)
    : context(agentPtr) {}

void KnowledgeAgentPackageProvider::providePackage(
    KnowledgeAgent* agent, std::vector<KnowledgeAgentPackage>& out) {
    repast::AgentId id = agent->getId();
    KnowledgeAgentPackage package;
    agent->provideContent(package);
    out.push_back(package);
}

void KnowledgeAgentPackageProvider::provideContent(
    repast::AgentRequest req, std::vector<KnowledgeAgentPackage>& out) {
    for (const auto& id : req.requestedAgents()) {
        providePackage(context->getAgent(id), out);
    }
}

KnowledgeAgentPackageReceiver::KnowledgeAgentPackageReceiver(
    repast::SharedContext<KnowledgeAgent>* agentPtr)
    : context(agentPtr) {}

KnowledgeAgent*
KnowledgeAgentPackageReceiver::createAgent(KnowledgeAgentPackage package) {
    repast::AgentId id(package.id, package.rank, package.type, package.currentRank);
    return new KnowledgeAgent(id, package.birth, package.position, package.color);
}

void KnowledgeAgentPackageReceiver::updateAgent(KnowledgeAgentPackage package) {
    repast::AgentId id(package.id, package.rank, package.type);
    KnowledgeAgent* agent = context->getAgent(id);
    agent->update(package);
}

KnowledgeSpreadModel::KnowledgeSpreadModel(std::string propsFile, int argc,
                                           char** argv,
                                           boost::mpi::communicator* comm)
    : context(comm) {
    props = new repast::Properties(propsFile, argc, argv, comm);
    runId = repast::strToInt(props->getProperty("run_id"));
    totalTicks_ = repast::strToInt(props->getProperty("totalTicks"));
    distThreshold_ = repast::strToDouble(props->getProperty("distThreshold"));
    useSocialNetData_ =
        repast::strToInt(props->getProperty("useSocialNetData")) == 1;
    runSocial_ = repast::strToInt(props->getProperty("runSocial")) == 1;
    runCentroid_ = repast::strToInt(props->getProperty("runCentroid")) == 1;

    // Initialize Projections (Space and Network)
    repast::GridDimensions dimensions(
        repast::Point<double>(-WORLD_X_BOUND, -WORLD_Y_BOUND),
        repast::Point<double>(WORLD_X_BOUND*2, WORLD_Y_BOUND*2));

    regionLayer = new repast::DiscreteValueLayer<std::pair<Color, std::vector<double>>, repast::StrictBorders>(
        "KnowledgeSpaceValueLayer", dimensions, true);

    socialNetwork =
        new repast::SharedNetwork<KnowledgeAgent, repast::RepastEdge<KnowledgeAgent>,
                                  repast::RepastEdgeContent<KnowledgeAgent>,
                                  repast::RepastEdgeContentManager<KnowledgeAgent>>(
            "SocialNetwork", false, &edgeContentManager);
    context.addProjection(socialNetwork);

    provider = new KnowledgeAgentPackageProvider(&context);
    receiver = new KnowledgeAgentPackageReceiver(&context);

    // Data collection
    // Create the data set builder for dynamic variables
    std::string dynamic_results_file("./output/dynamic_results.csv");
    repast::SVDataSetBuilder dynamic_builder(
        dynamic_results_file.c_str(), ",",
        repast::RepastProcess::instance()->getScheduleRunner().schedule());
    int rank = repast::RepastProcess::instance()->rank();

    // Create the individual dynamic data sets to be added to the builder
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_blue", new StatDataSource(this, StatType::TOTAL_BLUE, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_orange", new StatDataSource(this, StatType::TOTAL_ORANGE, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_red", new StatDataSource(this, StatType::TOTAL_RED, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_yellow", new StatDataSource(this, StatType::TOTAL_YELLOW, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_green", new StatDataSource(this, StatType::TOTAL_GREEN, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_purple", new StatDataSource(this, StatType::TOTAL_PURPLE, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_magenta", new StatDataSource(this, StatType::TOTAL_MAGENTA, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_white", new StatDataSource(this, StatType::TOTAL_WHITE, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "run_id", new StatDataSource(this, StatType::RUN_ID, rank),
        std::plus<double>()));

    dynamic_dataset_ = dynamic_builder.createDataSet();

    // Create the builder for static variables
    std::string static_results_file("./output/static_results.csv");
    repast::SVDataSetBuilder static_builder(
        static_results_file.c_str(), ",",
        repast::RepastProcess::instance()->getScheduleRunner().schedule());

    // Create the individual static data sets to be added to the builder
    static_builder.addDataSource(repast::createSVDataSource(
        "total_vertices", new StatDataSource(this, StatType::TOTAL_VERTICES, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "total_edges", new StatDataSource(this, StatType::TOTAL_EDGES, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "run_id", new StatDataSource(this, StatType::RUN_ID, rank),
        std::plus<double>()));

    static_dataset = static_builder.createDataSet();

    setupKnowledgeSpace();
    setupSocialNetwork();
}

KnowledgeSpreadModel::~KnowledgeSpreadModel() {
    delete props;
    delete provider;
    delete receiver;
    delete dynamic_dataset_;
}

void KnowledgeSpreadModel::setupKnowledgeSpace() {
    std::vector<std::vector<double>> candidatePaperLocs;
    LOG_RANK0(logger, repast::DEBUG, "Setting up knowledge space");
    std::vector<ScientificPaper> papers;
    std::vector<KnowledgeCentroid> centroids;

    std::vector<std::pair<double, double>> clusterPredefinedLocations = {
        {-6.108634, 10.140601},
        {-10.147067, 0.537975},
        {10.736579, 16.038066},
        {-22.348510, 15.329037},
        {-0.362956, -22.001765},
        {3.552401, 15.067330}
    };

    // Generate clusters
    for (int i = 0; i < NUM_CLUSTERS; i++) {
        // double centerX =
        //     repast::Random::instance()
        //         ->createNormalGenerator(0.0, WORLD_X_BOUND / 2.5)
        //         .next() *
        //     CLUSTER_CENTER_SCALE_FACTOR;
        // double centerY =
        //     repast::Random::instance()
        //         ->createNormalGenerator(0.0, WORLD_Y_BOUND / 2.5)
        //         .next() *
        //     CLUSTER_CENTER_SCALE_FACTOR;
        double centerX = clusterPredefinedLocations[i].first;
        double centerY = clusterPredefinedLocations[i].second;

        for (int j = 0; j < CLUSTER_SIZE / NUM_CLUSTERS; j++) {
            double directionAngle = repast::Random::instance()
                                        ->createUniDoubleGenerator(0.0, 360.0)
                                        .next();
            double directionMagnitude =
                abs(repast::Random::instance()
                        ->createNormalGenerator(0.0, CLUSTER_STD_DEV / 2)
                        .next());
            std::vector<double> paperLoc = {centerX, centerY};
            double angleRad = directionAngle * M_PI / 180.0;
            paperLoc[0] += directionMagnitude * cos(angleRad);
            paperLoc[1] += directionMagnitude * sin(angleRad);
            paperLoc[0] = std::min(WORLD_X_BOUND-1, std::max(-WORLD_X_BOUND+1, paperLoc[0]));
            paperLoc[1] = std::min(WORLD_Y_BOUND-1, std::max(-WORLD_Y_BOUND+1, paperLoc[1]));
            if (j % 100 == 0) {
                candidatePaperLocs.push_back(paperLoc);
            }
            papers.emplace_back(paperLoc);
        }
        logger.log(repast::DEBUG, "Created cluster of papers in ("+std::to_string(centerX)+", "+std::to_string(centerY)+"), id="+std::to_string(i));
    }

    std::vector<std::vector<double>> centroidPredefinedLocations = {
        {-6.108634, 10.140601},
        {-10.147067, 0.537975},
        {10.736579, 16.038066},
        {-22.348510, 15.329037},
        {-0.362956, -22.001765},
        {3.552401, 15.067330},
        {0.0, 0.0},
        {30.0, 30.0},
    };

    // Reset centroids
    for (int i = 0; i < NUM_CENTROIDS; i++) {
        int randomIndex =
            repast::Random::instance()
                ->createUniIntGenerator(0, candidatePaperLocs.size() - 1)
                .next();
        // std::vector<double> centroidLoc = candidatePaperLocs[randomIndex];
        std::vector<double> centroidLoc = centroidPredefinedLocations[i];
        Color centroidColor = ALL_COLORS[i + 1];
        centroids.emplace_back(centroidLoc, centroidColor);
        logger.log(repast::DEBUG, "Created knowledge centroid in ("+std::to_string(centroidLoc[0])+", "+std::to_string(centroidLoc[1])+"), color="+std::to_string(centroidColor));
    }

    // Update clusters
    // Step 1: Assign points to the nearest centroid
    for (ScientificPaper& paper : papers) {
        double minDist = std::numeric_limits<double>::max();
        Color closestCentroidColor = BLACK;

        for (KnowledgeCentroid centroid : centroids) {
            double currentDist = distSq(paper.location, centroid.location);
            if (currentDist < minDist) {
                minDist = currentDist;
                closestCentroidColor = centroid.color;
            }
        }
        paper.color = closestCentroidColor;
    }
    // Step 2: Move centroids to the center of their points
    for (KnowledgeCentroid& centroid : centroids) {
        double sumX = 0.0;
        double sumY = 0.0;
        int count = 0;

        for (ScientificPaper paper : papers) {
            if (paper.color == centroid.color) {
                sumX += paper.location[0];
                sumY += paper.location[1];
                count++;
            }
        }

        if (count > 0) {
            centroid.location = {sumX / count, sumY / count};
        }
        logger.log(repast::DEBUG, "Moved knowledge centroid to ("+std::to_string(centroid.location[0])+", "+std::to_string(centroid.location[1])+"), color="+std::to_string(centroid.color));
    }

    // Step 3: Populate the DiscreteValueLayer to simulate "colored patches"
    for (ScientificPaper& paper : papers) {
        for (KnowledgeCentroid centroid : centroids) {
            if (paper.color == centroid.color) {
                std::pair<Color, std::vector<double>> layerValue(
                    paper.color, centroid.location);
                regionLayer->set(layerValue, discretizeVec2(paper.location));
                break;
            }
        }
    }

    // Write to file each one of the coordinate color pairs that define the knowledge space, to be used in the serialization
    int rank = repast::RepastProcess::instance()->rank();
    if (rank == 0) {
        std::ofstream knowledgeSpaceOut("./output/knowledge_space.csv");
        if (knowledgeSpaceOut.is_open()) {
            knowledgeSpaceOut << "x,y,color,centroid_x,centroid_y\n";
            for (double x = -WORLD_X_BOUND + 1; x < WORLD_X_BOUND; x++) {
                for (double y = -WORLD_Y_BOUND + 1; y < WORLD_Y_BOUND; y++) {
                    auto layerValue = regionLayer->get(discretizeVec2({x, y}));
                    if (layerValue.first == BLACK) {
                        knowledgeSpaceOut << x << "," << y << "," << layerValue.first << "," << -50.0 << "," << -50.0 << "\n";
                        continue;
                    }
                    knowledgeSpaceOut << x << "," << y << "," << layerValue.first << "," << layerValue.second[0] << "," << layerValue.second[1] << "\n";
                }
            }
            knowledgeSpaceOut.close();
        } else {
            logger.log(repast::ERROR, "Unable to open file to write knowledge space data");
        }
    }

    LOG_RANK0(logger, repast::DEBUG, "Knowledge space successfully set up");
}

void KnowledgeSpreadModel::setupSocialNetwork() {
    LOG_RANK0(logger, repast::DEBUG, "Setting up social network");
    if (!useSocialNetData_) {
        logger.log(repast::ERROR, "Not implemented");
        return;
    }

    int rank = repast::RepastProcess::instance()->rank();
    int worldSize = repast::RepastProcess::instance()->worldSize();

    // Step 1: Parse birth CSV and create agents
    logger.log(repast::DEBUG,
               "Creating local agents for rank " + std::to_string(rank) + "...");
    std::string birthsFile = props->getProperty("birthFile");
    std::ifstream birthIn(birthsFile.c_str());
    if (!birthIn.is_open())
        return;

    std::string birthLine;
    int i = 0;
    std::map<std::string, int> agentIdByName;
    int totalLocalAgents = 0;
    while (std::getline(birthIn, birthLine)) {
        std::stringstream ss(birthLine);
        std::string idStr, nameStr, birthStr, xStr, yStr;

        std::getline(ss, idStr, ',');
        std::getline(ss, nameStr, ',');
        std::getline(ss, birthStr, ',');
        std::getline(ss, xStr, ',');
        std::getline(ss, yStr, ',');
        std::vector<double> agentLoc = {std::stod(xStr), std::stod(yStr)};

        int ownerRank = i % worldSize; // Modulo partitioning
        repast::AgentId id(i, rank, 0);
        if (ownerRank == rank) {
            // This agent belongs to this rank.
            KnowledgeAgent* agent = new KnowledgeAgent(id, std::stod(birthStr));
            context.addAgent(agent);
            agent->setPosition(agentLoc);
            agent->setColor(regionLayer->get(discretizeVec2(agentLoc)).first);
            totalLocalAgents++;
        }
        agentIdByName[nameStr] = id.id();
        i++;
        totalAgents++;
    }
    birthIn.close();
    logger.log(repast::DEBUG, "Created " + std::to_string(totalLocalAgents) +
                                  " local agents for rank " + std::to_string(rank));

    // Write to file each one of the agent's coordinate and color
    std::ofstream socialNetworkOut("./output/social_network_" + std::to_string(rank) + ".csv");
    if (socialNetworkOut.is_open()) {
        socialNetworkOut << "id,name,x,y,color\n";
        for (const auto& [name, id] : agentIdByName) {
            auto agent = context.getAgent(repast::AgentId(id, rank, 0));
            if (agent != nullptr) {
                std::vector<double> pos = agent->getPosition();
                socialNetworkOut << id << "," << name << "," << pos[0] << "," << pos[1] << "," << agent->getColor() << "\n";
            }
        }
        socialNetworkOut.close();
    } else {
        logger.log(repast::ERROR, "Unable to open file to write social network data");
    }


    // Step 2: Parse temporal edges
    logger.log(repast::DEBUG,
               "Storing temporal edges for rank " + std::to_string(rank) + "...");
    std::string edgesFile = props->getProperty("edgeFile");
    std::ifstream edgesIn(edgesFile.c_str());
    if (!edgesIn.is_open())
        return;

    std::string edgeLine;
    int edgeCounter = 0;
    while (std::getline(edgesIn, edgeLine)) {
        std::stringstream ss(edgeLine);
        std::string sourceName, targetName, timeStr;

        std::getline(ss, sourceName, ',');
        std::getline(ss, targetName, ',');
        std::getline(ss, timeStr, ',');
        int tick = std::stoi(timeStr);

        auto it = networkEvolutionMap.find(tick);
        auto itEdge1 = agentIdByName.find(sourceName);
        auto itEdge2 = agentIdByName.find(targetName);
        if (itEdge1 != agentIdByName.end() && itEdge2 != agentIdByName.end()) {
            auto edge = std::make_pair(itEdge1->second, itEdge2->second);
            logger.log(repast::DEBUG, "Storing edge " + std::to_string(itEdge1->second) + "-" +std::to_string(itEdge2->second) + " on tick "+std::to_string(tick));
            edgeCounter++;
            if (it != networkEvolutionMap.end()) {
                auto edges = it->second;
                edges.push_back(edge);
                networkEvolutionMap[tick] = edges;
            } else {
                networkEvolutionMap[tick] = {edge};
            }
        }
    }
    totalEdges = edgeCounter;
    edgesIn.close();

    LOG_RANK0(logger, repast::DEBUG, "Social Network successfully set up");
}

void KnowledgeSpreadModel::evolveNetwork(int currentTick,
                                         std::vector<KnowledgeAgent*> agents) {
    int rank = repast::RepastProcess::instance()->rank();
    int worldSize = repast::RepastProcess::instance()->worldSize();

    // Step 1: Detect Required Ghosts
    logger.log(repast::DEBUG,
               "Requesting ghost agents for rank " + std::to_string(rank) + "...");
    repast::AgentRequest request(rank);
    std::set<int> requestedGhosts; // Prevent duplicate requests

    auto it = networkEvolutionMap.find(currentTick);
    if (it == networkEvolutionMap.end()) {
        return;
    }
    auto edges = it->second;

    for (auto edge : edges) {
        int sourceId = edge.first;
        int targetId = edge.second;

        int sourceOwner = sourceId % worldSize;
        int targetOwner = targetId % worldSize;

        // If rank owns the source, but not the target, request a ghost of the target
        if (sourceOwner == rank && targetOwner != rank) {
            if (requestedGhosts.find(targetId) == requestedGhosts.end()) {
                repast::AgentId ghost_id(targetId, targetOwner, 0);
                ghost_id.currentRank(targetOwner);
                request.addRequest(ghost_id);
                requestedGhosts.insert(targetId);
            }
        }
        // If rank owns the target, but not the source, request a ghost of the source
        else if (targetOwner == rank && sourceOwner != rank) {
            if (requestedGhosts.find(sourceId) == requestedGhosts.end()) {
                repast::AgentId ghost_id(sourceId, sourceOwner, 0);
                ghost_id.currentRank(sourceOwner);
                request.addRequest(ghost_id);
                requestedGhosts.insert(sourceId);
            }
        } else if (rank == 0) {
            if (requestedGhosts.find(targetId) == requestedGhosts.end()) {
                repast::AgentId ghost_id(targetId, targetOwner, 0);
            }
            if (requestedGhosts.find(sourceId) == requestedGhosts.end()) {
                repast::AgentId ghost_id(sourceId, sourceOwner, 0);
            }
        }
    }

    // Step 2: Fetch the Ghosts via MPI
    logger.log(repast::DEBUG, "Requested " + std::to_string(requestedGhosts.size()) +
                                  " ghost agents for rank " + std::to_string(rank));
    repast::RepastProcess::instance()
        ->requestAgents<KnowledgeAgent, KnowledgeAgentPackage,
                        KnowledgeAgentPackageProvider,
                        KnowledgeAgentPackageReceiver>(context, request, *provider,
                                                       *receiver, *receiver);

    // Step 3: Build the Edges
    logger.log(repast::DEBUG,
               "Creating edges for rank " + std::to_string(rank) + "...");
    int totalLocalEdges = 0;
    // Now that local agents and ghost agents are in the context, we can link them
    for (auto edge : edges) {
        int sourceId = edge.first;
        int targetId = edge.second;

        int sourceOwner = sourceId % worldSize;
        int targetOwner = targetId % worldSize;

        // If this rank owns at least one of the nodes, the edge must exist in this
        // rank's network
        if (sourceOwner == rank || targetOwner == rank) {
            repast::AgentId srcId(sourceId, sourceOwner, 0);
            repast::AgentId tgtId(targetId, targetOwner, 0);

            KnowledgeAgent* src = context.getAgent(srcId);
            KnowledgeAgent* tgt = context.getAgent(tgtId);

            // Add edge to the Repast SharedNetwork
            if (src != nullptr && tgt != nullptr) {
                socialNetwork->addEdge(src, tgt);
                totalLocalEdges++;
            }
        }
    }
    logger.log(repast::DEBUG, "Created " + std::to_string(totalLocalEdges) +
                                  " edges for rank " + std::to_string(rank));
}

void KnowledgeSpreadModel::step() {
    logger.log(repast::DEBUG, "Starting step");
    int rank = repast::RepastProcess::instance()->rank();
    double currentTick =
        repast::RepastProcess::instance()->getScheduleRunner().currentTick();

    std::vector<KnowledgeAgent*> localAgents;
    context.selectAgents(repast::SharedContext<KnowledgeAgent>::LOCAL,
                         context.size(), localAgents);
    std::vector<KnowledgeAgent*> nonLocalAgents;
    context.selectAgents(repast::SharedContext<KnowledgeAgent>::NON_LOCAL,
                         context.size(), nonLocalAgents);

    // Phase 1: Calculate stochastic transitions based on current t
    if (runSocial_) {
        for (KnowledgeAgent* agent : localAgents) {
            if (agent->getBirth() > currentTick) {
                continue;
            }
            std::vector<double> currentLoc = agent->getPosition();
            std::vector<double> targetLoc = getSocialLoc(agent, currentLoc);
            agent->applyMovement(targetLoc, currentTick, distThreshold_, regionLayer);

            currentLoc = agent->getPosition();
            targetLoc = getCloseLoc(agent, currentLoc);
            agent->applyMovement(targetLoc, currentTick, distThreshold_, regionLayer);
        }
    }
    if (runCentroid_) {
        for (KnowledgeAgent* agent : localAgents) {
            if (agent->getBirth() > currentTick) {
                continue;
            }
            std::vector<double> currentLoc = agent->getPosition();
            std::vector<double> targetLoc = getCentroidLoc(currentLoc);
            agent->applyMovement(targetLoc, currentTick, distThreshold_, regionLayer);
        }
    }
    logger.log(repast::DEBUG, "Applied all movements");

    // Phase 2: Synchronize ghost agents across MPI processes
    repast::RepastProcess::instance()
        ->synchronizeAgentStatus<KnowledgeAgent, KnowledgeAgentPackage,
                                 KnowledgeAgentPackageProvider,
                                 KnowledgeAgentPackageReceiver>(
            context, *provider, *receiver, *receiver);

    repast::AgentRequest request;
    std::set<repast::AgentId> requiredAgentIds;

    // Step 2.0: Evolve network
    evolveNetwork(currentTick, localAgents);

    // Step 2.1: compute needed agents
    int worldSize = repast::RepastProcess::instance()->worldSize();
    for (KnowledgeAgent* agent : localAgents) {
        std::vector<KnowledgeAgent*> neighbours = selectAdjacentsByDegree(
            agent, socialNetwork, NETWORK_NEIGHBOUR_MAX_DEGREE);
        for (auto& neighbour : neighbours) {
            repast::AgentId id = neighbour->getId();
            if (!context.contains(id)) {
                requiredAgentIds.insert(id);
            }
        }
    }

    // Step 2.2: request only NEW ones and synchronize cache
    for (const repast::AgentId requiredAgentId : requiredAgentIds) {
        if (synchronizedAgentIds.count(requiredAgentId) == 0) {
            request.addRequest(requiredAgentId);
        }
    }
    for (const repast::AgentId synchronizedAgentId : synchronizedAgentIds) {
        if (requiredAgentIds.count(synchronizedAgentId) == 0) {
            request.addCancellation(synchronizedAgentId);
        }
    }

    // Step 2.3: batch request
    if (request.requestCount() > 0) {
        repast::RepastProcess::instance()
            ->requestAgents<KnowledgeAgent, KnowledgeAgentPackage,
                            KnowledgeAgentPackageProvider,
                            KnowledgeAgentPackageReceiver>(
                context, request, *provider, *receiver, *receiver);
    }

    // Step 2.4: remove no longer needed ghosts from context
    std::vector<repast::AgentId> cancellations = request.cancellations();
    std::vector<repast::AgentId>::iterator idToRemove = cancellations.begin();
    while (idToRemove != cancellations.end()) {
        context.importedAgentRemoved(*idToRemove);
        idToRemove++;
    }

    repast::RepastProcess::instance()
        ->synchronizeProjectionInfo<KnowledgeAgent, KnowledgeAgentPackage,
                                    KnowledgeAgentPackageProvider,
                                    KnowledgeAgentPackageReceiver>(
            context, *provider, *receiver, *receiver);

    repast::RepastProcess::instance()
        ->synchronizeAgentStates<KnowledgeAgentPackage,
                                 KnowledgeAgentPackageProvider,
                                 KnowledgeAgentPackageReceiver>(*provider,
                                                                *receiver);
    synchronizedAgentIds = requiredAgentIds;
    logger.log(repast::DEBUG, "Synchronized all agents");
}

std::vector<double>
KnowledgeSpreadModel::getSocialLoc(KnowledgeAgent* agent,
                                   std::vector<double> currentLoc) {
    // Find neighbours in the social network
    std::vector<KnowledgeAgent*> neighbours =
        selectAdjacentsByDegree(agent, socialNetwork, NETWORK_NEIGHBOUR_MAX_DEGREE);

    if (!neighbours.empty()) {
        // Pick a random neighbor
        int randomIndex = repast::Random::instance()
                              ->createUniIntGenerator(0, neighbours.size() - 1)
                              .next();
        KnowledgeAgent* target = neighbours[randomIndex];
        std::vector<double> targetLoc = target->getPosition();
        return targetLoc;
    }
    return currentLoc;
}

std::vector<double>
KnowledgeSpreadModel::getCentroidLoc(std::vector<double> currentLoc) {
    // Agents move towards the center of their respective mental model region
    auto layerValue = regionLayer->get(discretizeVec2(currentLoc));
    if (layerValue.first != BLACK)
        return layerValue.second;
    return currentLoc;
}

std::vector<double>
KnowledgeSpreadModel::getCloseLoc(KnowledgeAgent* agent,
                                  std::vector<double> currentLoc) {
    // Agents learn from a close agent in the semantic layer

    // Iterate over all agents independent of LOCAL or NON_LOCAL and find the closest one within the distance threshold
    std::vector<KnowledgeAgent*> localAgents;
    context.selectAgents(repast::SharedContext<KnowledgeAgent>::LOCAL,
                          context.size(), localAgents);
    std::vector<KnowledgeAgent*> nonLocalAgents;
    context.selectAgents(repast::SharedContext<KnowledgeAgent>::NON_LOCAL,
                          context.size(), nonLocalAgents);
    std::vector<KnowledgeAgent*> allAgents;
    allAgents.insert(allAgents.end(), localAgents.begin(), localAgents.end());
    allAgents.insert(allAgents.end(), nonLocalAgents.begin(), nonLocalAgents.end());

    // Filter agents that are within the distance threshold and are already born, and put them in a cache to randomly select from
    std::vector<KnowledgeAgent*> neighbours;
    for (KnowledgeAgent* other : allAgents) {
        if (other->getId() == agent->getId() || other->getBirth() > repast::RepastProcess::instance()->getScheduleRunner().currentTick()) {
            continue;
        }
        double distance = sqrt(distSq(currentLoc, other->getPosition()));
        if (distance < distThreshold_) {
            neighbours.push_back(other);
        }
    }
    if (neighbours.empty()) {
        return currentLoc;
    }
    
    int randomIndex = repast::Random::instance()
                          ->createUniIntGenerator(0, neighbours.size() - 1)
                          .next();
    KnowledgeAgent* target = neighbours[randomIndex];
    std::vector<double> targetLoc = target->getPosition();

    // logger.log(repast::DEBUG, "Agent " + std::to_string(agent->getId().id()) + " with current location (" + std::to_string(currentLoc[0]) + ", " + std::to_string(currentLoc[1]) +
    //                               " found closest location ( " + std::to_string(closestLoc[0]) + ", " + std::to_string(closestLoc[1]) + " ) with distance " + std::to_string(minDist));

    return targetLoc;
}

void KnowledgeSpreadModel::initSchedule(repast::ScheduleRunner& runner) {
    runner.scheduleEvent(
        1, 1,
        repast::Schedule::FunctorPtr(new repast::MethodFunctor<KnowledgeSpreadModel>(
            this, &KnowledgeSpreadModel::step)));
    runner.scheduleEvent(
        0.5, 1,
        repast::Schedule::FunctorPtr(new repast::MethodFunctor<KnowledgeSpreadModel>(
            this, &KnowledgeSpreadModel::recordDynamicResults)));
    runner.scheduleEvent(
        0.5, 1,
        repast::Schedule::FunctorPtr(new repast::MethodFunctor<KnowledgeSpreadModel>(
            this, &KnowledgeSpreadModel::recordLocations)));
    runner.scheduleEvent(
        0.5, 1,
        repast::Schedule::FunctorPtr(new repast::MethodFunctor<KnowledgeSpreadModel>(
            this, &KnowledgeSpreadModel::recordNetwork)));
    runner.scheduleEndEvent(
        repast::Schedule::FunctorPtr(new repast::MethodFunctor<KnowledgeSpreadModel>(
            this, &KnowledgeSpreadModel::recordDynamicResults)));
    // runner.scheduleEndEvent(
    //     repast::Schedule::FunctorPtr(new repast::MethodFunctor<KnowledgeSpreadModel>(
    //         this, &KnowledgeSpreadModel::recordStaticResults)));
    runner.scheduleStop(totalTicks_);
}

void KnowledgeSpreadModel::recordDynamicResults() {
    // colors = BLUE, ORANGE, RED, YELLOW, GREEN, PURPLE, MAGENTA, WHITE
    localBlue = 0;
    localOrange = 0;
    localRed = 0;
    localYellow = 0;
    localGreen = 0;
    localPurple = 0;
    localMagenta = 0;
    localWhite = 0;
    std::vector<KnowledgeAgent*> localAgents;
    context.selectAgents(repast::SharedContext<KnowledgeAgent>::LOCAL,
                         context.size(), localAgents);
    for (KnowledgeAgent* agent : localAgents) {
        if (agent->getColor() == BLUE) {
            localBlue++;
        } else if (agent->getColor() == ORANGE) {
            localOrange++;
        } else if (agent->getColor() == RED) {
            localRed++;
        } else if (agent->getColor() == YELLOW) {
            localYellow++;
        } else if (agent->getColor() == GREEN) {
            localGreen++;
        } else if (agent->getColor() == PURPLE) {
            localPurple++;
        } else if (agent->getColor() == MAGENTA) {
            localMagenta++;
        } else if (agent->getColor() == WHITE) {
            localWhite++;
        }
    }

    dynamic_dataset_->record();
    dynamic_dataset_->write();
}

void KnowledgeSpreadModel::recordLocations() {
    int rank = repast::RepastProcess::instance()->rank();
    int tick = repast::RepastProcess::instance()->getScheduleRunner().currentTick();
    logger.log(repast::DEBUG, "Recording locations for rank " + std::to_string(rank));

    if (tick == 0) {
        // Write header to file
        std::ofstream locationOut("./output/locations_" + std::to_string(rank) + ".csv");
        if (locationOut.is_open()) {
            locationOut << "tick,agent_id,x,y,color\n";
            locationOut.close();
        } else {
            logger.log(repast::ERROR, "Unable to open file to write location data");
            return;
        }
    }
    // append to file each one of the agent's coordinate and color at the current tick
    std::ofstream locationOut("./output/locations_" + std::to_string(rank) + ".csv", std::ios_base::app);
    if (locationOut.is_open()) {
        std::vector<KnowledgeAgent*> localAgents;
        context.selectAgents(repast::SharedContext<KnowledgeAgent>::LOCAL,
                              context.size(), localAgents);
        for (KnowledgeAgent* agent : localAgents) {
            std::vector<double> pos = agent->getPosition();
            locationOut << tick << "," << agent->getId().id() << "," << pos[0] << "," << pos[1] << "," << agent->getColor() << "\n";
        }
        locationOut.close();
    } else {
        logger.log(repast::ERROR, "Unable to open file to write location data");
    }
}

void KnowledgeSpreadModel::recordNetwork() {
    // Writes a GML file for each tick and rank, containing all the edges present in that rank at that tick.
    // Writes node positions and colors as node attributes.
    int rank = repast::RepastProcess::instance()->rank();
    int tick = repast::RepastProcess::instance()->getScheduleRunner().currentTick();

    logger.log(repast::DEBUG, "Recording network for rank " + std::to_string(rank));
    std::ofstream networkOut("./output/network_" + std::to_string(rank) + "_" + std::to_string(tick) + ".gml");
    if (networkOut.is_open()) {
        networkOut << "graph [\n";
        // Write nodes with attributes
        std::vector<KnowledgeAgent*> localAgents;
        context.selectAgents(repast::SharedContext<KnowledgeAgent>::LOCAL,
                              context.size(), localAgents);
        std::vector<KnowledgeAgent*> nonLocalAgents;
        context.selectAgents(repast::SharedContext<KnowledgeAgent>::NON_LOCAL,
                              context.size(), nonLocalAgents);
        std::vector<KnowledgeAgent*> allAgents = localAgents;
        allAgents.insert(allAgents.end(), nonLocalAgents.begin(), nonLocalAgents.end());

        std::set<std::pair<int, int>> writtenEdges; // To avoid duplicates in undirected graph
        for (KnowledgeAgent* agent : allAgents) {
            if (agent->getBirth() > tick) {
                continue; // Agent not born yet
            }
            bool isGhost = false;
            if (std::find(localAgents.begin(), localAgents.end(), agent) == localAgents.end()) {
                isGhost = true;
            }
            std::vector<double> pos = agent->getPosition();
            networkOut << "  node [\n";
            networkOut << "    id " << agent->getId().id() << "\n";
            networkOut << "    x " << pos[0] << "\n";
            networkOut << "    y " << pos[1] << "\n";
            networkOut << "    color " << agent->getColor() << "\n";
            networkOut << "    isGhost " << isGhost << "\n";
            networkOut << "  ]\n";

            // Write edges
            std::vector<KnowledgeAgent*> neighbours;
            socialNetwork->adjacent(agent, neighbours);
            for (KnowledgeAgent* neighbour : neighbours) {
                if (writtenEdges.count({std::min(agent->getId().id(), neighbour->getId().id()),
                                       std::max(agent->getId().id(), neighbour->getId().id())}) > 0) {
                    continue; // Edge already written
                }
                if (neighbour->getBirth() > tick) {
                    continue; // Neighbour not born yet
                }
                if (std::find(allAgents.begin(), allAgents.end(), neighbour) == allAgents.end()) {
                    logger.log(repast::ERROR, "Neighbour agent with ID " + std::to_string(neighbour->getId().id()) + " not found in context for rank " + std::to_string(rank));
                    continue; // Neighbour not in this rank's context (shouldn't happen due to synchronization, but just in case)
                }
                networkOut << "  edge [\n";
                networkOut << "    source " << agent->getId().id() << "\n";
                networkOut << "    target " << neighbour->getId().id() << "\n";
                networkOut << "  ]\n";
                writtenEdges.insert({std::min(agent->getId().id(), neighbour->getId().id()),
                                     std::max(agent->getId().id(), neighbour->getId().id())});
            }
        }
        networkOut << "]\n";
        networkOut.close();
    } else {
        logger.log(repast::ERROR, "Unable to open file to write network data");
    }
}

void KnowledgeSpreadModel::recordStaticResults() {
    int rank = repast::RepastProcess::instance()->rank();
    logger.log(repast::DEBUG, "Recording results for rank " + std::to_string(rank));

    // local_degree_sum = 0;
    // local_normals = 0;
    // local_scholars = 0;
    // local_influencers = 0;
    // local_b_bots = 0;
    // local_fc_bots = 0;
    // local_super_spreaders = 0;
    //
    // std::vector<KnowledgeAgent*> local_agents;
    // context.selectAgents(repast::SharedContext<KnowledgeAgent>::LOCAL,
    //                      context.size(), local_agents);
    // for (KnowledgeAgent* agent : local_agents) {
    //     std::vector<KnowledgeAgent*> neighbours;
    //     network->successors(agent, neighbours);
    //     local_degree_sum += neighbours.size();
    //
    //     if (neighbours.size() > 100 && neighbours.size() < 200) {
    //         local_super_spreaders++;
    //     }
    //
    //     if (agent->getAgentClass() == NORMAL) {
    //         local_normals++;
    //     } else if (agent->getAgentClass() == SCHOLAR) {
    //         local_scholars++;
    //     } else if (agent->getAgentClass() == INFLUENCER) {
    //         local_influencers++;
    //     } else if (agent->getAgentClass() == BOT) {
    //         if (agent->getState() == BELIEVER) {
    //             local_b_bots++;
    //         } else if (agent->getState() == FACT_CHECKER) {
    //             local_fc_bots++;
    //         }
    //     }
    // }

    static_dataset->record();
    static_dataset->write();
    if (rank == 0)
        props->writeToSVFile("./output/props.csv");

    logger.log(repast::DEBUG, "Recorded results successfully.");
}

/* DATA SOURCES */

double StatDataSource::getData() {
    // For distributed metrics: return the local fractional contribution.
    // When Repast sums these across all ranks, it yields the global metric.
    switch (type) {
        case StatType::TOTAL_BLUE:
            return model->localBlue;
        case StatType::TOTAL_ORANGE:
            return model->localOrange;
        case StatType::TOTAL_RED:
            return model->localRed;
        case StatType::TOTAL_YELLOW:
            return model->localYellow;
        case StatType::TOTAL_GREEN:
            return model->localGreen;
        case StatType::TOTAL_PURPLE:
            return model->localPurple;
        case StatType::TOTAL_MAGENTA:
            return model->localMagenta;
        case StatType::TOTAL_WHITE:
            return model->localWhite;

        // For globally known constants:
        // We only return the value on Rank 0 and 0 on all other ranks.
        // This prevents std::plus from multiplying the parameter by the number of
        // ranks
        case StatType::RUN_ID:
            return rank == 0 ? model->runId : 0;
        case StatType::TOTAL_VERTICES:
            return rank == 0 ? model->totalAgents : 0;
        case StatType::TOTAL_EDGES:
            return rank == 0 ? model->totalEdges : 0;
        default:
            return 0.0;
    }
}
