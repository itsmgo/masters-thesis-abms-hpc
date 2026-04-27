#ifndef KNOWLEDGE_MODEL
#define KNOWLEDGE_MODEL

#include "KnowledgeAgent.h"
#include "repast_hpc/Edge.h"
#include "repast_hpc/Properties.h"
#include "repast_hpc/SVDataSet.h"
#include "repast_hpc/Schedule.h"
#include "repast_hpc/SharedNetwork.h"
#include "repast_hpc/TDataSource.h"

#include <boost/mpi.hpp>

/* Agent Package Provider */
class KnowledgeAgentPackageProvider {
  private:
    repast::SharedContext<KnowledgeAgent>* context;

  public:
    KnowledgeAgentPackageProvider(repast::SharedContext<KnowledgeAgent>* agentPtr);
    void providePackage(KnowledgeAgent* agent,
                        std::vector<KnowledgeAgentPackage>& out);
    void provideContent(repast::AgentRequest req,
                        std::vector<KnowledgeAgentPackage>& out);
};

/* Agent Package Receiver */
class KnowledgeAgentPackageReceiver {
  private:
    repast::SharedContext<KnowledgeAgent>* context;

  public:
    KnowledgeAgentPackageReceiver(repast::SharedContext<KnowledgeAgent>* agentPtr);
    KnowledgeAgent* createAgent(KnowledgeAgentPackage package);
    void updateAgent(KnowledgeAgentPackage package);
};

class KnowledgeSpreadModel {
  private:
    repast::SharedContext<KnowledgeAgent> context;
    //
    // social layer: connects agents working together/sharing an edge list
    repast::RepastEdgeContentManager<KnowledgeAgent> edgeContentManager;
    repast::SharedNetwork<KnowledgeAgent, repast::RepastEdge<KnowledgeAgent>,
                          repast::RepastEdgeContent<KnowledgeAgent>,
                          repast::RepastEdgeContentManager<KnowledgeAgent>>*
        socialNetwork;
    std::map<int, std::vector<std::pair<int, int>>> networkEvolutionMap;

    // stores regional population and color
    repast::DiscreteValueLayer<std::pair<Color, std::vector<double>>,
                               repast::StrictBorders>* regionLayer;

    repast::Properties* props;
    repast::Logger logger = repast::Log4CL::instance()->get_logger("root");

    // model props
    int totalTicks_;
    double distThreshold_;
    bool useSocialNetData_; // "preferential attachment" vs "data"
    bool runSocial_;
    bool runCentroid_;

    KnowledgeAgentPackageProvider* provider;
    KnowledgeAgentPackageReceiver* receiver;
    std::set<repast::AgentId> synchronizedAgentIds;

    repast::SVDataSet* dynamic_dataset_;

    // Initialization / Setup Functions
    void setupKnowledgeSpace(); // K-means data points setup
    void setupSocialNetwork();  // Network creation
    void evolveNetwork(int tick,
                       std::vector<KnowledgeAgent*>
                           agents); // Apply modifications acording to temporal edges

    // Core Behaviors
    std::vector<double>
    getSocialLoc(KnowledgeAgent* agent,
                 std::vector<double> currentLoc); // Agents move toward colleagues
    std::vector<double> getCentroidLoc(
        std::vector<double> currentLoc); // Agents move to the region's core
    std::vector<double>
    getCloseLoc(KnowledgeAgent* agent,
                std::vector<double>
                    currentLoc); // Agents learn from nearest epistemic neighbor

  public:
    KnowledgeSpreadModel(std::string propsFile, int argc, char** argv,
                         boost::mpi::communicator* comm);
    virtual ~KnowledgeSpreadModel();
    void initSchedule(repast::ScheduleRunner& runner);
    void step();
    void recordStaticResults();
    void recordLocations();
    void recordNetwork();
    void recordDynamicResults();

    // metrics
    int runId;
    int totalAgents;
    int totalEdges;
    int localBlue;
    int localOrange;
    int localRed;
    int localYellow;
    int localGreen;
    int localPurple;
    int localMagenta;
    int localWhite;

    repast::SVDataSet* static_dataset;
};

/* Data Collection */

enum class StatType {
    RUN_ID,
    TOTAL_VERTICES,
    TOTAL_EDGES,
    TOTAL_BLUE,
    TOTAL_ORANGE,
    TOTAL_RED,
    TOTAL_YELLOW,
    TOTAL_GREEN,
    TOTAL_PURPLE,
    TOTAL_MAGENTA,
    TOTAL_WHITE,
};

class StatDataSource : public repast::TDataSource<double> {
  private:
    KnowledgeSpreadModel* model;
    StatType type;
    int rank;

  public:
    StatDataSource(KnowledgeSpreadModel* m, StatType t, int r)
        : model(m)
        , type(t)
        , rank(r) {}

    double getData();
};
#endif
