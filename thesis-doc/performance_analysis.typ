= Performance Analysis

This chapter presents the performance analysis of the implemented models. The models are evaluated based on their computational efficiency and scalability in simulating social network dynamics. The analysis presents the methodology and results for both the misinformation diffusion and the socio-epistemic knowledge spread models.

== Methodology


*Instrumentation for performance metering*

In order to measure the performance of the RepastHPC model implementations, the TAU Performance System @ShendeMalony2006 @TAUWebpage has been used. The Tuning and Analysis Utilities (TAU) system has been configured with the specific purpose of measuring the MPI message protocol performance, as well as execution time for the different testing scenarios. Python has been used to programatically analyze the results and create the figures.

To better understand the distribution of the execution time among the different model tasks, a set of specific timers have been set up. The description of each timer can be found in @TimersDescription. This execution time breakdown is crucial to understand the performance bottlenecks of the model and to identify potential areas for optimization once the model parameters are explored.

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
    [*Initialization time*], [Model initialization logic: network file parsing, network partitioning, agents instantiation, ghost agents initial synchronization.],
    [*Computation time*], [Model computation phase: calculation of next agent state and agent state updates.],
    [*Ghost Sync time*], [Model communication phase: inter-agent message exchange for ghost agents synchronization.],
    [*Tick Sync time*], [Time spent in synchronization calls at the end of each Repast Scheduler tick, specifically `MPI_Allreduce` method.],
    [*Results time*], [Model results collection and output phase: gathering of model results and writing to disk.],
  ),
  caption: "Description of the timers used for performance analysis and execution time breakdown.",
  placement: auto,
) <TimersDescription>

#v(10pt)
*Execution time decomposition*

// To analyse the impact of MPI communication on the overall performance of the misinformation diffusion model, execution traces generated with TAU were examined using the Jumpshot trace visualization tool. This analysis provides a high-level decomposition of the model execution time, illustrated in @SchematicTimeBreakdown.

The total execution time of the sequential implementation can be expressed as the sum of the initialization phase and the execution time of all simulation ticks:
$
T_"total" = T_"init" + sum_(i=1)^N T_"step,i"
$
where $N = 236$ corresponds to the number of independent ticks executed in each simulation.

For the RepastHPC implementation, the execution time includes a computation time and a synchronization overhead. The total execution time can therefore be decomposed as:
$
T_"total"^("RHPC") = T_"init"^("RHPC") + T_"sync,init" + sum_(i=1)^N (T_"step,i"^("RHPC") + T_"sync,i")
$
where $T_"sync,init"$ represents the synchronization time incurred during initialization and $T_"sync,i"$ corresponds to the synchronization overhead at tick $i$.

The difference between the parallel and sequential execution times is then given by:
$
Delta T_"total" = T_"total"^("RHPC") - T_"total"
$
which can be expanded as:
$
Delta T_"total" = (T_"init"^("RHPC") - T_"init") + T_"sync,init" + sum_(i=1)^N ((T_"step,i"^("RHPC") - T_"step,i") + T_"sync,i")
$
For the RepastHPC implementation to provide a performance improvement over the sequential execution, the condition
$
Delta T_"total" < 0
$
must hold. Consequently, the cumulative synchronization overhead must remain smaller than the computational savings achieved through parallelization:
$
T_"sync,init" + sum_(i=1)^N T_"sync,i" < (T_"init" - T_"init"^("RHPC")) + sum_(i=1)^N (T_"step,i" - T_"step,i"^("RHPC"))
$

Synchronization time is defined as the sum of two communication components: the synchronization of ghost agents between MPI ranks and the global tick synchronization performed at the end of each tick. Furthermore, the execution time of an individual tick can be decomposed into computation, synchronization and result-processing phases.

The synchronization metric reported throughout this chapter corresponds to the arithmetic mean of the total synchronization time measured across all MPI ranks. This metric provides a convenient estimate of communication overhead but does not represent the true global synchronization cost. A more accurate measure would require identifying each synchronization window individually and summing the maximum synchronization time observed across all ranks for every synchronization event. Due to limitations of the available trace-analysis workflow, extracting synchronization windows at this level of detail proved impractical. As a result, the reported synchronization times should be interpreted as a lower-bound estimate of the actual synchronization overhead.

#v(10pt)
*Default setup*

When executing the performance analysis, a systematic exploration of the model parameters has been conducted to understand their impact on the performance metrics. The parameters studied include the number of MPI ranks, the number of agents in the synthetic network, the type of synthetic network used, the average degree of the network, the partitioning strategy for distributing the network across MPI ranks, and two synthetic factors: MPI message size and computational load.

