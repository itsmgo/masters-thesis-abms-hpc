#include "KnowledgeAgent.h"


KnowledgeAgent::KnowledgeAgent(repast::AgentId id, double birth)
    : id_(id)
    , birth_(birth)
    , position_(false)
    , color_(Color::BLACK) {}

KnowledgeAgent::KnowledgeAgent(repast::AgentId id, double birth, std::vector<double> position, Color color)
    : id_(id)
    , birth_(birth)
    , position_(position)
    , color_(color) {}

KnowledgeAgent::~KnowledgeAgent() {}

void KnowledgeAgent::applyMovement(
    std::vector<double> targetLoc, int currentTick, double distThreshold,
    repast::DiscreteValueLayer<std::pair<Color, std::vector<double>>,
                               repast::StrictBorders>* regionLayer) {
    double dx = targetLoc[0] - position_[0];
    double dy = targetLoc[1] - position_[1];

    double age = std::max(1.0, birth_ - currentTick);

    double dist = std::sqrt(dx * dx + dy * dy);

    if (dist > 0 && dist < distThreshold) {
        // Logistic function of age and distance
        double stepSize = 2.0 / (1.0 + std::exp(- dist / age) - 1.0);
        // Move 1 unit per tick at most
        stepSize = std::min(1.0, stepSize);
        // Prevent overshooting the specific target
        if (stepSize > dist)
            stepSize = dist;

        double deltaX = (dx / dist) * stepSize;
        double deltaY = (dy / dist) * stepSize;
        std::vector<double> newLocation = {position_[0] + deltaX,
                                           position_[1] + deltaY};
        std::vector<int> newDiscreteLoc = discretizeVec2(newLocation);
        Color nextColor = regionLayer->get(newDiscreteLoc).first;

        if (nextColor == BLACK) {
            // Discard movement
            return;
        }

        // Apply movement and color changes
        position_ = newLocation;
        color_ = nextColor;
    }
}

void KnowledgeAgent::provideContent(KnowledgeAgentPackage& package) {
    package.id = id_.id();
    package.rank = id_.startingRank();
    package.type = id_.agentType();
    package.currentRank = id_.currentRank();

    package.birth = birth_;
    package.position = position_;
    package.color = color_;
}

void KnowledgeAgent::update(KnowledgeAgentPackage& package) {
    birth_ = package.birth;
    position_ = package.position;
    color_ = package.color;
}
