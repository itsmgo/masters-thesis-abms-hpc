= Performance Analysis

This chapter presents the performance analysis of the implemented models. The models are evaluated based on their computational efficiency and scalability in simulating social network dynamics. The analysis presents the methodology and results for both the misinformation diffusion and the socio-epistemic knowledge spread models.

== Misinformation diffusion model

=== Methodology


#text(10pt)[*Instrumentation for performance metering*]

In order to measure the performance of the misinformation diffusion model, the TAU Performance System @ShendeMalony2006 @TAUWebpage has been used. The Tuning and Analysis Utilities (TAU) system has been configured with the specific purpose of measuring the MPI message protocol performance, as well as execution time for the different testing scenarios. To better understand the distribution of the execution time among the different model tasks, a set of specific timers have been set up. The description of each timer can be found in @TimersDescription. This execution time breakdown is crucial to understand the performance bottlenecks of the model and to identify potential areas for optimization once the model parameters are explored.

#figure(
  table(
    columns: (auto, auto),
    inset: (x: 8pt),
    align: (x, y) => if x == 0 { right } else { left },
    stroke: (x, y) => if y == 0 or y == 6 {
      (right: none, top: none, bottom: 0.5pt, left: none)
    } else { none },
    table.header(
      [*Timer name*], [*Description*]
    ),
    [*Total time*], [Total execution time of the model.],
    [*Initialization time*], [Model initialization logic: network parsing, network partitioning, agents instantiation, ghost agents initial synchronization.],
    [*Computation time*], [Model computation phase: calculation of next agent state and agent state updates.],
    [*Communication time*], [Model communication phase: inter-agent message exchange and ghost agents synchronization.],
    [*Results time*], [Model results collection and output phase: gathering of model results and writing to disk.],
    [*MPI Sync time*], [Time spent in MPI rank synchronization calls, such as MPI_Barrier, MPI_Wait, MPI_Test, etc...],
  ),
  caption: "Description of the timers used for performance analysis of the misinformation diffusion model."
) <TimersDescription>

#text(10pt)[*Default setup*]

When executing the performance analysis, a systematic exploration of the model parameters has been conducted to understand their impact on the performance metrics. The parameters studied include the number of MPI ranks, the number of agents in the synthetic network, the type of synthetic network used, the average degree of the network, the partitioning strategy for distributing the network across MPI ranks, and additional factors such as message size and computational load.

The default setting for each of the parameters explored has been chosen based on a balance between computational feasibility and representativeness of real-world scenarios. This default setup serves as a baseline for studying the impact of the mentioned parameters on the performance metrics. @DefaultConfig provides a detailed description of the default configuration used for the performance analysis.

#figure(
  table(
    columns: (auto, auto, auto),
    inset: (x: 8pt),
    align: (x, y) => if x == 0 { right } else { left },
    stroke: (x, y) => if y == 0 or y == 7 {
      (right: none, top: none, bottom: 0.5pt, left: none)
    } else { none },
    table.header(
      [*Parameter*], [*Description*], [*Default value*]
    ),
    [*Ranks*], [Number of MPI ranks used for the simulation.], [4 ranks],
    [*Agents*], [Number of nodes in the synthetic network.], [$10^5$ agents],
    [*Network*], [Type of synthetic network used for the simulation.], [Holme and Kim],
    [*Avg degree*], [Average degree of the synthetic network.], [4],
    [*Partition*], [Strategy used for partitioning the network across MPI ranks.], [Fluid community],
    [*Msg extra size*], [Size of the messages exchanged between agents during the communication phase.], [0 bytes],
    [*CPU extra load*], [Computational load of the agent state update function, measured in operations.], [0 operations],
  ),
  caption: "Default configuration for the performance analysis of the misinformation diffusion model."
) <DefaultConfig>

