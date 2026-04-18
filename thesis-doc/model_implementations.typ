= Model implementations

The core objective of the upcoming third chapter of this Master's thesis is the adaptation and implementation of the aforementioned social network models onto the Repast HPC platform. Transitioning the models from a single-threaded, high-level, interpreted environment like NetLogo into a highly distributed, compiled C++ and MPI-based framework requires profound architectural shifts and a deep understanding of parallel computing paradigms. The implementations must carefully map the conceptual socio-cognitive components of the ABM's to Repast HPC's strict distributed memory architecture.   

== Parallelizing the misinformation diffusion model

Translating the extended SBFC model from its original NetLogo format into Repast HPC demands a fundamental shift in programming paradigms. While NetLogo relies on an interpreted, single-threaded execution loop that evaluates agents sequentially or in randomized batches, Repast HPC utilizes a compiled, distributed-memory C++ architecture built on top of the Message Passing Interface (MPI).  

In a distributed environment, the global network of 4,039 Facebook nodes is not held in a single block of memory. Instead, the network graph and its constituent agents must be spatially partitioned across multiple processes (ranks). As the simulation scales to millions of agents in later benchmarking phases, the algorithms governing agent interaction, specifically the spreading functions evaluating neighbor states, must be carefully constructed to accommodate data that is non-local and potentially stale between synchronization steps.   

#v(0.25cm)
*Representing the misinformation diffusion agent in RepastHPC*

In Repast HPC, the foundational memory container for the simulation is the `Context`. The `Context` encapsulates the agent population, ensuring through strict set semantics that only a single, unique instance of an agent exists within the logical bounds of the simulation. For this misinformation model, the `Context` will hold all instances of Scholars, Influencers, Normal agents, and Bots, managing their creation and lifecycle.

To represent the complex Facebook topology used in the original model simulations, the model must implement a `SharedNetwork` projection. A projection in Repast HPC is a construct that imposes a specific relational structure upon the otherwise unstructured pool of agents residing in the `Context`. When an agent is instantiated and added to the `Context`, it automatically becomes a vertex in the `Network` projection, and the specific edges representing social connections are mapped according to the parsed dataset.

The temporal execution of the model is governed by Repast HPC's dynamic discrete-event scheduler. Unlike simple loop-based simulators, the scheduler operates on a principle of conservative synchronization. At each tick, representing one hour of simulated time in the news cycle, the scheduler pops the next prioritized event from its queue. In the context of the misinformation model, a single scheduled tick involves a massive sequence of highly orchestrated operations for every active agent:
+ Query the current state (S, B, FC) and the specific class type (SC, I, N, BOT) of all connected neighbours via the `Network` projection.
+ Calculate the fractional ratios for the spreading functions $f_i (t)$ and $g_i (t)$.
+ Evaluate the independent verification ($p_"verify"$) and forgetting ($p_"forget"$) probabilities, dynamically accessing the specific parameters based on the agent's assigned class.
+ Generate a high-entropy random number using the boost/MPI synchronized random number generators to trigger the stochastic transitions.
+ Determine and lock in the discrete state for $t+1$.

#v(0.25cm)
*Distributed memory management*

Repast HPC is explicitly designed for distributed-memory hardware architectures, utilizing the Message Passing Interface (MPI) standard to parallelize operations across multiple separate compute nodes. In this architecture, the global `Context` and the massive `Network` projection do not exist as a single, contiguous entity in any single processor's memory. Instead, the agents are spatially partitioned and distributed across multiple MPI processes, known as `ranks`.

Each MPI process is strictly and exclusively responsible for the computation of its assigned local agents. For example, if Process 1 (P1) holds Agent A, and Process 2 (P2) holds Agent B, P1 computes the transition logic for A, and P2 independently computes it for B. However, the highly interconnected nature of a scale-free social network guarantees that thousands of edges will span across process boundaries. If Agent A (residing on P1) is followers with Agent B (residing on P2), Agent A absolutely needs to read Agent B's state to correctly calculate its local spreading functions $f_A (t)$ and $g_A (t)$.

Because physical memory is not shared in an MPI environment, P1 cannot simply dereference a pointer to read the memory address of Agent B on P2. Repast HPC resolves this fundamental distributed computing problem through the creation of "non-local" or "ghost" agents. In this system, P1 requests a copy of Agent B from P2 over the network. This ghost copy is instantiated and resides locally in P1's Context. When Agent A iterates through its neighbours during the update step, it reads the local ghost copy of Agent B without needing to perform an expensive network call mid-computation.

*Parallel communication management*

Crucially, the code executing on P1 is strictly forbidden from altering or writing to the state of the ghost Agent B. Agent B is the sovereign property of its home process, P2. Because Agent B might stochastically change its state from Susceptible to Believer on P2 during a tick, the ghost copy sitting on P1 becomes instantly stale.

To maintain strict simulation coherence and prevent causality errors, Repast HPC requires the explicit, synchronized updating of all ghost agents across all process boundaries at the end of every tick. This complex data serialization is achieved using the Repast HPC `Package` pattern. The C++ implementation of the model must define:
- A *`Package`*: A lightweight, optimized C++ struct containing only the absolute minimal state data required for network transmission, in this case, the agent's unique ID, its current belief state, and its class type.
- A *provider*: A routine on the home process (P2) that efficiently extracts the state from the real Agent B and serializes it into the `Package` for outbound MPI transmission.
- A *receiver*: A routine on the requesting process (P1) that receives the inbound `Package` array, deserializes the data, and maps the updates to the corresponding ghost Agent B.

