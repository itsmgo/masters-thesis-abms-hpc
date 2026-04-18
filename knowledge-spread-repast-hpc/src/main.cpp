#include "KnowledgeModel.h"
#include "repast_hpc/RepastProcess.h"
#include "repast_hpc/logger.h"

#include <boost/mpi.hpp>

int main(int argc, char** argv) {
    std::string configFile = argv[1];
    std::string propsFile = argv[2];

    boost::mpi::environment env(argc, argv);
    boost::mpi::communicator world;

    repast::RepastProcess::init(configFile);
    repast::Logger logger = repast::Log4CL::instance()->get_logger("root");

    LOG_RANK0(logger, repast::INFO, "Initializing model");
    KnowledgeSpreadModel* model =
        new KnowledgeSpreadModel(propsFile, argc, argv, &world);
    repast::ScheduleRunner& runner =
        repast::RepastProcess::instance()->getScheduleRunner();

    LOG_RANK0(logger, repast::INFO, "Initializing scheduler");
    model->initSchedule(runner);

    LOG_RANK0(logger, repast::INFO, "Running model simulation");
    runner.run();

    delete model;
    repast::RepastProcess::instance()->done();
    LOG_RANK0(logger, repast::INFO, "Simulation finished successfully");
}
