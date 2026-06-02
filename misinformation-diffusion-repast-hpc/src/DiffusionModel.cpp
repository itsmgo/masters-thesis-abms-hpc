#include "DiffusionModel.h"

#include "DiffusionAgent.h"
#include "NetworkUtils.h"
#include "mpi.h"
#include "repast_hpc/AgentId.h"
#include "repast_hpc/AgentRequest.h"
#include "repast_hpc/Properties.h"
#include "repast_hpc/RepastProcess.h"
#include "repast_hpc/SVDataSetBuilder.h"
#include "repast_hpc/Utilities.h"
#include "repast_hpc/logger.h"

#include <boost/mpi.hpp>
#include <map>
#include <string>
#include <TAU.h>

BOOST_CLASS_EXPORT_GUID(repast::SpecializedProjectionInfoPacket<
                            repast::RepastEdgeContent<DiffusionAgent>>,
                        "SpecializedProjectionInfoPacket_EDGE");

constexpr int INFLUENCER_PERCENTAGE = 1;
constexpr double BOT_P_VERIFY = 0.0;
constexpr double BOT_P_FORGET = 0.0;
constexpr int MIN_NETWORK_COMMUNITIES_K = 4;

DiffusionAgentPackageProvider::DiffusionAgentPackageProvider(
    repast::SharedContext<DiffusionAgent>* agentPtr)
    : context(agentPtr) {}

void DiffusionAgentPackageProvider::providePackage(
    DiffusionAgent* agent, std::vector<DiffusionAgentPackage>& out) {
    repast::AgentId id = agent->getId();
    DiffusionAgentPackage package;
    agent->provideContent(package);
    out.push_back(package);
}

void DiffusionAgentPackageProvider::provideContent(
    repast::AgentRequest req, std::vector<DiffusionAgentPackage>& out) {
    for (const auto& id : req.requestedAgents()) {
        providePackage(context->getAgent(id), out);
    }
}

DiffusionAgentPackageReceiver::DiffusionAgentPackageReceiver(
    repast::SharedContext<DiffusionAgent>* agentPtr)
    : context(agentPtr) {}

DiffusionAgent*
DiffusionAgentPackageReceiver::createAgent(DiffusionAgentPackage package) {
    repast::AgentId id(package.id, package.rank, package.type, package.currentRank);
    return new DiffusionAgent(id, static_cast<AgentClass>(package.agentClass), 0.0,
                              0.0, static_cast<BeliefState>(package.state), package.extraMessageBytes);
}

void DiffusionAgentPackageReceiver::updateAgent(DiffusionAgentPackage package) {
    repast::AgentId id(package.id, package.rank, package.type);
    DiffusionAgent* agent = context->getAgent(id);
    agent->update(package);
}

