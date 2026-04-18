#include "KnowledgeAgent.h"

#include "repast_hpc/logger.h"

#include <string>

KnowledgeAgent::KnowledgeAgent(repast::AgentId id, double birth)
    : id_(id)
    , birth_(birth)
    , isConferencing_(false)
    , color_(Color::BLACK) {}

KnowledgeAgent::KnowledgeAgent(repast::AgentId id, double birth, bool isConferencing,
                               Color color)
    : id_(id)
    , birth_(birth)
    , isConferencing_(isConferencing)
    , color_(color) {}

KnowledgeAgent::~KnowledgeAgent() {}

void KnowledgeAgent::applyMovement(
    std::vector<double> currentLoc, std::vector<double> targetLoc,
    double distThreshold,
    repast::DiscreteValueLayer<std::pair<Color, std::vector<double>>,
                               repast::StrictBorders>* regionLayer,
    repast::SharedContinuousSpace<KnowledgeAgent, repast::StrictBorders,
                                  repast::SimpleAdder<KnowledgeAgent>>*
        continuousSpace,
    repast::SharedDiscreteSpace<KnowledgeAgent, repast::StrictBorders,
                                repast::SimpleAdder<KnowledgeAgent>>*
        discreteSpace) {
    double dx = targetLoc[0] - currentLoc[0];
    double dy = targetLoc[1] - currentLoc[1];
    double dist = std::sqrt(dx * dx + dy * dy);

    if (dist > 0 && dist < distThreshold) {
        // Logistic function of age and distance
        double stepSize = 1.0 / (1.0 + std::exp(-birth_ * dist));
        // Move 1 unit per tick at most
        stepSize = std::min(1.0, stepSize);
        // Prevent overshooting the specific target
        if (stepSize > dist)
            stepSize = dist;

        double deltaX = (dx / dist) * stepSize;
        double deltaY = (dy / dist) * stepSize;
        std::vector<double> newLocation = {currentLoc[0] + deltaX,
                                           currentLoc[1] + deltaY};
        std::vector<int> newDiscreteLoc = discretizeVec2(newLocation);
        Color nextColor = regionLayer->get(newDiscreteLoc).first;

        if (nextColor == BLACK) {
            // Discard movement
            return;
        }

        // Apply movement and color changes
        continuousSpace->moveTo(id_, newLocation);
        discreteSpace->moveTo(id_, discretizeVec2(newLocation));
        color_ = nextColor;
    }
}

void KnowledgeAgent::provideContent(KnowledgeAgentPackage& package) {
    package.id = id_.id();
    package.rank = id_.startingRank();
    package.type = id_.agentType();
    package.currentRank = id_.currentRank();

    package.birth = birth_;
    package.isConferencing = isConferencing_;
    package.color = color_;
}

void KnowledgeAgent::update(KnowledgeAgentPackage& package) {
    birth_ = package.birth;
    isConferencing_ = package.isConferencing;
    color_ = package.color;
}