The implementation will utilize Repast HPC's default `GhostMode` synchronization protocol. In `GhostMode`, writes are strictly local, and distant agents are read from a ghost copy representing the stable system state at the previous time step ($t-1$). While this ensures strict determinism and eliminates read-write race conditions, the mandatory block-synchronization of the entire boundary layer at the end of the tick induces massive latency, forming the primary barrier to scalability.

@MisinformationRepast depicts how Repast HPC handles the distributed memory and parallel communication in the specific case of the heterogeneous SBFC model: The global network that holds the relationships between agents is partitioned to distribute the work load among the multiple processes or ranks. To read data from agents in foreign processes, the framework requests a ghost read-only copy to the provider process and hands it over to the receiver process.

#figure(
  image("media/repasthpc_memory.pdf", width: 75%),
  caption: [Repast HPC memory management applied to the SBFC model], 
  placement: auto,
) <MisinformationRepast>

#pagebreak()

== Parallelizing the socio-epistemic knowledge spread model

Translating the socio-epistemic _"Opinion Dynamics of Science"_ model from its native NetLogo environment to Repast HPC introduces architectural complexities fundamentally different from the misinformation diffusion model. While both rely on network topologies, the socio-epistemic model operates within a highly coupled dual-layer environment: agents traverse a continuous spatial lattice representing abstract mental models (the epistemic layer) while simultaneously evaluating connections across a multi-layered graph (the social layer).

Distributing this model across multiple MPI processes requires a careful orchestration of Repast HPC's spatial partitioning, network projections, and ghost agent synchronization to ensure that the emergent formation of the giant component observed in the historical general relativity community is accurately and deterministically reproduced at scale.

#v(0.25cm)
*Representing the socio-epistemic agent and dual projections*

In Repast HPC, the global population of scientists is managed within a `repast::SharedContext`. To represent the complex environmental duality of the NetLogo model, this `Context` must be projected into two distinct spaces simultaneously:

- `repast::SharedContinuousSpace`: This projection replaces the discrete patches of NetLogo. It provides a continuous 2D Cartesian coordinate system where agents represent their current epistemic stance. The Euclidean distance between coordinates serves as the proxy for cognitive similarity.

- `repast::SharedNetwork`: Superimposed over the continuous space, this directed network projection manages the historical or procedural collaboration edges.

The local state variables that each individual scientist agent encapsulates are described in @ScientistAgentAttrs.

#figure(
  table(
    columns: (auto, 1fr),
    inset: (x: 8pt),
    align: (x, y) => if x == 0 { right } else { left },
    stroke: (x, y) => if y == 0 or y == 3 {
      (right: none, top: none, bottom: 0.5pt, left: none)
    } else { none },
    table.header([*Attribute*], [*Description*]),
    [`birth`], [Serves as an age and rigidity modifier],
    [`conference_flag`], [Flag for temporary aggregate movement from the conference force],
    [`topic_color`], [Indicator for which epistemic cluster the agent belongs to],
  ),
  caption: "Scientist agent internal attributes",
  placement: auto,
) <ScientistAgentAttrs>

*Spatial partitioning and the ghost buffer zone*

The primary challenge in parallelizing this model lies in the spatial decomposition of the epistemic layer. Repast HPC divides the continuous space into geometric regions, assigning each region to a specific MPI rank. However, the model's core attraction forces, specifically the Semantic Closeness force and the Gravity force, require agents to evaluate the exact positions and densities of other agents within a specific radius.

Because an agent A near the boundary of node 1's spatial partition might need to evaluate an agent B residing on node 2, a _buffer zone_ must be established. Repast HPC populates this buffer zone with ghost agents. The width of this buffer zone must be mathematically strictly greater than or equal to the maximum possible dist parameter configured for the simulation sweep. If the buffer is too narrow, the spatial density calculations driving the gravity force will experience boundary truncation errors, invalidating the simulation's emergent dynamics.

*Synchronization and resolving the network-space conflict*

The dual-layer nature of the model creates a severe parallelization conflict: two agents perfectly adjacent in the social network might reside on entirely opposite sides of the epistemic spatial grid, and therefore on completely different compute nodes. If agent A on node 1 needs to evaluate its co-author agent B on node 3 for the Social movement force, node 1 requires a network-based ghost of agent B, independent of the spatial buffer zone.

To maintain coherence across both projections, the Repast HPC simulation must execute a complex, two-tiered synchronization at the beginning of every tick. The implementation defines a `ScientistPackage`: a lightweight C++ struct containing only the mutable properties of the agent.

During synchronization, the system first updates the status of all ghost agents across the network edges, ensuring topological consistency. Immediately following, it synchronizes the spatial buffer zones to ensure geographic consistency. Only after both synchronization barriers are cleared can the scheduler safely iterate over the local agents to calculate the logistic speed function and execute the movement algorithms.

