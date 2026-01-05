= Introduction

== Problem description


Agent Based Modelling is a computational method used to simulate the actions and interactions of autonomous agents (individuals, companies, cells) and study their effects on the system as a whole. Its goal is to understand complex phenomena by watching it emerge from the individual interactions between a large number of agents. The complex group behavior is not modelled nor programmed directly, but it naturally occurs, as in an ant colony.

High Performance Computing (HPC) is the practice of aggregating computing power in a way that delivers much higher performance than a single workstation could deliver. It relies on the concept of parallel processing in order to break down a single job with considerable computational work into multiple smaller jobs that can be processed at the same time. All HPC systems are composed of nodes, which perform the calculations, and interconnections, which allow for communication between nodes.

Given the parallel nature of agent based systems, it's logical to combine the two disciplines to unlock the ability to simulate millions of agents in reasonable time. But, can one quantify the real performance gain of implementing an agent based model in a high performance computing platform? Which are the performance bottlenecks of the HPC platforms that accelerate ABMS? Is there any way to alleviate those? This Master thesis work will answer the mentioned questions by studying the performance of Agent Based systems implemented in High Performance Computing platforms.

== State of the art

Over the past two decades, several frameworks for implementing agent-based modeling and simulation (ABMS) on high-performance computing (HPC) systems have been proposed and applied to real-world case studies. Among the most prominent examples are FLAME @flame, FLAME GPU @flameGpu, RepastHPC @repastHpc @repastWeb and DMASON @dmason. These frameworks are designed to allow domain specialists to build large-scale simulations without directly dealing with the low-level complexities of parallelism. Despite this shared motivation, they adopt different design choices: agents and environments may be defined using diverse languages and formalisms, inter-agent interactions can rely on distinct communication strategies, and different support for features such as load balancing. These architectural and implementation choices influence scalability and efficiency, leading to substantially different performance outcomes depending on the framework beign chosen and the simulation model characteristics.

Benchmarks on the performance discrepancies between different HPC frameworks and ABMS characteristics have been performed by @ROUSSET2016 and @MORENO2023, shedding light on the problem of which HPC framework to select depending on the simulation model. This work focuses in the RepastHPC framework to implement the parallelized versions of the agent based models. It is selected for its C++ based architecture designed specifically for TOP500 class supercomputers, utilizing MPI (Message Passing Interface) for efficient cross-process communication and spatial decomposition.

The Computational Model Library provided by the CoMSES Net @comses @comsesWeb has been the primary database for exploring and publishing ABMS since its publication more than a decade ago. This platform acts as a common sharing ground of peer-reviewed, reproducible models that follow the standard ODD protocol, providing a reliable foundation for the performance analysis.

== Objectives

The main objective of the work is to evaluate the performance and identify the bottlenecks of two existing complex agent based models implemented in the Repast HPC framework. To achive that, the following intermediate objectives are presented:

+ *Models research and selection*: Selecting two representative social network agent based models, that could be implemented in an HPC framework to support millions of agents.

+ *Detailed analysis for the selected models*: The exhaustive analysis will include descriptions on the model internal logic, the agent relationship and communication, the complexity of the agent and environment logic and the inputs of outputs of the model.

+ *Implementing the selected ABMS in an HPC framework*: Description of the Repast HPC framework fundamentals and how each model has to be implemented according to Repast HPC concepts like the Scheduler, the Context and MPI communication. Validation and verification of the programs to ensure that the model has been implemented properly.

+ *Simulation execution and analysis performance*: Benchmark executions with parameter sweeping and scalability tests to measure performance metrics like execution time, resource usage, and parallel efficiency.

+ *Bottleneck identification*: The main part of the analysis will be centered around identifying, quantifying and describing the nature of the inefficiencies and bottlenecks of each model.

Finally, a secondary objective on a *graph partitioning algorithm benchmarking* focuses on testing a new load balancing algorithm that distributes work between nodes in an HPC cluster by partigioning a graph in a certain new way to improve the overall system performance.


== Methodology

To achieve the mentioned objectives in the previous section, the following methodology will be applied

- *ABMS literature review*: Use CoMSES Net model repository and academic databases to analyse and select two social networks agent based models. In order to validate the model selection, the following properties will be analyzed:
  - _Model domain_: Description of the model representation, inputs, outputs and purpose. 
  - _Agent relationship_: Number of agent kinds and the relationship between them, description of their communication mechanism, content and criteria.
  - _Model complexity_: Evaluation of the underlying logic for agents and environment

- *Implementing the ABMS in an HPC framework*: Select the appropiate framework using the benchmarks designed for ABMS performance evaluation for HPC in @MORENO2023 and @MORENO2019.

- *Define testing hardware, environment and performance metrics*: The specific HPC infrastructure for executing the models is currently under evaluation. The final selection will depend on resource availability and the specific hardware requirements dictated by the complexity of the selected models.

== Planning

Follows an enumeration and description of all the tasks needed to achieve the work's objectives:

+ *ABMS research and selection*
  + Introduction to CoMSES Net's Computational Model Library. 
  + Preselection of most interesting ABMS found with an initial superficial analysis.
  + Final selection of 2 ABMS that fit the criteria defined previously.

+ *Models in-depth analysis*
  + Description of the model domain, inputs, outputs and purpose.
  + Description of the model agents behaviour, relationship and parameters.
  + Identification of the parameter sweeping for performance evaluation.

+ *HPC implementation*
  + Introduction to HPC frameworks and their unique characteristics.
  + Introduction to RepastHPC.
  + Implementation of models with RepastHPC.

+ *Execution and validation*
  + Programs validation to ensure that the models have been implemented properly. 
  + Executions with parameter sweeping and scalability tests to measure performance metrics: execution time, resource usage, parallel efficiency...

+ *Performance analysis*
  + Analysis of performance metrics results.
  + Identification of bottleneck and possible causes.

#v(20pt)
#figure(
  include "planning-gantt.typ",
  caption: "Gantt diagram for task planning"
)

== Ethical, social and environmental impact

This work contributes to the advancement of computational social science by enabling larger and more accurate simulations of complex systems. By identifying performance bottlenecks in economic and social network models, this research facilitates the creation of digital twins that can be used by governments to predict economic crises or the spread of misinformation with higher fidelity.

Ethically, the work promotes transparency in algorithmic decision-making by optimizing open-source tools like RepastHPC and relying on open-access model libraries like CoMSES, democratizing access to powerful simulation capabilities.

Environmentally, the focus on performance optimization and bottleneck identification directly relates to energy efficiency. By reducing the computational resources required to run massive simulations, the carbon footprint of large-scale research projects can be minimized.