For the network setup, a set of synthetic networks have been generated to evaluate the performance of the misinformation diffusion model. The synthetic network generation process allows the creation of controlled environments with specific characteristics, such as network size, degree distribution and clustering coefficient. This controlled setup is essential for systematically studying the impact of various model parameters on performance metrics. The Holme and Kim model @Holme2002 has been used for synthetic network generation, as it produces scale-free networks that are commonly observed in real-world social networks and it allows fine tuning of the networks average clustering coefficient. Other network generation models, such as the Barabási-Albert model @BarabasiAlbert1999, the Erdős-Rényi model @ErdosRenyi1960 and the Watts-Strogatz model @WattsStrogatz1998, have also been included for comparative analysis.

Each simulation run has been executed 5 times to account for variability in execution time and performance metrics. The results presented in the following sections are based on the average values obtained from these runs.

=== Results

The performance of the misinformation diffusion model has been evaluated by varying the number of MPI ranks used for the simulation. In @TimeRankDependency, the execution time breakdown for different numbers of ranks is presented, where the results indicate that as the number of ranks increases, the total execution time increases due to the cost of synchronization between ranks.

#figure(
  image("../misinformation-diffusion-repast-hpc/figures/barabasi_albert/rank_vs_time.png"),
  caption: "Execution time breakdown for different numbers of MPI ranks in a Barabási-Albert network with average degree 198 and clustering coefficient 0.057.",
)<TimeRankDependency>

In order to understand this result, the partitioning strategy and the network structure play a fundamental role. @TimeRankWattsDependency shows the same metric for a different network with a similar average degree but a higher clustering coefficient.

#figure(
  image("../misinformation-diffusion-repast-hpc/figures/watts_strogatz/rank_vs_time.png"),
  caption: "Execution time breakdown for different numbers of MPI ranks in a Barabási-Albert network with average degree 198 and clustering coefficient 0.057.",
)<TimeRankWattsDependency>

It is worth noting that the communication time stays relatively constant across different numbers of ranks, while the computation time decreases significantly with more ranks:
- The computation time decreasing behaviour is explained by the partitioning strategy that is balancing the agent distribution across ranks properly.
- The communication time remaining constant is explained by the fact that the degree distribution of the synthetic network is very narrow around 100 nodes and thus the number of ghosts per rank is always linearly proportional to the number of agents in the rank. 

#text(10pt)[*Agent dependency*]

The performance of the model has also been evaluated by varying the number of agents in the synthetic network. As shown in @TimeAgentDependency, the execution time increases with the number of agents, which is expected due to the increased computational load and communication overhead.


In order to isolate the impact of the number of agents on performance, the execution time breakdown has been presented as a ratio of the total execution time in @TimeAgentDependencyPercentage. This breakdown reveals that the computation time increases significantly with more agents, while the communication time remains fairly constant.

#grid(
  columns: 2,
  [
    #figure(
      image("../misinformation-diffusion-repast-hpc/figures/barabasi_albert/agents_vs_time.png"),
      caption: "Execution time breakdown for different numbers of agents.",
    )<TimeAgentDependency>
    #figure(
      image("../misinformation-diffusion-repast-hpc/figures/barabasi_albert/agents_vs_time_ratio.png"),
      caption: "Execution time breakdown as a ratio of total execution time for different numbers of agents.",
    )<TimeAgentDependencyPercentage>
  ]
)

#text(10pt)[*Rank-Agent dependency*]

In @TimeRankAgentDependency, the execution time breakdown for different combinations of ranks and agents is presented. The results indicate that the performance improvement from increasing the number of ranks is more pronounced with a larger number of agents, suggesting that the model benefits from parallelism as the computational load increases.

#figure(
  image("../misinformation-diffusion-repast-hpc/figures/barabasi_albert/ranks_and_agents_vs_time.png"),
  caption: "Execution time breakdown for different combinations of ranks and agents.",
)<TimeRankAgentDependency>

Execution time:
- Partition strategy comparison
- Message size dependency
- Computation load dependency

== Socio-epistemic knowledge spread model

=== Methodology

Model parameters to study and Performance metrics

=== Results