Each model has a default setting for each of the parameters explored that has been chosen based on a balance between computational feasibility and representativeness of real-world scenarios. This default setup serves as a baseline for studying the impact of the mentioned parameters on the performance metrics.

#v(10pt)
*Network topologies*

For the network setup, a set of synthetic networks have been generated to evaluate the performance of the misinformation diffusion model. The synthetic network generation process allows the creation of controlled environments with specific characteristics, such as network size, degree distribution and clustering coefficient. Understanding the structural properties of the networks used in the performance analysis is essential for interpreting the observed performance results.

Three synthetic network models were selected to represent distinct structural scenarios commonly encountered in social network analysis. Their differing degree distributions and clustering properties make it possible to evaluate how network topology influences communication overhead, partition quality and scalability. @DegreeDistributionComparison illustrates the degree distribution of each generated networks.

+ *Holme-Kim* network @Holme2002. This model generates scale-free networks with a power-law degree distribution while allowing control over the average clustering coefficient. Since both heavy-tailed degree distributions and high clustering are characteristic features of many real-world social networks, the Holme-Kim model serves as the primary benchmark topology throughout this study.
+ *Watts-Strogatz* network @WattsStrogatz1998. This model produces networks with a relatively narrow degree distribution and a tunable clustering coefficient. Due to its highly clustered structure and more homogeneous degree distribution, it provides a favourable scenario for graph partitioning algorithms.
+ *Barabási-Albert* network @BarabasiAlbert1999. Similar to the Holme-Kim model, it generates scale-free networks with a power-law degree distribution. However, it exhibits significantly lower clustering coefficients. As a result, it represents a structural scenario that contrasts with the Watts-Strogatz model, allowing the evaluation of partitioning strategies under conditions where highly connected hubs dominate the network topology but local clustering is limited.

#figure(
  grid(
    columns: 3,
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/degree_distribution.png"),
    image("../misinformation-diffusion-repast-hpc/figures/watts_strogatz/degree_distribution.png"),
    image("../misinformation-diffusion-repast-hpc/figures/barabasi_albert/degree_distribution.png"),
  ),
  caption: "Degree distribution for, left to right, Holme-Kim, Watts-Strogatz and Barabási-Albert.",
  placement: auto,
)<DegreeDistributionComparison>

Each simulation run has been executed multiple times to account for variability in execution time and performance metrics. The results presented in the following sections are based on the average values obtained from these runs.


== Misinformation diffusion model results

As mentioned in the methodology section, the parameters studied in the performance analysis have a default or baseline configuration. @DefaultConfig provides a detailed description of the default configuration used for the performance analysis of the misinformation diffusion model.

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
    [*Partition*], [Strategy used for partitioning the network across MPI ranks.], [Fluid Communities],
    [*Msg extra size*], [Size of the messages exchanged between agents during the communication phase.], [0 bytes],
    [*CPU extra load*], [Computational load of the agent state update function, measured in operations.], [0 operations],
  ),
  caption: "Default configuration for the performance analysis of the misinformation diffusion model.",
  placement: auto,
) <DefaultConfig>

#v(10pt)
*Partitioning strategy analysis*

The naive partitioning strategy assigns agents to MPI ranks according to a modulo operation on the agent identifier. As a result, the assignment is effectively independent of the network topology and can be regarded as a pseudo-random distribution of agents across ranks. In contrast, the Fluid Communities @Pares2017fluid partitioning strategy first identifies network communities and subsequently assigns communities to MPI ranks. Agents that belong to the same community are therefore placed within the same rank.

@PartitioningTimeAnalysis compares the execution time breakdown obtained using the naive and Fluid Communities partitioning strategies. The results show that the fluid communities strategy consistently outperforms the naive approach. The improvement is primarily explained by a reduction in synchronization time, while computation time remains largely unchanged. Since neighbouring agents tend to belong to the same community, a larger fraction of agent interactions occurs locally within each rank. Consequently, the number of ghost agents and the volume of inter-rank communication are reduced. @PartitioningMessageAnalysis compares the communication overhead of the two partitioning strategies. The volume of inbound and outbound communication for all agents is drastically reduced when partitioning the network based on the fluid communities algorithm.

These results demonstrate that partition quality is a critical factor in the performance of distributed agent-based simulations. By preserving network locality, community-aware partitioning reduces communication overhead and improves overall execution time.

#grid(
  columns: 4,
  column-gutter: 10pt,
  [],
  [#figure(
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/time_distribution_per_partition_strat.png", width: 97%),
    caption: "Execution time breakdown per partitioning strategy."
  )<PartitioningTimeAnalysis>],
  [#figure(
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/message_size_per_partition_strat.png"),
    caption: "MPI message size by message direction per partition strategy."
  )<PartitioningMessageAnalysis>],
  [],
)

