#include "DiffusionAgent.h"

#include "repast_hpc/logger.h"

#include <string>
#include <vector>

void DiffusionAgent::calculateNextState(
    repast::SharedContext<DiffusionAgent>& context,
    repast::SharedNetwork<DiffusionAgent, repast::RepastEdge<DiffusionAgent>,
                          repast::RepastEdgeContent<DiffusionAgent>,
                          repast::RepastEdgeContentManager<DiffusionAgent>>* network,
    double alpha, double beta, int extra_compute_cycles) {
    
    double dummy = 0;
    for (int i = 0; i < extra_compute_cycles; i++) {
        // Perform some dummy computations to simulate extra compute load
        dummy += std::sin(i) * std::cos(i);
    }

    // Bots are static and do not participate in Markov transitions
    if (type_ == BOT) {
        next_state_ = state_;
        return;
    }

    // Draw high-entropy random value utilizing Boost/MPI safe RNG
    double rand_val = repast::Random::instance()->nextDouble();

    logger.log(repast::DEBUG,
               std::to_string(id_.id()) + " rand_val: " + std::to_string(rand_val));

    switch (state_) {
        case SUSCEPTIBLE: {
            std::vector<DiffusionAgent*> neighbours;
            network->successors(this, neighbours);

            double n_B = 0;
            double n_F = 0;

            // Count neighbourhood influence
            for (auto neighbour : neighbours) {
                if (neighbour->getState() == BELIEVER)
                    n_B++;
                else if (neighbour->getState() == FACT_CHECKER)
                    n_F++;
            }
            logger.log(repast::DEBUG,
                       std::to_string(id_.id()) + " n_B: " + std::to_string(n_B));
            logger.log(repast::DEBUG,
                       std::to_string(id_.id()) + " n_F: " + std::to_string(n_F));

            // Calculate Spreading Functions f_i(t) and g_i(t)
            double denominator = (n_B * (1.0 + alpha)) + (n_F * (1.0 - alpha));
            double f_i = 0, g_i = 0;

            if (denominator > 0) {
                f_i = beta * ((n_B * (1.0 + alpha)) / denominator);
                g_i = beta * ((n_F * (1.0 - alpha)) / denominator);
            }
            logger.log(repast::DEBUG,
                       std::to_string(id_.id()) + " f_i: " + std::to_string(f_i));
            logger.log(repast::DEBUG,
                       std::to_string(id_.id()) + " g_i: " + std::to_string(g_i));

            // Stochastic state resolution based on neighbour pressure
            if (rand_val < f_i) {
                next_state_ = BELIEVER;
                logger.log(repast::DEBUG, std::to_string(id_.id()) +
                                              " spread: SUSCEPTIBLE -> BELIEVER");
            } else if (rand_val < (f_i + g_i)) {
                next_state_ = FACT_CHECKER;
                logger.log(repast::DEBUG,
                           std::to_string(id_.id()) +
                               " spread: SUSCEPTIBLE -> FACT_CHECKER");
            } else {
                next_state_ = SUSCEPTIBLE;
                logger.log(repast::DEBUG,
                           std::to_string(id_.id()) + " stationary: SUSCEPTIBLE");
            }
            break;
        }
        case BELIEVER:
            // Evaluate chance to verify or forget the hoax
            if (rand_val < p_verify_) {
                next_state_ = FACT_CHECKER;
                logger.log(repast::DEBUG, std::to_string(id_.id()) +
                                              " verify: BELIEVER -> FACT_CHECKER");
            } else if (rand_val < (p_verify_ + p_forget_)) {
                next_state_ = SUSCEPTIBLE;
                logger.log(repast::DEBUG, std::to_string(id_.id()) +
                                              " forget: BELIEVER -> SUSCEPTIBLE");
            } else {
                next_state_ = BELIEVER;
                logger.log(repast::DEBUG,
                           std::to_string(id_.id()) + " stationary: BELIEVER");
            }
            break;
        case FACT_CHECKER:
            // Evaluate chance to forget the hoax
            if (rand_val < p_forget_) {
                next_state_ = SUSCEPTIBLE;
                logger.log(repast::DEBUG,
                           std::to_string(id_.id()) +
                               " forget: FACT_CHECKER -> SUSCEPTIBLE");
            } else {
                next_state_ = FACT_CHECKER;
                logger.log(repast::DEBUG,
                           std::to_string(id_.id()) + " stationary: FACT_CHECKER");
            }
    }
}

void DiffusionAgent::applyNextState() {
    state_ = next_state_;
}

void DiffusionAgent::provideContent(DiffusionAgentPackage& package) {
    package.id = id_.id();
    package.rank = id_.startingRank();
    package.type = id_.agentType();
    package.currentRank = id_.currentRank();
    package.state = state_;
    package.agentClass = type_;
    package.extraMessageBytes = extra_message_bytes_;
    // Create a vector with particular size to simulate larger package sizes and message serialization overhead
    package.extraMessageBuffer = std::vector<int>(extra_message_bytes_ / sizeof(int), 0);
}

void DiffusionAgent::update(DiffusionAgentPackage& package) {
    state_ = static_cast<BeliefState>(package.state);
}
