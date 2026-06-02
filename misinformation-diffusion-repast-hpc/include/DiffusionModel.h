#ifndef DIFFUSION_MODEL
#define DIFFUSION_MODEL

#include "DiffusionAgent.h"
#include "repast_hpc/Properties.h"
#include "repast_hpc/SVDataSet.h"
#include "repast_hpc/Schedule.h"
#include "repast_hpc/TDataSource.h"

#include <boost/mpi.hpp>

/* Agent Package Provider */
class DiffusionAgentPackageProvider {
  private:
    repast::SharedContext<DiffusionAgent>* context;

  public:
    DiffusionAgentPackageProvider(repast::SharedContext<DiffusionAgent>* agentPtr);
    void providePackage(DiffusionAgent* agent,
                        std::vector<DiffusionAgentPackage>& out);
    void provideContent(repast::AgentRequest req,
                        std::vector<DiffusionAgentPackage>& out);
};

/* Agent Package Receiver */
class DiffusionAgentPackageReceiver {
  private:
    repast::SharedContext<DiffusionAgent>* context;

  public:
    DiffusionAgentPackageReceiver(repast::SharedContext<DiffusionAgent>* agentPtr);
    DiffusionAgent* createAgent(DiffusionAgentPackage package);
    void updateAgent(DiffusionAgentPackage package);
};

class MisinformationDiffusionModel {
  private:
    repast::SharedContext<DiffusionAgent> context;
    repast::RepastEdgeContentManager<DiffusionAgent> edgeContentManager;
    repast::SharedNetwork<DiffusionAgent, repast::RepastEdge<DiffusionAgent>,
                          repast::RepastEdgeContent<DiffusionAgent>,
                          repast::RepastEdgeContentManager<DiffusionAgent>>* network;
    repast::Properties* props;
    repast::Logger logger = repast::Log4CL::instance()->get_logger("root");

    // model props
    std::string network_file_;
    double total_ticks_;
    double alpha_;
    double beta_;
    double believer_percentage_;
    double influencer_p_verify_;
    double influencer_p_forget_;
    double normal_p_verify_;
    double normal_p_forget_;
    double scholar_p_verify_;
    double scholar_p_forget_;
    int scholars_community_;
    std::string partitioning_strat_;
    int extra_compute_cycles_;
    int extra_message_bytes_;
    double bot_p_fact_checker_;
    double bot_p_believer_;
    double bot_p_;

    DiffusionAgentPackageProvider* provider;
    DiffusionAgentPackageReceiver* receiver;

    repast::SVDataSet* dynamic_dataset_;

  public:
    MisinformationDiffusionModel(std::string propsFile, int argc, char** argv,
                                 boost::mpi::communicator* comm);
    ~MisinformationDiffusionModel();
    void initNetwork();
    void step();
    void initSchedule(repast::ScheduleRunner& runner);
    void recordStaticResults();
    void recordDynamicResults();
    int getNodeOwnerRank(int node_id, std::map<int, int>* node_id_to_community_map);

    // metrics
    int run_id;
    int total_agents;
    int total_edges;
    double local_degree_sum;
    double local_normals;
    double local_scholars;
    double local_influencers;
    double local_b_bots;
    double local_fc_bots;
    double local_super_spreaders;
    double local_believers;
    double local_factcheckers;
    double local_susceptibles;
    double local_normal_believers;
    double local_normal_factcheckers;
    double local_normal_susceptibles;
    double local_scholar_believers;
    double local_scholar_factcheckers;
    double local_scholar_susceptibles;
    double local_influencer_believers;
    double local_influencer_factcheckers;
    double local_influencer_susceptibles;

    repast::SVDataSet* static_dataset;
};

/* Data Collection */

enum class StatType {
    RUN_ID,
    TOTAL_VERTICES,
    TOTAL_EDGES,
    AVG_DEGREE,
    PCT_NORMAL,
    PCT_SCHOLAR,
    PCT_INFLUENCER,
    PCT_B_BOT,
    PCT_FC_BOT,
    TOTAL_SUPER_SPREADERS,
    TOTAL_BELIEVERS,
    TOTAL_FACTCHECKERS,
    TOTAL_SUSCEPTIBLES,
    NORMAL_BELIEVERS,
    NORMAL_FACTCHECKERS,
    NORMAL_SUSCEPTIBLES,
    SCHOLAR_BELIEVERS,
    SCHOLAR_FACTCHECKERS,
    SCHOLAR_SUSCEPTIBLES,
    INFLUENCER_BELIEVERS,
    INFLUENCER_FACTCHECKERS,
    INFLUENCER_SUSCEPTIBLES
};

class StatDataSource : public repast::TDataSource<double> {
  private:
    MisinformationDiffusionModel* model;
    StatType type;
    int rank;

  public:
    StatDataSource(MisinformationDiffusionModel* m, StatType t, int r)
        : model(m)
        , type(t)
        , rank(r) {}

    double getData();
};
#endif
