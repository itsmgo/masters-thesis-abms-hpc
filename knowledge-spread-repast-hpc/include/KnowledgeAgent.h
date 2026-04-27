#ifndef KNOWLEDGE_AGENT
#define KNOWLEDGE_AGENT

#include "repast_hpc/AgentId.h"
#include "repast_hpc/GridComponents.h"
#include "repast_hpc/ValueLayer.h"
#include "repast_hpc/logger.h"
#include <vector>

#define LOG_RANK0(logger, level, message)                                           \
    do {                                                                            \
        if (repast::RepastProcess::instance()->rank() == 0) {                       \
            (logger).log(level, message);                                           \
        }                                                                           \
    } while (0)

inline std::vector<int> discretizeVec2(std::vector<double> in) {
    return {(int)round(in[0]), (int)round(in[1])};
}

enum Color { BLACK, BLUE, ORANGE, RED, YELLOW, GREEN, PURPLE, MAGENTA, WHITE };
const Color ALL_COLORS[] = {BLACK, BLUE,   ORANGE,  RED,  YELLOW,
                            GREEN, PURPLE, MAGENTA, WHITE};
const size_t NUM_TOTAL_COLORS = sizeof(ALL_COLORS) / sizeof(ALL_COLORS[0]);

struct KnowledgeAgentPackage {
    int id;
    int rank;
    int type;
    int currentRank;

    double birth;
    std::vector<double> position;
    Color color;

    // Default constructor required by Boost Serialization
    KnowledgeAgentPackage() {}

    KnowledgeAgentPackage(int _id, int _rank, int _type, int _currentRank,
                          double _birth, std::vector<double> _position, Color _color)
        : id(_id)
        , rank(_rank)
        , type(_type)
        , currentRank(_currentRank)
        , birth(_birth)
        , position(_position)
        , color(_color) {}

    // Boost serialization template mapping variables for MPI transfer
    template <class Archive>
    void serialize(Archive& ar, const unsigned int version) {
        ar& id;
        ar& rank;
        ar& type;
        ar& currentRank;
        ar& birth;
        ar& position;
        ar& color;
    }
};

/* Agents */
class KnowledgeAgent {
  private:
    repast::AgentId id_;
    double birth_;
    std::vector<double> position_;
    Color color_;

    repast::Logger logger = repast::Log4CL::instance()->get_logger("root");

  public:
    KnowledgeAgent(repast::AgentId id, double birth);
    KnowledgeAgent(repast::AgentId id, double birth, std::vector<double> position,
                   Color color);
    virtual ~KnowledgeAgent();

    /* Required Getters */
    virtual repast::AgentId& getId() { return id_; }
    virtual const repast::AgentId& getId() const { return id_; }

    /* Getters specific to this kind of Agent */
    double getBirth() const { return birth_; }

    std::vector<double> getPosition() const { return position_; }
    void setPosition(std::vector<double> pos) { position_ = pos; }

    Color getColor() const { return color_; }
    void setColor(Color c) { color_ = c; }

    /* Actions */
    void applyMovement(
        std::vector<double> targetLoc, int currentTick, double distThreshold,
        repast::DiscreteValueLayer<std::pair<Color, std::vector<double>>,
                                   repast::StrictBorders>* regionLayer);

    /* Package Actions */
    void provideContent(KnowledgeAgentPackage& package);
    void
    update(KnowledgeAgentPackage& package); // This is called on GHOST agents when
                                            // the true local agent changes.
};

#endif