#v(10pt)
*Network structure analysis*

@NetworkStructureAnalysis presents the impact of network topology on the execution time breakdown. The analysis focuses on two structural properties: the average degree and the average clustering coefficient. The results indicate a strong dependency on the average clustering coefficient, whereas the influence of the average degree is comparatively weaker. As the clustering coefficient decreases, synchronization costs increase significantly and become a larger fraction of the total execution time. This behaviour can be explained by the characteristics of the fluid communities partitioning strategy. Highly clustered networks naturally contain well-defined communities, allowing connected agents to be grouped within the same rank. When the clustering coefficient decreases, community boundaries become less distinct and the partitioning algorithm is less effective at preserving locality. Consequently, a larger number of ghost agents must be maintained across rank boundaries, increasing communication overhead.

#figure(
  grid(
    columns: 2,
    image("../misinformation-diffusion-repast-hpc/figures/degree_and_clustering_vs_time.png"),
    image("../misinformation-diffusion-repast-hpc/figures/degree_and_clustering_vs_time_interpolated.png"),
  ),
  caption: "Total execution time for each network type, positioned by network average degree and average clustering coefficient. Interpolated results on the right.",
  placement: auto,
)<NetworkStructureAnalysis>

These findings suggest that network clustering is one of the most influential structural factors affecting distributed simulation performance, particularly when community-based partitioning strategies are employed.

#v(10pt)
*Rank analysis*

@RankAnalysis shows the effect of increasing the number of MPI ranks on the execution time breakdown for the different network topologies considered. The observed behaviour differs substantially between the network models. For the highly clustered network topology, total execution time decreases as the number of ranks increases, indicating that the computational savings obtained through parallelization outweigh the additional synchronization overhead. In contrast, for the weakly clustered scale-free network, execution time increases with the number of ranks.

The opposite trends can be explained by the effectiveness of the partitioning strategy. In networks with well-defined communities, partitioning successfully minimizes inter-rank communication, allowing the computational workload to be distributed efficiently. Conversely, in networks where community structure is weak, the number of ghost agents grows rapidly as additional ranks are introduced. Under these conditions, synchronization costs increase faster than computation costs decrease.

The results highlight that increasing the number of MPI ranks does not necessarily improve performance. The effectiveness of parallelization is strongly dependent on the ability of the partitioning strategy to preserve network locality and limit communication overhead.

#figure(
  grid(
    columns: 2,
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/rank_vs_time.png"),
    image("../misinformation-diffusion-repast-hpc/figures/barabasi_albert/rank_vs_time.png"),
  ),
  caption: "Execution time breakdown per number of total MPI ranks for Holme-Kim (left) and Barabási-Albert (right) networks.",
  placement: auto,
)<RankAnalysis>

#v(10pt)
*Agent count analysis*

@AgentCountAnalysis presents the effect of increasing the number of agents on the execution time breakdown.
As expected, both computation and synchronization costs increase with the size of the network. The observed growth is approximately linear with respect to the number of agents, indicating that the computational workload and communication requirements scale proportionally to the problem size within the range explored.

The linear trend suggests that the implementation scales predictably with increasing network size. Although larger networks require additional communication due to the increased number of agent interactions, synchronization costs do not exhibit evidence of linear growth under the evaluated conditions.

#figure(
  grid(
    columns: 2,
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/agents_vs_time.png", width: 80%),
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/agents_vs_time_ratio.png", width: 80%),
  ),
  caption: "Execution time breakdown per number of agents in absolute (left) and relative (right) time.",
  placement: auto,
)<AgentCountAnalysis>

#v(10pt)
*Rank-Agent dependency*

In @TimeRankAgentDependency, the execution time breakdown for different combinations of ranks and agents is presented. The results indicate that the performance improvement from increasing the number of ranks is more pronounced with a larger number of agents, suggesting that the model benefits from parallelism as the computational load increases. Note how the Barabási-Albert results show a much less pronounced improvement as the number of ranks and agents increase, and a dip in performance when changing from single-rank execution to parallel execution.

#figure(
  grid(
    columns: 2,
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/ranks_and_agents_vs_time.png"),
    image("../misinformation-diffusion-repast-hpc/figures/barabasi_albert/ranks_and_agents_vs_time.png"),
  ),
  caption: "Execution time breakdown for different combinations of ranks and agents for Holme-Kim (left) and Barabási-Albert (right) networks.",
  placement: auto,
)<TimeRankAgentDependency>

#v(10pt)
*Computational load analysis*