MisinformationDiffusionModel::MisinformationDiffusionModel(
    std::string propsFile, int argc, char** argv, boost::mpi::communicator* comm)
    : context(comm) {
    props = new repast::Properties(propsFile, argc, argv, comm);
    run_id = repast::strToInt(props->getProperty("run_id"));
    network_file_ = props->getProperty("network_file");
    total_ticks_ = repast::strToInt(props->getProperty("total_ticks"));
    alpha_ = repast::strToDouble(props->getProperty("alpha_hoax_credibility"));
    beta_ = repast::strToDouble(props->getProperty("beta_spreading_rate"));
    influencer_p_verify_ =
        repast::strToDouble(props->getProperty("influencer_p_verify"));
    influencer_p_forget_ =
        repast::strToDouble(props->getProperty("influencer_p_forget"));
    believer_percentage_ =
        repast::strToDouble(props->getProperty("believer_percentage"));
    influencer_p_verify_ =
        repast::strToDouble(props->getProperty("influencer_p_verify"));
    influencer_p_forget_ =
        repast::strToDouble(props->getProperty("influencer_p_forget"));
    normal_p_verify_ = repast::strToDouble(props->getProperty("normal_p_verify"));
    normal_p_forget_ = repast::strToDouble(props->getProperty("normal_p_forget"));
    scholar_p_verify_ = repast::strToDouble(props->getProperty("scholar_p_verify"));
    scholar_p_forget_ = repast::strToDouble(props->getProperty("scholar_p_forget"));
    scholars_community_ = repast::strToInt(props->getProperty("scholars_community"));
    partitioning_strat_ = props->getProperty("partitioning_strat");
    extra_compute_cycles_ = repast::strToInt(props->getProperty("extra_compute_cycles"));
    extra_message_bytes_ = repast::strToInt(props->getProperty("extra_message_bytes"));
    bot_p_believer_ = repast::strToDouble(props->getProperty("bot_p_believer"));
    bot_p_fact_checker_ =
        repast::strToDouble(props->getProperty("bot_p_fact_checker"));
    bot_p_ = bot_p_believer_ + bot_p_fact_checker_;
    network =
        new repast::SharedNetwork<DiffusionAgent, repast::RepastEdge<DiffusionAgent>,
                                  repast::RepastEdgeContent<DiffusionAgent>,
                                  repast::RepastEdgeContentManager<DiffusionAgent>>(
            "FacebookNet", false, &edgeContentManager);
    context.addProjection(network);

    provider = new DiffusionAgentPackageProvider(&context);
    receiver = new DiffusionAgentPackageReceiver(&context);

    // Data collection
    // Create the data set builder
    std::string dynamic_results_file("./output/dynamic_results.csv");
    repast::SVDataSetBuilder dynamic_builder(
        dynamic_results_file.c_str(), ",",
        repast::RepastProcess::instance()->getScheduleRunner().schedule());
    int rank = repast::RepastProcess::instance()->rank();

    // Create the individual data sets to be added to the builder
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_believers", new StatDataSource(this, StatType::TOTAL_BELIEVERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_fact_checkers",
        new StatDataSource(this, StatType::TOTAL_FACTCHECKERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "total_susceptibles",
        new StatDataSource(this, StatType::TOTAL_SUSCEPTIBLES, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "influencer_believers",
        new StatDataSource(this, StatType::INFLUENCER_BELIEVERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "influencer_fact_checkers",
        new StatDataSource(this, StatType::INFLUENCER_FACTCHECKERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "influencer_susceptibles",
        new StatDataSource(this, StatType::INFLUENCER_SUSCEPTIBLES, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "scholar_believers",
        new StatDataSource(this, StatType::SCHOLAR_BELIEVERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "scholar_fact_checkers",
        new StatDataSource(this, StatType::SCHOLAR_FACTCHECKERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "scholar_susceptibles",
        new StatDataSource(this, StatType::SCHOLAR_SUSCEPTIBLES, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "normal_believers",
        new StatDataSource(this, StatType::NORMAL_BELIEVERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "normal_fact_checkers",
        new StatDataSource(this, StatType::NORMAL_FACTCHECKERS, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "normal_susceptibles",
        new StatDataSource(this, StatType::NORMAL_SUSCEPTIBLES, rank),
        std::plus<double>()));
    dynamic_builder.addDataSource(repast::createSVDataSource(
        "run_id", new StatDataSource(this, StatType::RUN_ID, rank),
        std::plus<double>()));

    dynamic_dataset_ = dynamic_builder.createDataSet();

    // Create the builder. It will automatically generate the CSV header.
    std::string static_results_file("./output/static_results.csv");
    repast::SVDataSetBuilder static_builder(
        static_results_file.c_str(), ",",
        repast::RepastProcess::instance()->getScheduleRunner().schedule());

    // ... add your static parameters here ...
    static_builder.addDataSource(repast::createSVDataSource(
        "total_vertices", new StatDataSource(this, StatType::TOTAL_VERTICES, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "total_edges", new StatDataSource(this, StatType::TOTAL_EDGES, rank),
        std::plus<double>()));

    static_builder.addDataSource(repast::createSVDataSource(
        "avg_degree", new StatDataSource(this, StatType::AVG_DEGREE, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "%_normal", new StatDataSource(this, StatType::PCT_NORMAL, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "%_scholar", new StatDataSource(this, StatType::PCT_SCHOLAR, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "%_influencer", new StatDataSource(this, StatType::PCT_INFLUENCER, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "%_b_bot", new StatDataSource(this, StatType::PCT_B_BOT, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "%_fc_bot", new StatDataSource(this, StatType::PCT_FC_BOT, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "total_super_spreaders",
        new StatDataSource(this, StatType::TOTAL_SUPER_SPREADERS, rank),
        std::plus<double>()));
    static_builder.addDataSource(repast::createSVDataSource(
        "run_id", new StatDataSource(this, StatType::RUN_ID, rank),
        std::plus<double>()));

    static_dataset = static_builder.createDataSet();

    initNetwork();
}

MisinformationDiffusionModel::~MisinformationDiffusionModel() {
    delete props;
    delete provider;
    delete receiver;
    delete dynamic_dataset_;
}

int MisinformationDiffusionModel::getNodeOwnerRank(int node_id, std::map<int, int>* node_id_to_community_map) {
    if (partitioning_strat_ == "node_id_modulo") {
        int world_size = repast::RepastProcess::instance()->worldSize();
        return node_id % world_size;
    } else if (partitioning_strat_ == "node_community_modulo") {
        int world_size = repast::RepastProcess::instance()->worldSize();
        int community_id = (*node_id_to_community_map).at(node_id); 
        return community_id % world_size;
    } else {
        throw std::invalid_argument("Unsupported partitioning strategy: " + partitioning_strat_);
    }
}

void MisinformationDiffusionModel::initNetwork() {
    int rank = repast::RepastProcess::instance()->rank();
    int world_size = repast::RepastProcess::instance()->worldSize();

    // Step 0: Parsing
    TAU_PROFILE_TIMER(parse_timer, "MisinformationDiffusionModel::initNetwork__networkParsing", "", TAU_DEFAULT);
    TAU_PROFILE_START(parse_timer);
    logger.log(repast::DEBUG,
               "Starting parsing of " + network_file_ + " network file...");
    std::vector<std::pair<int, int>> nodes; // (node_id, num_edges)
    std::vector<std::pair<int, int>> edges; // (source_node_id, target_node_id)

    if (network_file_.substr(network_file_.find_last_of(".") + 1) == "gml") {
        parseGmlFile(network_file_, nodes, edges);
    } else if (network_file_.substr(network_file_.find_last_of(".") + 1) == "csv") {
        parseCsvFile(network_file_, nodes, edges);
    } else {
        throw std::invalid_argument("Unsupported file format: " + network_file_);
    }
    TAU_PROFILE_STOP(parse_timer);

    TAU_PROFILE_TIMER(comm_dectector_timer, "MisinformationDiffusionModel::initNetwork__communityDetection", "", TAU_DEFAULT);
    TAU_PROFILE_START(comm_dectector_timer);
    int total_communities = world_size;
    if (total_communities < MIN_NETWORK_COMMUNITIES_K) {
      total_communities *= 2;
    }
    std::map<int, int> node_id_to_community_map =
        fluidCommunities(nodes, edges, std::max(world_size, total_communities));
    TAU_PROFILE_STOP(comm_dectector_timer);

    int total_nodes = nodes.size();
    logger.log(repast::DEBUG, "Parsed network file and detected " +
                                  std::to_string(total_nodes) + " nodes with " +
                                  std::to_string(edges.size()) + " edges");

    // Calculate exact target counts based on global network size
    int target_influencers = total_nodes * INFLUENCER_PERCENTAGE / 100.0;
    int target_bots = total_nodes * bot_p_;

    // Separate non-scholar nodes
    std::vector<int> non_scholar_nodes;
    for (const auto& node : nodes) {
        if (node_id_to_community_map.at(node.first) != scholars_community_) {
            non_scholar_nodes.push_back(node.first);
            continue;
        }
    }

    // Distribute the agent classes
    std::unordered_map<int, AgentClass> preassigned_class;
    for (std::size_t i = 0; i < non_scholar_nodes.size(); ++i) {
        int node_id = non_scholar_nodes[i];
        if (i < target_influencers) {
            preassigned_class[node_id] = AgentClass::INFLUENCER;
        } else if (i < target_influencers + target_bots) {
            preassigned_class[node_id] = AgentClass::BOT;
        } else {
            preassigned_class[node_id] = AgentClass::NORMAL;
        }
    }

    // Step 1: Create Local Agents
    TAU_PROFILE_TIMER(agent_creation_timer, "MisinformationDiffusionModel::initNetwork__agentCreation", "", TAU_DEFAULT);
    TAU_PROFILE_START(agent_creation_timer);
    logger.log(repast::DEBUG,
               "Creating local agents for rank " + std::to_string(rank) + "...");
    int total_local_agents = 0;
    total_agents = total_nodes;
    for (const auto& node : nodes) {
        int node_id = node.first;
        int owner_rank = getNodeOwnerRank(node_id, &node_id_to_community_map);

        if (owner_rank == rank) {
            // This agent belongs to this rank.
            repast::AgentId id(node_id, rank, 0);

            // Select class, properties and initial state based on node connectivity
            // and model params
            AgentClass agent_class;
            double p_verify;
            double p_forget;
            BeliefState agent_state;
            double rand_val = repast::Random::instance()->nextDouble();
            if (node_id_to_community_map.at(node_id) == scholars_community_) {
                agent_class = AgentClass::SCHOLAR;
                p_verify = scholar_p_verify_;
                p_forget = scholar_p_forget_;
                if (rand_val < believer_percentage_) {
                    agent_state = BeliefState::BELIEVER;
                } else {
                    agent_state = BeliefState::SUSCEPTIBLE;
                }
            } else {
                agent_class = preassigned_class[node_id];
                if (agent_class == AgentClass::INFLUENCER) {
                    p_verify = influencer_p_verify_;
                    p_forget = influencer_p_forget_;
                    if (rand_val < believer_percentage_) {
                        agent_state = BeliefState::BELIEVER;
                    } else {
                        agent_state = BeliefState::SUSCEPTIBLE;
                    }
                } else if (agent_class == AgentClass::BOT) {
                    p_verify = BOT_P_VERIFY;
                    p_forget = BOT_P_FORGET;
                    if (rand_val < bot_p_believer_ / bot_p_) {
                        agent_state = BeliefState::BELIEVER;
                    } else {
                        agent_state = BeliefState::FACT_CHECKER;
                    }
                } else {
                    p_verify = normal_p_verify_;
                    p_forget = normal_p_forget_;
                    if (rand_val < believer_percentage_) {
                        agent_state = BeliefState::BELIEVER;
                    } else {
                        agent_state = BeliefState::SUSCEPTIBLE;
                    }
                }
            }
            DiffusionAgent* agent =
                new DiffusionAgent(id, agent_class, p_verify, p_forget, agent_state, extra_message_bytes_);
            context.addAgent(agent);
            total_local_agents++;
        }
    }
    logger.log(repast::INFO, "Created " + std::to_string(total_local_agents) +
                                  " local agents for rank " + std::to_string(rank));
    TAU_PROFILE_STOP(agent_creation_timer);

    // Step 2: Detect Required Ghosts
    TAU_PROFILE_TIMER(ghost_request_timer, "MisinformationDiffusionModel::initNetwork__ghostRequest", "", TAU_DEFAULT);
    TAU_PROFILE_START(ghost_request_timer);
    logger.log(repast::DEBUG,
               "Requesting ghost agents for rank " + std::to_string(rank) + "...");
    repast::AgentRequest request(rank);
    std::set<int> requested_ghosts; // Prevent duplicate requests

    for (const auto& edge : edges) {
        int source_id = edge.first;
        int target_id = edge.second;

        int source_owner = getNodeOwnerRank(source_id, &node_id_to_community_map);
        int target_owner = getNodeOwnerRank(target_id, &node_id_to_community_map);

        // If rank owns the source, but not the target, request a ghost of the target
        if (source_owner == rank && target_owner != rank) {
            if (requested_ghosts.find(target_id) == requested_ghosts.end()) {
                repast::AgentId ghost_id(target_id, target_owner, 0);
                ghost_id.currentRank(target_owner);
                request.addRequest(ghost_id);
                requested_ghosts.insert(target_id);
            }
        }
        // If rank owns the target, but not the source, request a ghost of the source
        else if (target_owner == rank && source_owner != rank) {
            if (requested_ghosts.find(source_id) == requested_ghosts.end()) {
                repast::AgentId ghost_id(source_id, source_owner, 0);
                ghost_id.currentRank(source_owner);
                request.addRequest(ghost_id);
                requested_ghosts.insert(source_id);
            }
        }
    }
    TAU_PROFILE_STOP(ghost_request_timer);

    // Step 3: Fetch the Ghosts via MPI
    TAU_PROFILE_TIMER(ghost_fetch_timer, "MisinformationDiffusionModel::initNetwork__ghostFetch", "", TAU_DEFAULT);
    TAU_PROFILE_START(ghost_fetch_timer);
    logger.log(repast::INFO, "Requested " +
                                  std::to_string(requested_ghosts.size()) +
                                  " ghost agents for rank " + std::to_string(rank));
    repast::RepastProcess::instance()
        ->requestAgents<DiffusionAgent, DiffusionAgentPackage,
                        DiffusionAgentPackageProvider,
                        DiffusionAgentPackageReceiver>(context, request, *provider,
                                                       *receiver, *receiver);
    TAU_PROFILE_STOP(ghost_fetch_timer);

    // Step 4: Build the Edges
    TAU_PROFILE_TIMER(edge_creation_timer, "MisinformationDiffusionModel::initNetwork__edgeCreation", "", TAU_DEFAULT);
    TAU_PROFILE_START(edge_creation_timer);
    logger.log(repast::DEBUG,
               "Creating edges for rank " + std::to_string(rank) + "...");
    int total_local_edges = 0;
    total_edges = edges.size();
    // Now that local agents and ghost agents are in the context, we can link them
    for (const auto& edge : edges) {
        int source_id = edge.first;
        int target_id = edge.second;

        int source_owner = getNodeOwnerRank(source_id, &node_id_to_community_map);
        int target_owner = getNodeOwnerRank(target_id, &node_id_to_community_map);

        // If this rank owns at least one of the nodes, the edge must exist in this
        // rank's network
        if (source_owner == rank || target_owner == rank) {
            repast::AgentId src_id(source_id, source_owner, 0);
            repast::AgentId tgt_id(target_id, target_owner, 0);

            DiffusionAgent* src = context.getAgent(src_id);
            DiffusionAgent* tgt = context.getAgent(tgt_id);

            // Add edge to the Repast SharedNetwork
            if (src != nullptr && tgt != nullptr) {
                network->addEdge(src, tgt);
                total_local_edges++;
            }
        }
    }
    logger.log(repast::DEBUG, "Created " + std::to_string(total_local_edges) +
                                  " edges for rank " + std::to_string(rank));
    TAU_PROFILE_STOP(edge_creation_timer);
}

void MisinformationDiffusionModel::step() {
    logger.log(repast::DEBUG, "Starting step");
    TAU_PROFILE_TIMER(state_calc_timer, "MisinformationDiffusionModel::step__stateCalculation", "", TAU_DEFAULT);
    TAU_PROFILE_START(state_calc_timer);
    std::vector<DiffusionAgent*> local_agents;
    context.selectAgents(repast::SharedContext<DiffusionAgent>::LOCAL,
                         context.size(), local_agents);

    // Phase 1: Calculate stochastic transitions based on current t
    for (DiffusionAgent* agent : local_agents) {
        agent->calculateNextState(context, network, alpha_, beta_, extra_compute_cycles_);
    }
    logger.log(repast::DEBUG, "Calculated all next states");
    TAU_PROFILE_STOP(state_calc_timer);

    // Phase 2: Lock in the states for t+1
    TAU_PROFILE_TIMER(state_apply_timer, "MisinformationDiffusionModel::step__stateApplication", "", TAU_DEFAULT);
    TAU_PROFILE_START(state_apply_timer);
    for (DiffusionAgent* agent : local_agents) {
        agent->applyNextState();
    }
    logger.log(repast::DEBUG, "Applied all next states");
    TAU_PROFILE_STOP(state_apply_timer);

    // Phase 3: Block-synchronize boundary ghost agents across MPI processes
    TAU_PROFILE_TIMER(sync_timer, "MisinformationDiffusionModel::step__ghostSynchronization", "", TAU_DEFAULT);
    TAU_PROFILE_START(sync_timer);
    repast::RepastProcess::instance()
        ->synchronizeAgentStates<DiffusionAgentPackage,
                                 DiffusionAgentPackageProvider,
                                 DiffusionAgentPackageReceiver>(*provider,
                                                                *receiver);
    logger.log(repast::DEBUG, "Synchronized all agents");
    TAU_PROFILE_STOP(sync_timer);
}

void MisinformationDiffusionModel::initSchedule(repast::ScheduleRunner& runner) {
    runner.scheduleEvent(1, 1,
                         repast::Schedule::FunctorPtr(
                             new repast::MethodFunctor<MisinformationDiffusionModel>(
                                 this, &MisinformationDiffusionModel::step)));
    runner.scheduleEvent(
        0.5, 1,
        repast::Schedule::FunctorPtr(
            new repast::MethodFunctor<MisinformationDiffusionModel>(
                this, &MisinformationDiffusionModel::recordDynamicResults)));
    runner.scheduleEndEvent(repast::Schedule::FunctorPtr(
        new repast::MethodFunctor<MisinformationDiffusionModel>(
            this, &MisinformationDiffusionModel::recordDynamicResults)));
    // runner.scheduleEndEvent(repast::Schedule::FunctorPtr(
    //     new repast::MethodFunctor<MisinformationDiffusionModel>(
    //         this, &MisinformationDiffusionModel::recordStaticResults)));
    runner.scheduleStop(total_ticks_);
}

void MisinformationDiffusionModel::recordDynamicResults() {
    TAU_PROFILE_TIMER(record_timer, "MisinformationDiffusionModel::recordDynamicResults__dataCount", "", TAU_DEFAULT);
    TAU_PROFILE_START(record_timer);
    local_believers = 0;
    local_factcheckers = 0;
    local_susceptibles = 0;
    local_normal_believers = 0;
    local_normal_factcheckers = 0;
    local_normal_susceptibles = 0;
    local_scholar_believers = 0;
    local_scholar_factcheckers = 0;
    local_scholar_susceptibles = 0;
    local_influencer_believers = 0;
    local_influencer_factcheckers = 0;
    local_influencer_susceptibles = 0;

    std::vector<DiffusionAgent*> local_agents;
    context.selectAgents(repast::SharedContext<DiffusionAgent>::LOCAL,
                         context.size(), local_agents);
    for (DiffusionAgent* agent : local_agents) {
        if (agent->getState() == BELIEVER) {
            local_believers++;
            if (agent->getAgentClass() == INFLUENCER) {
                local_influencer_believers++;
            } else if (agent->getAgentClass() == SCHOLAR) {
                local_scholar_believers++;
            } else if (agent->getAgentClass() == NORMAL) {
                local_normal_believers++;
            }
        } else if (agent->getState() == FACT_CHECKER) {
            local_factcheckers++;
            if (agent->getAgentClass() == INFLUENCER) {
                local_influencer_factcheckers++;
            } else if (agent->getAgentClass() == SCHOLAR) {
                local_scholar_factcheckers++;
            } else if (agent->getAgentClass() == NORMAL) {
                local_normal_factcheckers++;
            }
        } else {
            local_susceptibles++;
            if (agent->getAgentClass() == INFLUENCER) {
                local_influencer_susceptibles++;
            } else if (agent->getAgentClass() == SCHOLAR) {
                local_scholar_susceptibles++;
            } else if (agent->getAgentClass() == NORMAL) {
                local_normal_susceptibles++;
            }
        }
    }
    TAU_PROFILE_STOP(record_timer);

    TAU_PROFILE_TIMER(write_timer, "MisinformationDiffusionModel::recordDynamicResults__dataWrite", "", TAU_DEFAULT);
    TAU_PROFILE_START(write_timer);
    dynamic_dataset_->record();
    dynamic_dataset_->write();
    TAU_PROFILE_STOP(write_timer);
}
void MisinformationDiffusionModel::recordStaticResults() {
    int rank = repast::RepastProcess::instance()->rank();
    logger.log(repast::DEBUG, "Recording results for rank " + std::to_string(rank));

    local_degree_sum = 0;
    local_normals = 0;
    local_scholars = 0;
    local_influencers = 0;
    local_b_bots = 0;
    local_fc_bots = 0;
    local_super_spreaders = 0;

    std::vector<DiffusionAgent*> local_agents;
    context.selectAgents(repast::SharedContext<DiffusionAgent>::LOCAL,
                         context.size(), local_agents);
    for (DiffusionAgent* agent : local_agents) {
        std::vector<DiffusionAgent*> neighbours;
        network->successors(agent, neighbours);
        local_degree_sum += neighbours.size();

        if (neighbours.size() > 100 && neighbours.size() < 200) {
            local_super_spreaders++;
        }

        if (agent->getAgentClass() == NORMAL) {
            local_normals++;
        } else if (agent->getAgentClass() == SCHOLAR) {
            local_scholars++;
        } else if (agent->getAgentClass() == INFLUENCER) {
            local_influencers++;
        } else if (agent->getAgentClass() == BOT) {
            if (agent->getState() == BELIEVER) {
                local_b_bots++;
            } else if (agent->getState() == FACT_CHECKER) {
                local_fc_bots++;
            }
        }
    }

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
        case StatType::AVG_DEGREE:
            return model->local_degree_sum / model->total_agents;
        case StatType::PCT_NORMAL:
            return (model->local_normals / model->total_agents) * 100.0;
        case StatType::PCT_SCHOLAR:
            return (model->local_scholars / model->total_agents) * 100.0;
        case StatType::PCT_INFLUENCER:
            return (model->local_influencers / model->total_agents) * 100.0;
        case StatType::PCT_B_BOT:
            return (model->local_b_bots / model->total_agents) * 100.0;
        case StatType::PCT_FC_BOT:
            return (model->local_fc_bots / model->total_agents) * 100.0;

        case StatType::TOTAL_SUPER_SPREADERS:
            return model->local_super_spreaders;
        case StatType::TOTAL_BELIEVERS:
            return model->local_believers;
        case StatType::TOTAL_FACTCHECKERS:
            return model->local_factcheckers;
        case StatType::TOTAL_SUSCEPTIBLES:
            return model->local_susceptibles;
        case StatType::NORMAL_BELIEVERS:
            return model->local_normal_believers;
        case StatType::NORMAL_FACTCHECKERS:
            return model->local_normal_factcheckers;
        case StatType::NORMAL_SUSCEPTIBLES:
            return model->local_normal_susceptibles;
        case StatType::SCHOLAR_BELIEVERS:
            return model->local_scholar_believers;
        case StatType::SCHOLAR_FACTCHECKERS:
            return model->local_scholar_factcheckers;
        case StatType::SCHOLAR_SUSCEPTIBLES:
            return model->local_scholar_susceptibles;
        case StatType::INFLUENCER_BELIEVERS:
            return model->local_influencer_believers;
        case StatType::INFLUENCER_FACTCHECKERS:
            return model->local_influencer_factcheckers;
        case StatType::INFLUENCER_SUSCEPTIBLES:
            return model->local_influencer_susceptibles;

        // For globally known constants:
        // We only return the value on Rank 0 and 0 on all other ranks.
        // This prevents std::plus from multiplying the parameter by the number of
        // ranks
        case StatType::RUN_ID:
            return rank == 0 ? model->run_id : 0;
        case StatType::TOTAL_VERTICES:
            return rank == 0 ? model->total_agents : 0;
        case StatType::TOTAL_EDGES:
            return rank == 0 ? model->total_edges : 0;
        default:
            return 0.0;
    }
}
