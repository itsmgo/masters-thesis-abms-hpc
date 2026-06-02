#ifndef DIFFUSION_AGENT
#define DIFFUSION_AGENT

#include "repast_hpc/AgentId.h"
#include "repast_hpc/SharedContext.h"
#include "repast_hpc/SharedNetwork.h"
#include <vector>

#define LOG_RANK0(logger, level, message)                                           \
    do {                                                                            \
        if (repast::RepastProcess::instance()->rank() == 0) {                       \
            (logger).log(level, message);                                           \
        }                                                                           \
    } while (0)

enum AgentClass { NORMAL = 0, SCHOLAR = 1, INFLUENCER = 2, BOT = 3 };
enum BeliefState { SUSCEPTIBLE = 0, BELIEVER = 1, FACT_CHECKER = 2 };

struct DiffusionAgentPackage {
    int id;
    int rank;
    int type;
    int currentRank;
    int extraMessageBytes;
    std::vector<int> extraMessageBuffer; // This is just to increase the size of the package for simulation purposes

    int agentClass;
    int state;

    // Default constructor required by Boost Serialization
    DiffusionAgentPackage() {}

    DiffusionAgentPackage(int _id, int _rank, int _type, int _currentRank,
                          int _agentClass, int _state, int _extraMessageBytes,
                          std::vector<int> _extraMessageBuffer)
        : id(_id)
        , rank(_rank)
        , type(_type)
        , currentRank(_currentRank)
        , agentClass(_agentClass)
        , state(_state)
        , extraMessageBytes(_extraMessageBytes)
        , extraMessageBuffer(_extraMessageBuffer) {}

    // Boost serialization template mapping variables for MPI transfer
    template <class Archive>
    void serialize(Archive& ar, const unsigned int version) {
        ar& id;
        ar& rank;
        ar& type;
        ar& currentRank;
        ar& agentClass;
        ar& state;
        ar& extraMessageBytes;
        ar& extraMessageBuffer;
    }
};

/* Agents */
class DiffusionAgent {
  private:
    repast::AgentId id_;
    AgentClass type_;
    BeliefState state_;
    BeliefState next_state_; // Double buffering for synchronized updates

    double p_verify_;
    double p_forget_;

    int extra_message_bytes_; // This is just to simulate larger package sizes and message serialization overhead

    repast::Logger logger = repast::Log4CL::instance()->get_logger("root");

  public:
    DiffusionAgent(repast::AgentId id, AgentClass type, double p_verify,
                   double p_forget, BeliefState initial_state, int extra_message_bytes)
        : id_(id)
        , type_(type)
        , p_verify_(p_verify)
        , p_forget_(p_forget)
        , state_(initial_state)
        , extra_message_bytes_(extra_message_bytes) {}

    ~DiffusionAgent() {}

    /* Required Getters */
    virtual repast::AgentId& getId() { return id_; }
    virtual const repast::AgentId& getId() const { return id_; }

    /* Getters specific to this kind of Agent */
    int getState() const { return state_; }
    int getAgentClass() const { return type_; }

    /* Actions */
    void calculateNextState(
        repast::SharedContext<DiffusionAgent>& context,
        repast::SharedNetwork<DiffusionAgent, repast::RepastEdge<DiffusionAgent>,
                              repast::RepastEdgeContent<DiffusionAgent>,
                              repast::RepastEdgeContentManager<DiffusionAgent>>*
            network,
        double alpha, double beta, int extra_compute_cycles);
    void applyNextState();

    /* Package Actions */
    void provideContent(DiffusionAgentPackage& package);
    void
    update(DiffusionAgentPackage& package); // This is called on GHOST agents when
                                            // the true local agent changes.
};

#endif