@ComputationalLoadAnalysis presents the effect of increasing the synthetic computational load applied during the agent update phase. In the context of the misinformation diffusion model, this parameter can be interpreted as representing increasingly complex decision-making processes when agents evaluate the credibility of information. The results show a linear increase in computation time as the additional workload increases. In contrast, synchronization times remain largely unaffected, since the communication pattern of the model does not change with the complexity of the agent update logic. As a consequence, the relative contribution of communication overhead decreases for computationally intensive scenarios. This behaviour is characteristic of distributed applications in which communication costs remain constant while the amount of local computation increases.

These results indicate that the parallel implementation becomes increasingly advantageous as the computational complexity of individual agent updates grows.

#figure(
  grid(
    columns: 2,
    gutter: 10pt,
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/extra_compute_vs_time.png", width:80%),
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/extra_compute_vs_time_ratio.png", width:80%),
  ),
  caption: "Execution time breakdown per extra computational load in absolute (left) and relative (right) time.",
  placement: auto,
)<ComputationalLoadAnalysis>

#v(10pt)
*MPI Message size analysis*

@MessageSizeAnalysis presents the effect of increasing the synthetic MPI message size exchanged during the ghosts synchronization phase. In the context of the misinformation diffusion model, this parameter can be interpreted as representing more information during the communication of the hoax and current belief status via messages between agents. The results show a linear increase in synchronization time as the additional message size increases. In contrast, computational times remain unaffected for the same reason presented in the computational load analysis.

These results indicate that the parallel implementation becomes increasingly disadvantageous as the individual agent communication package size grows.

#figure(
  grid(
    columns: 2,
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/extra_message_vs_time.png", width:80%),
    image("../misinformation-diffusion-repast-hpc/figures/holme_and_kim/extra_message_vs_time_ratio.png", width:80%),
  ),
  caption: "Execution time breakdown per extra MPI message size in absolute (left) and relative (right) time.",
  placement: auto,
)<MessageSizeAnalysis>

#pagebreak()

== Socio-epistemic knowledge spread model results

@DefaultConfigKnowledge provides a detailed description of the default configuration used for the performance analysis of the socio-epistemic knowledge spread model.

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
    [*Ranks*], [Number of MPI ranks used for the simulation.], [6 ranks],
    [*Agents*], [Number of nodes in the synthetic network.], [$10^3$ agents],
    [*Network*], [Type of synthetic network used for the simulation.], [Holme and Kim],
    [*Avg degree*], [Average degree of the synthetic network.], [4],
    [*Partition*], [Strategy used for partitioning the network across MPI ranks.], [Louvain],
    [*Msg extra size*], [Size of the messages exchanged between agents during the communication phase.], [0 bytes],
    [*CPU extra load*], [Computational load of the agent state update function, measured in operations.], [0 operations],
  ),
  caption: "Default configuration for the performance analysis of the socio-epistemic knowledge spread model",
  placement: auto,
) <DefaultConfigKnowledge>

#v(10pt)
*Methodological differences with the misinformation diffusion model*

The performance analysis of the socio-epistemic knowledge spread model follows the same methodology used for the misinformation diffusion model. The same instrumentation strategy, execution-time breakdown and performance metrics were employed, allowing direct comparison between the two models.

A key difference lies in the network partitioning. In the misinformation diffusion model, community detection and partition assignment are performed during model initialization and it relies on the Fluid Communities @Pares2017fluid algorithm. In contrast, the socio-epistemic knowledge spread model performs partitioning during network generation, storing the resulting partition identifier as a node attribute within the network file. During simulation initialization, agents are directly assigned to MPI ranks according to this precomputed partition information. This approach reduces initialization overhead and ensures that repeated executions use identical network partitions. The downside is that the number of communities does not necessarily have to match to the total number of ranks, which can create load imbalances.

Another difference concerns the community detection algorithm employed. Whereas the misinformation diffusion model relies on the Fluid Communities algorithm, the socio-epistemic knowledge spread model uses the Louvain algorithm @Blondel2008fast to identify communities within the network.

Although the same timers are used in both models, some timers capture different operations. In particular, the initialization phase includes not only network loading and agent instantiation but also the generation of the epistemic landscape through a k-means clustering procedure. Furthermore, the ghost synchronization phase is more complex than in the misinformation diffusion model. In addition to synchronizing agent state, the communication phase must also support the temporal evolution of the network by activating edges whose creation time is reached during the simulation. Finally, The identification of ghost agents is also substantially more expensive. While the misinformation diffusion model only requires tracking immediate neighbours, the socio-epistemic knowledge spread model must maintain information about agents located up to three network hops away. Consequently, determining which ghost agents must be synchronized requires traversing a significantly larger neighbourhood around each local agent, increasing the cost associated with agent synchronization management.

#v(10pt)
*Partitioning strategy analysis*

@PartitioningTimeAnalysisKS compares the execution-time breakdown obtained using the Louvain-based partitioning strategy and the baseline Node-ID partitioning approach. The results in @PartitioningMessageAnalysisKS show that the Louvain partitioning strategy substantially reduces communication volume compared with the Node-ID strategy. This behaviour is expected, as community-aware partitioning places strongly connected agents within the same MPI rank and therefore reduces the number of ghost agents and inter-rank messages.

#grid(
  columns: 4,
  column-gutter: 10pt,
  [],
  [#figure(
    image("../knowledge-spread-repast-hpc/figures/time_distribution_per_partition_strat.png", width: 98%),
    caption: "Execution time breakdown per partitioning strategy."
  )<PartitioningTimeAnalysisKS>],
  [#figure(
    image("../knowledge-spread-repast-hpc/figures/message_size_per_partition_strat.png"),
    caption: "MPI message size by message direction per partition strategy."
  )<PartitioningMessageAnalysisKS>],
  [],
)

However, unlike the misinformation diffusion model, the reduction in communication volume does not translate into a noticeable reduction in total execution time, but rather an increase. This behaviour suggests that communication itself is not the dominant bottleneck of the model. Instead, the cost associated with identifying and managing ghost agents appears to be more significant than the cost of exchanging synchronization messages. Trace analysis performed using Jumpshot supports this interpretation, revealing that a substantial fraction of the synchronization phase is spent determining which ghost agents require updates rather than performing MPI communication operations.


#v(10pt)
*Network structure analysis*

@NetworkStructureAnalysisKS presents the impact of network topology on the execution-time breakdown. A notable difference emerges when comparing these results with those obtained for the misinformation diffusion model. Whereas the previous model exhibited a strong dependency on the average clustering coefficient, the socio-epistemic knowledge spread model is considerably more sensitive to the average degree of the network.

#figure(
  grid(
    columns: 2,
    image("../knowledge-spread-repast-hpc/figures/degree_and_clustering_vs_time.png"),
    image("../knowledge-spread-repast-hpc/figures/degree_and_clustering_vs_time_interpolated.png"),
  ),
  caption: "Total execution time for each network type, positioned by network average degree and average clustering coefficient. Interpolated results on the right.",
  placement: auto,
)<NetworkStructureAnalysisKS>

As the average degree increases, execution times grow substantially due to the larger number of neighbour relationships that must be maintained and synchronized across ranks. Since the model requires tracking information up to three hops away from each local agent, an increase in node degree leads to a rapid growth in the number of relevant neighbouring agents. Consequently, both ghost-management costs and synchronization overhead increase. By contrast, variations in the clustering coefficient have a smaller impact on performance. Although highly clustered networks may still improve partition quality, the benefit is reduced because the model requires information from agents that are multiple edges away. Under these conditions, preserving immediate community structure becomes less effective at reducing communication requirements.

These findings suggest that the dominant performance bottleneck is not the existence of inter-rank connections themselves, but rather the number of neighbouring relationships that must be tracked and maintained throughout the simulation.

#v(10pt)
*Rank analysis*

@RankAnalysisKS shows the effect of increasing the number of MPI ranks on the execution-time breakdown. Compared with the misinformation diffusion model, a substantially larger fraction of the total execution time is spent in tick synchronization operations. This behaviour is attributed to load imbalance between MPI ranks.

The imbalance originates from the partitioning strategy employed. While the Louvain algorithm is effective at identifying community structure, it does not explicitly optimize for equal partition sizes. As a result, some MPI ranks may contain significantly more agents than others. Since global synchronization requires all ranks to progress at the same pace, faster ranks remain idle while waiting for slower ranks to complete their computations.

#figure(
  image("../knowledge-spread-repast-hpc/figures/rank_vs_time.png", width: 60%),
  caption: "Execution time breakdown per number of total MPI ranks.",
  placement: auto,
)<RankAnalysisKS>

To further analyse the load imbalance between ranks, @MPISyncTimeDistribution presents the distribution of MPI synchronization time used. The spread in samples represents the difference of time waiting for other ranks, thus showing the load imbalance is present for all total number of ranks except the single threaded execution.

#figure(
  image("../knowledge-spread-repast-hpc/figures/rank_vs_mpi_sync_time_distribution.png", width: 60%),
  caption: "MPI Synchronization time per number of total MPI ranks.",
  placement: auto,
)<MPISyncTimeDistribution>
