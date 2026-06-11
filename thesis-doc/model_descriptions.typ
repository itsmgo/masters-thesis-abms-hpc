= Model descriptions

The evaluation of High Performance Computing frameworks for Agent-Based Modelling and Simulation requires the selection of baseline models that are robust, computationally significant, and relevant to contemporary science. Following the methodology and objectives outlined in the introductory chapter, the models selected for this performance analysis operate within the domain of computational social science, specifically focusing on the diffusion of information in a social network. This chapter provides an exhaustive analysis of the models internal mechanisms, mathematical foundations, agent interactions, and the specific variables that will govern the subsequent HPC implementation and benchmarking phases.

== Misinformation diffusion model

The first selected model, archived in the COMSES Net Computational Model Library under version 1.0.0, is titled _"Controlling the Misinformation Diffusion in Social Media by the Effect of Different Classes of Agents"_ @misinformationArticle @misinformationComses and describes the spread of misinformation and the corresponding countermeasures in digital social networks.

This model represents an architectural extension of the foundational Susceptible-Believer-FactChecker (SBFC) epidemic model originally proposed in @TambuscioRuffoFlamminiMenczer2015 @Tambuscio2020. While the original SBFC framework established the mathematical model for simulating the competitive diffusion of a viral hoax and its debunking information within a homogeneous population, the selected extended model introduces significant topological and behavioral complexities that mirror real-world dynamics. By categorizing the network nodes into distinct, heterogeneous agent types: Scholars, Influencers, Normal Agents, and Bots, the model accurately captures the asymmetric influence and dynamic belief structures present in real-world platforms like Facebook @Willmore2016Analysis.

From a computational perspective, the introduction of heterogeneous agent classes and targeted intervention strategies significantly increases the computational load required for each agent evaluation cycle. Furthermore, simulating this environment over a large-scale, highly connected graph introduces intricate memory access patterns and inter-agent communication dependencies that supose a challenge to parallelize efficiently. These characteristics are precisely what expose the performance bottlenecks, parallelization inefficiencies, and synchronization overheads inherent in distributed-memory platforms such as Repast HPC. 

=== Epidemiological foundations: The baseline SBFC framework

The Susceptible-Believer-FactChecker model conceptualizes the spread of misinformation not as a simple, unidirectional contagion, but as a complex, simultaneous competitive process between a virus (the hoax) and its cure (the debunking information). By modeling hoaxes analogously to biological viruses, the framework borrows heavily from traditional compartmental epidemic models such as the Susceptible-Infected-Recovered (SIR) and Susceptible-Infected-Susceptible (SIS) paradigms. However, it splits the "Infected" compartment into two distinct and adversarial sub-compartments, creating a more dynamic state space. 

#v(0.25cm)
*I. Agent State Space and Network Topology*

The simulation environment is mathematically represented as a network graph $G=(V,E)$, where $V$ represents the set of vertices (the individual agents or users) and $E$ represents the set of edges (the social connections or follower relationships between them). At any discrete time step $t$, each agent is characterized by a specific behavioral state: This state is rigorously defined by a triple of binary indicators:

$ forall i in V #h(0.5cm) s_i(t) = [s_i^B (t), s_i^F (t), s_i^S (t)] = cases([1,0,0], [0,1,0], [0,0,1]) $

The state vector is constrained such that it can only assume one of three mutually exclusive configurations, corresponding to the agent's current cognitive stance regarding the circulating information:

- *Believer (B)*: Represented as $s_i^B (t) = 1$. In this state, the agent $i$ has been exposed to the hoax, believes it to be true, and actively participates in its propagation across the network.
- *Fact-Checker (FC)*: Represented as $s_i^F (t) = 1$. In this state, the agent $i$ has either independently verified the news or been exposed to debunking information. The agent recognizes the information as a hoax, adopts the factual narrative, and actively propagates the truth to its neighbours.
- *Susceptible (S)*: Represented as $s_i^S (t) = 1$. This is a neutral state. The agent $i$ is either entirely ignorant of the circulating narrative, or they have forgotten a previously held belief (either belief in the hoax or belief in the facts).

#v(0.25cm)
*II. Stochastic Transition Dynamics*

The temporal evolution of the system is governed by a stochastic, discrete-time Markov process. The probability that an individual agent $i$ transitions into or remains in a specific state at time $t+1$ is defined by a probability mass function:

$
p_i (t+1) = [p^B_i (t), p^F_i (t), p^S_i (t)] =
#linebreak()
=cases( p^B_i (t + 1) = f_i s_i^S (t) + (1 − p_"forget" − p_"verify" ) s_i^B (t),
                  p^F_i (t + 1) = g_i s_i^S (t) + p_"verify" s_i^B (t) + (1 − p_"forget" )s_i^F (t),
                  p^S_i (t + 1) = p_"forget" (s_i^B (t) + s_i^F (t)) + (1 − f_i − g_i )s_i^S (t)
                  )
$

where $p_"forget"$ , $p_"verify"$ are constant probabilities and $f_i$ , $g_i$ are the spreading functions that provide the network effect. @SBFC shows the three states and their primary sociocognitive phenomena that drive these probability distributions and subsequent transitions: Forgetting ($p_"forget"$), Verifying ($p_"verify"$) and Spreading ($f_i$, $g_i$).

The actual, deterministic state of the agent at the next sequential time step is then determined by a random realization of this distribution:

$ s_i (t + 1) = "MultiRealize"[p_i (t + 1)]. $


#figure(
  image("media/sbfc_state_diagram.pdf", width: 80%),
  caption: "States and transitions of the SBFC model",
  placement: auto,
) <SBFC>

#v(0.25cm)
*III. The Spreading Mechanism*

Two continuous spreading functions, $f_i (t)$ and $g_i (t)$, calculate the exact probability of a Susceptible agent $i$ adopting the hoax or adopting the debunking information, respectively. These functions evaluate the ratio of Believers and Fact-Checkers within the agent's immediate network neighborhood, modulated by global system parameters:

$ f_i (t) = beta (n_i^B (t) dot (1+alpha))/(n_i^B (t) dot (1+alpha) + n_i^F (t) dot (1-alpha)) $
$ g_i (t) = beta (n_i^F (t) dot (1-alpha))/(n_i^B (t) dot (1+alpha) + n_i^F (t) dot (1-alpha)) $

In these formulations, $n_i^B (t)$ and $n_i^F (t)$ represent the absolute, integer count of agent $i$'s direct neighbours who are currently in the Believer and Fact-Checker states at time $t$. The parameter $beta in [0, 1]$ represents the base spreading rate, defining the overall transmissibility or virality of information across the network, independent of its truthfulness. The parameter $alpha in [0, 1]$ is a constant parameter for the credibility of the hoax. It is critical to note that $f_i (t) + g_i (t) = \beta$, which aligns the total aggregate infection rate with traditional SIS epidemic models, ensuring mathematical consistency.

From a high-performance computing perspective, the evaluation of $n_i^B (t)$ and $n_i^F (t)$ represents one of the most significant computational burdens in the simulation. For an agent to calculate its spreading functions, the processor must fetch the state data of every single vertex connected to agent $i$. In dense, scale-free networks, a single agent may possess thousands of edges, requiring massive, non-contiguous memory access operations that frequently result in degraded performance.

#v(0.5cm)
*IV. Results*

The original authors of the SBFC model conducted extensive mean-field approximations to understand the infinite-time limit behavior of the system, assuming a homogeneous network where all vertices have the same degree $k$. Their mathematical analysis demonstrated that the density of susceptible individuals at equilibrium ($S_infinity$) depends solely on the spreading rate $beta$ and the forgetting probability $p_"forget"$, calculated as:

$ S_infinity = p_"forget" / (beta + p_"forget") $

The core analytical breakthrough of the baseline model, however, was the derivation of a hard threshold for the verification probability that guarantees the complete eradication of the hoax from the network, achieving a state where $B_infinity = 0$. By setting the equilibrium equation for Believers to zero and solving for $p_"verify"$, the sufficient condition for hoax eradication is expressed as:

$ p_"verify" >= (2alpha)/(1-alpha) dot p_"forget" $

This critical equation establishes that the minimum required fact-checking effort to eradicate a hoax is not linear. Instead, it scales non-linearly with the hoax's inherent credibility $alpha$ and proportionally with the network's overall forgetting rate. If a hoax is highly credible ($alpha$ approaches 1), the required verification effort approaches infinity. While this elegant mathematical threshold holds true for homogeneous, mean-field approximations, the dynamics alter significantly, and become vastly more difficult to predict, when network topologies exhibit real-world scale-free properties and when agent behaviors become heterogeneous. This limitation in the baseline model necessitates the transition to the extended model selected for this thesis.

=== Architectural enhancements: Heterogeneous agent classes

The fundamental flaw in utilizing the baseline SBFC model to analyze real-world social networks is its assumption of a homogeneous population. In the baseline model, every node in the graph exhibits the exact same propensity to verify information ($p_"verify"$), the exact same rate of memory decay ($p_"forget"$), and equal susceptibility to peer influence. Real digital social ecosystems, however, are characterized by vast disparities in user influence, media literacy, engagement algorithms, and automated bot activity.

The model selected for this HPC performance analysis addresses these limitations by introducing four distinct, behaviorally heterogeneous classes of agents. This extension pushes the model closer to reality and simultaneously increases the algorithmic complexity of the simulation, making it an excellent candidate for benchmarking distributed computing systems.

This enhancement transforms the localized neighbor counting mechanism. The transition equations that calculate $n_i^B (t)$ and $n_i^F (t)$ must now aggregate the influences of neighbours separated by their respective classes, requiring the simulation to query not only the state of each neighbor, but also its inherent class type during every iteration:

$ n_i^B (t) = n^B_"SC"_i (t) + n^B_"I"_i (t) + n^B_"N"_i (t) + n^B_"BOT"_i (t) $
$ n_i^F (t) = n^F_"SC"_i (t) + n^F_"I"_i (t) + n^F_"N"_i (t) + n^F_"BOT"_i (t) $

where the subscripts SC, I, N, and BOT denote Scholars, Influencers, Normal agents, and Bots, respectively. Follows a description of each agent type characteristics, sumarized in @MisinformationAgents:

- *Normal agents*: Normal agents constitute the vast, overwhelming majority of the network graph. They represent the standard, everyday users of a social media platform who consume and share information without specialized agendas or elevated media literacy. In the simulation, the Normal class operates strictly according to the baseline parameters originally defined in the homogeneous SBFC model. Specifically, they exhibit a standard, relatively high forgetting probability ($p_"forget" = 0.1$) and a low baseline verification probability ($p_"verify" = 0.05$). Because they represent the numerical bulk of the population, the global macroscopic state of the simulation, that is whether the hoax ultimately becomes an endemic fixture of the network or is successfully eradicated, heavily depends on the shifting beliefs of this specific class. Their behavior provides the underlying substrate through which the other, more specialized classes operate.

- *Scholars*: The Scholar class represents a minority subset of users characterized by high media literacy, a deeper understanding of factual information, and a proactive approach to debunking falsehoods. Behaviorally, Scholars exhibit a substantially higher probability of independently verifying incoming news, with experimental configurations testing $p_("verify"-"scholar") in [0.05, 0.3]$. Furthermore, because their beliefs are rooted in verified evidence rather than fleeting trends, they exhibit a significantly lower probability of forgetting their verified stance, with $p_("forget"-"scholar") in [0.02, 0.1]$. A critical topological constraint distinguishes the Scholar class from the rest of the population: they are not randomly or uniformly distributed across the network graph. Instead, they are densely concentrated within specific, highly interconnected structural clusters, simulating real-world academic, scientific, or professional knowledge silos.

- *Influencers*: Influencers model human users who possess disproportionate social reach and exceptionally high network centrality. Topologically, they are rigidly defined as the top 1% of nodes sorted by out-degree connectivity. Because they are connected to a massive number of follower neighbours, any state change in an Influencer rapidly cascades through the network, creating massive localized ripples in the $f_i (t)$ and $g_i (t)$ functions of thousands of normal agents. Behaviorally, Influencers are modeled to hold onto their public beliefs longer than Normal agents to maintain their brand identity, resulting in a lower $p_"forget"$. They also possess a variable, but generally higher, verification probability than normal users, simulating the resources they might have to evaluate information before broadcasting it to their large audiences.

- *Bots*: The Bot class introduces fully automated, algorithmic, and static agents into the social ecosystem. Bots represent the top 10% of nodes in terms of degree connectivity, explicitly excluding the already designated human Influencers. Crucially, Bots do not participate in the cognitive Markov transitions of the SBFC framework. They possess a zero probability of forgetting ($p_"forget" = 0$) and a zero probability of verification ($p_"verify" = 0$). Once initialized at $t=0$, their state is permanently immutable. Bots are further subdivided into two adversarial factions: Believer Bots and Fact-Checker Bots.

#figure(
  table(
    columns: (90pt, 180pt, 90pt, 90pt),
    inset: (x: 10pt, bottom: 6pt),
    align: (x, y) => if x == 0 { right } else { left },
    stroke: (x, y) => if y == 0 or y == 4 {
      (right: none, top: none, bottom: 0.5pt, left: none)
    } else { none },
    // header
    table.header([], [*Topology*], [*$p_"verify"$*], [*$p_"forget"$*]),
    // rows
    [*Normal*], [Uniformly distributed], [0.05], [0.1],
    [*Scholar*], [Densly contencentrated], [$in [0.05, 0.3]$], [$in [0.02, 0.1]$],
    [*Influencer*], [Nodes with top 1% of edges], [$in [0.05, 0.2]$], [$in [0.02, 0.1]$],
    [*Bot*], [Nodes with top 10% of edges], [0.0], [0.0],
  ),
  caption: "Agent type characteristics of the heterogeneous SBFC model",
  placement: auto,
) <MisinformationAgents>


=== Experimental input parameters

Evaluating the performance of this model within an HPC framework requires a rigorous, systematic parameter sweep. The experimental space must deliberately push the simulation across varied phases of execution: from states where the hoax dies out rapidly (resulting in low computational interaction and early equilibrium) to states of intense, enduring, network-wide competition between Believer and Fact-Checker cascades (resulting in high computational interaction and maximum resource utilization).

The defined input variables and their specific tested values, derived from the original literature, are detailed in @MisinformationParameters.

#figure(
  table(
    columns: (50pt, 1fr, 80pt),
    inset: (x: 6pt, bottom: 6pt),
    align: (x, y) => if x == 0 { right } else { left },
    stroke: (x, y) => if y == 0 or y == 10 {
      (right: none, top: none, bottom: 0.5pt, left: none)
    } else { none },
    // header
    table.header([*Param*], [*Description*], [*Values*]),
    // rows
    [$alpha$], [The inherent believability factor of the hoax. Higher values artificially increase the mathematical weight of Believer neighbors in the spreading functions.], [{ 0.3, 0.8 }],
    [$beta$], [The base transmission intensity determining how quickly beliefs spread from neighbors to a Susceptible agent, independent of truth.], [{ 0.5, 0.75 }],
    [$B_0$], [The percentage of the total agent population initialized in the Believer state at $t=0$, setting the initial infection seed.], [{ 10%, 40% }],
    [$p_"verify"^"SC"$], [The specific probability that an agent in the Scholar class will independently verify the news.], [{ 0.05, 0.1, 0.2, 0.3 }],
    [$p_"forget"^"SC"$], [The specific probability that a Scholar agent will forget their belief and revert to Susceptible.], [{ 0.02, 0.05, 0.1 }],
    [$p_"verify"^"I"$], [The specific probability that an agent in the Influencer class will independently verify the news.], [{ 0.05, 0.1, 0.2 }],
    [$p_"forget"^"I"$], [The specific probability that an Influencer will forget their belief and revert to Susceptible.], [{ 0.02, 0.05, 0.1 }],
    [$"BOT"_B$], [The percentage of top-degree nodes (excluding Influencers) algorithmically converted into static Believer Bots.], [{ 0%, 1%, 2%, 5% }],
    [$"BOT"_F$], [The percentage of top-degree nodes (excluding Influencers) algorithmically converted into static Fact-Checker Bots.], [{ 0%, 1%, 2%, 5% }],
    [Ticks], [The temporal duration of the simulation. Each tick represents one hour. 168 ticks represent a 7-days lifecycle.], [168],
  ),
  caption: "Input parameters of the heterogeneous SBFC model",
  placement: auto,
) <MisinformationParameters>


===  Validation methodology

To verify that the newly developed C++ Repast HPC implementation correctly captures the intricate dynamics of the original model, a rigorous validation protocol must be established. Because the underlying transition functions are highly stochastic, direct 1:1 validation of a single run is mathematically impossible; instead, the validation framework must rely on demonstrating statistical equivalence over large sample sizes.

The primary metrics for validation will be the mean densities of the three agent states $"B"_infinity$, $"FC"_infinity$, and $"S"_infinity$, at the conclusion of the 168-tick simulation cycle. The baseline experiments in the original literature generated 4 replicates for each of the 13,824 settings. Analysis of these replicates revealed a standard deviation of less than 5% relative to the total agent population, indicating good macroscopic model stability despite individual micro-level stochasticity.

The Repast HPC model will be executed using identical input parameter matrices and identical network topology. The resulting macroscopic curves must statistically match the baselines within a strict confidence interval. For example, an interesting dynamic to replicate would be the non-linear growth of Believers when hoax credibility is maximized ($alpha=0.8$), versus the total systemic dominance of Fact-Checkers when hoax credibility is minimized ($alpha=0.3$). Additionally, the localized, systemic effects of the heterogeneous classes, such as the specific 8-9% reduction in the global Believer population when the Scholar class is properly configured and educated, must be demonstrably reproducible in the parallelized environment.

Only once this statistical parity is achieved, the performance analysis phase can be started. The benchmark suite will then systematically scale the agent population and the allocated MPI processes, recording total execution time, memory overhead, parallel efficiency, and MPI communication latency to fully expose, analyze, and document the architectural bottlenecks of distributing complex social network models across High Performance Computing environments.

#pagebreak()

== Socio-epistemic knowledge spread model

The second selected model is the socio-epistemic framework titled _"An Opinion Dynamics of Science? Agent-Based Modeling of Knowledge Spread"_. Authored by Bernardo Buarque and published via the CoMSES Net Computational Model Library under version 1.0.0 @knowledgeComses, this model was developed under the guidance of the ModelSEN project, an initiative dedicated to modeling historical knowledge processes and the evolution of science @ModelSEN.

The model operates as a socio-epistemic simulation engine, conceptually based in the literature of opinion dynamics and the sociology of scientific knowledge. It is inherently multi-layered, simulating both the tangible social networks of researchers, represented as a graph, and the abstract epistemic spaces they navigate, represented as clusters in a two-dimensional spatial lattice. The fundamental purpose of the model is to identify and isolate the socio-structural mechanisms that drive the creation, diffusion, and eventual consensus of mental models within a bounded scientific community. By simulating the interplay between scientists, institutional proximity, and conceptual coherence, the model aims to answer how marginal ideas transition into mainstream paradigms.

For the specific purposes of this Master's Thesis performance analysis, this socio-epistemic model presents an ideal candidate for HPC implementation. It exhibits complexities that include dynamic network topologies that evolve over time, continuous spatial density evaluations, heterogeneous agent decision-making logic, and computationally intensive initialization phases. By translating the authors original NetLogo-based implementation into the C++ Message Passing Interface (MPI) architecture of Repast HPC, the subsequent phases of this research will accurately quantify parallelization efficiency, measure cross-node communication overhead, and isolate resource bottlenecks.

The following analysis systematically decomposes the historical validation parameters, the internal computational logic, and the specific algorithms that must be optimized for distributed execution. 

=== Historical and empirical validation context

To ensure the simulation generates sociologically valid outputs, the model is based in the historical phenomenon known as the _Renaissance of General Relativity_ @relativity2019 @Blum2020renaissance. This paradigm shift in theoretical physics, which occurred between 1925 and 1970, provides the foundational validation parameters and the empirical edge-list data utilized when the simulation operates in its historically driven mode. Understanding the exact contours of this historical dataset is critical, as any successful HPC implementation must not only execute efficiently but also accurately replicate the emergent macro-phenomena observed in the historical record.

#v(1.5cm)
*I. The Dynamics of the General Relativity Renaissance*

The status of the General Theory of Relativity underwent a radical and structurally profound transformation across a four-decade timespan. The historical consensus divides this evolution into two highly distinct phases, which the socio-epistemic model attempts to replicate via emergent agent behavior and spatial clustering.

During the initial phase, commonly referred to as the _Low-Water Mark_ (spanning from the mid-1920s to the mid-1950s), the theory maintained a highly marginal status within the broader physics community, often relegated to the domain of abstract mathematical curiosity. Research during this period was characterized by extreme fragmentation. It was pursued primarily by isolated individuals or small, disconnected academic groups operating under divergent epistemic agendas, such as unified field theory, the quantization of Einstein's equations, and theoretical cosmology. Co-authorship and cross-institutional collaboration were markedly sparse, reflecting a deeply divided epistemic landscape.

The subsequent phase, termed the _Renaissance_ (spanning from the mid-1950s to 1970), witnessed the theory's dramatic return to the scientific mainstream, eventually solidifying as a foundational pillar of modern physics. Historically, this transition was characterized by the rapid establishment of a highly uniform research field focused heavily on the theory's tangible physical and astrophysical predictions. Traditional historical narratives often attribute this renaissance to sudden external astrophysical discoveries, most notably the observational discovery of quasars in 1963.

However, extensive multilayer network analyses conducted by researchers associated with the ModelSEN project have empirically disproven this external-trigger hypothesis @relativity2019 @schlattmann2024trajectories. The historical data demonstrates that a fundamental structural shift in the underlying social collaboration network of physicists occurred between the late 1950s and early 1960s, significantly prior to these external astrophysical discoveries. The core mathematical signature of this shift was the sudden formation of a "giant component" within the social network graph, indicating a rapid, large-scale integration of previously isolated research clusters into a unified socio-epistemic community. The fundamental validation target of the ABM is to simulate the precise localized agent interaction rules that organically precipitate the emergence of this giant component without relying on external exogenous shocks.

#v(0.25cm)
*II. Empirical Network Parameters*

When the simulation is initialized using empirical data rather than procedural generation, it relies on highly specific network parameters extracted through analysis. The construction of this validation dataset required to capture the full picture of scientific interaction, acknowledging that simple co-authorship records are insufficient to map the true flow of knowledge. The node population of the model, termed the _General Relativity Social Space_, comprises a total of 971 unique authors acting as individual agents, described in @KnowledgeNetwork. This population was aggregated through meticulous historical data curation and bibliometric extraction @Lalli2020.

#figure(
  table(
    columns: (110pt, 1fr, 50pt),
    inset: (x: 6pt, y: 8pt),
    align: (x, y) => if x == 0 { right } else { left },
    stroke: (x, y) => if y == 0 or y == 2 {
      (right: none, top: none, bottom: 0.5pt, left: none)
    } else { none },

    // header
    table.header([*Node Source*], [*Identification Criteria*], [*Count*]),
    // rows
    [Web of Science (WoS) Extraction],[Authors publishing at least two distinct items within the defined general relativity publication space between 1925 and 1970.],[770],
    [Manual Historical Supplementation],[Authors identified via manual historical research (e.g., conference proceedings, review articles, and the Mathematics Genealogy Project up to 1971) to correct for missing or misindexed online records.],[201],
    [],[#align([*Total network nodes*], right)],[*971*]
  ),
  caption: "Node source methodology for the \"General Relativity Social Space\" network",
  placement: auto,
) <KnowledgeNetwork>

The underlying _General Relativity Publication Space_ used to define these nodes and calculate their initial epistemic positions consists of 8.296 indexed articles. This corpus was assembled through a multi-tiered search strategy. It began with an initial citation space anchored by Albert Einstein's foundational papers from 1915 to 1955, expanding outward to include two subsequent generations of citing literature. This citation mapping was then heavily augmented by multi-lingual keyword searches incorporating terms such as "quantum gravity", "unified field", and "cosmology" across English, German, French, and Italian databases.  

In the computational implementation of the model, agent activity is strictly temporally constrained to match this empirical reality. An agent node only exists in the active simulation space during its documented duration of activity, spanning strictly from the exact year of its first relevant publication to the year of its final recorded contribution. This empirical rigor provides a stable, deterministic benchmark against which the generative, stochastic outputs of the simulation's movement logic can be statistically validated across parameter sweeps.


=== Architecture and internal computational logic

#v(0.25cm)
*I. General model description*

The architecture of the NetLogo implementation relies on a highly coupled, dual-layer environment representing a conceptual synthesis of continuous spatial simulation and discrete network theory. This dual topology requires agents to manage coordinates in a Cartesian space while simultaneously maintaining references to a graph structure. This structural duality forms the core challenge for subsequent HPC translation.  

The model comprises several distinct computational entities that interact across a simulated timespan. The primary environment is composed of a continuous two-dimensional space with a discrete grid embbedded in it, representing the landscape of possible mental models. The moving agents represent the individual scientists navigating this epistemic landscape. The relationships between these scientists are instantiated as explicit network links, forming the social topology of the simulation.

The state variables defining these entities dictate the limits of their interaction. Each grid node belongs to a mental model, represented with different colours. The agents hold a birth date and a boolean flag indicating temporary assignment to academic conferences. This birth variable functions not only as a timestamp for temporal activation but mathematically serves as a proxy for age and epistemic rigidity, permanently altering the agent's velocity across the simulation space. Agents possess the capability to accurately perceive the logical validity of their immediate spatial environment, recognising specific grid colours as coherent topics while identifying black grid nodes as logically inconsistent conceptual spaces.  

The interactions driving the simulation are heterogeneous, preventing uniform convergence. Agent interactions span from purely topological network transversals, where an agent consults its social graph regardless of geographic distance, to entirely spatial gradient ascents, where an agent ignores its social ties and simply moves toward the highest local concentration of peers. This interplay between social influence and spatial popularity generates the complex dynamics required to replicate the historical case study.  

The primary observation metric used to evaluate the terminal state of the simulation is defined as the _Epistemic Share_. The system continuously tracks the global distribution of the active agent population across the distinct topical clusters established during initialization. By outputting a dynamic time-series plot of the proportional density of agents residing within each defined conceptual region, one can quantitatively measure the degree of conceptual polarization versus consensus achieved by the end of the simulation lifecycle.  

#v(0.25cm)
*II. The epistemic layer and K-means initialization*

The cognitive space of the scientific community is modeled as a continuous two-dimensional regular lattice. Each discrete spatial coordinate within this lattice is bound to a mental model. The spatial arrangement of the environment is inherently semantic; the Euclidean distance between any two points directly correlates to their conceptual similarity. For example, neighboring lattice nodes might represent two nearly identical theoretical physics models that differ solely by the inclusion or exclusion of a single causal variable or mathematical constant. Agents navigating this space are effectively engaging in epistemic exploration, gradually transitioning their beliefs from one conceptual paradigm to another.

The setup phase of this epistemic layer is computationally intensive, as it procedurally generates the semantic landscape utilizing a k-means clustering algorithm. The procedure initializes by instantiating 10.000 points, symbolizing the foundational empirical corpus of scientific literature. These points are not distributed uniformly across the grid. Instead, they are aggregated into six distinct regions representing broad scientific disciplines or topical clusters. The underlying code utilizes a normal distribution function combined with a predefined standard deviation parameter to dictate the variance and spatial spread of these points around randomized initial coordinates.

To formalize these abstract regions into concrete geometric zones, the model invokes its clustering routine. Eight centroid points are instantiated and placed at the exact same coordinates as eight of the points representing literature entities, randomly chosen. Then, each of the 10.000 points calculates its Euclidean distance to all active centroids and assigns itself to the nearest one, updating its internal color state to match the assigned centroid. Finally, each centroid recalculates its own coordinate position to match the exact mathematical mean of the X and Y coordinates of all data points currently assigned to it. The 10.000 temporary data points are then discarded.

#v(0.25cm)
*III. The social layer and temporal graph dynamics*

Superimposed directly over the epistemic lattice is a topological graph representing the social and institutional ties between the scientific agents. The initialization of this network layer is highly configurable, offering two distinct operational modes governed by the global input parameters.  

In the procedural generation mode, the system utilizes a preferential attachment algorithm to simulate an idealized, scale-free academic network. This generates a highly centralized structure where a small minority of nodes possess a vast majority of connections, effectively simulating the disproportionate influence of elite researchers.  

Conversely, in the empirical data mode, the system invokes file input operations to instantiate the network via historical data integration. The model parses an external dataset to place pre-configured agents with specific birth dates and absolute initial coordinates onto the lattice. As the simulation clock advances, a continuous background process reads a temporal edge list, dynamically creating and destroying topological links between agents precisely when the simulation tick matches the historical timestamp of the real-world interaction. This dual capacity allows the model to function both as an abstract theoretical sandbox and as a rigid historical reconstructive tool.  


=== Agent interaction mechanisms and movement dynamics

The core execution loop of the model simulates the passage of time over 100 discrete ticks. During each tick, agents execute a series of decision-making algorithms that determine their trajectory across the epistemic lattice. These movements are strictly governed by cognitive constraints and a highly specific set of attraction forces, all mathematically modulated by a universal velocity equation.  

#v(0.25cm)
*IV. Cognitive constraints: absorptive capacity, cognitive coherence and the movement speed*

The system implements theoretical concepts from the sociology of science to create rigid boundaries on agent behavior:

- The first constraint is Cognitive Coherence: The model states that an agent cannot logically adopt a mental model that is fundamentally inconsistent or scientifically invalid. In the spatial context of the simulation, grid nodes colored black represent these void spaces or incoherent theories. If an agent's calculated trajectory causes it to land on a black lattice node, the movement is immediately nullified, and the agent is forced to revert to its original coordinate position. This ensures agents only navigate through validated epistemic territory.  

- The second constraint is Absorptive Capacity: The theoretical premise asserts that scientists are incapable of making radical, instantaneous leaps in scientific thought. An agent must evaluate the cognitive Euclidean distance between its current location and its intended focal point. The movement algorithm is aborted entirely if this distance exceeds the universally defined distance threshold, effectively bounding the scope of conceptual change achievable in a single interaction cycle.

When an agent successfully targets a valid focal point within its absorptive capacity, the velocity of its traversal, defined as the step size taken per tick, is not linear. Instead, the model mathematically dictates the movement speed through a rigorously bounded logistic decay function:

$ "speed" = 1/(1 + e^(- ("birth" times "distance"))) $

This specific mathematical formulation is the core of the agent behavioral dynamics, yielding sociological implications:
- The `birth` variable represents the simulation tick at which the agent entered the system. The speed formula dictates that agents with lower birth values (which conceptually equates to older, more established, and tenured scientists) move slower across the epistemic lattice. This simulates academic rigidity and the historically observed decreasing likelihood of senior scientists radically altering their established theoretical paradigms.
- The `distance` variable further modulates the speed's sigmoid curve. This exponential relationship ensures that agents decelerate asymptotically as they approach their conceptual target, mimicking the gradual nature of scientific consensus building, where the final minor theoretical alignments take substantially longer than initial broad agreements.

#v(0.25cm)
*The five forces of epistemic attraction*

During the execution phase, agents select their focal points based on five distinct, configurable attraction forces, represented in @KnowledgeForces. Each force represents a different sociological hypothesis regarding how scientific knowledge diffuses through a population, and their simultaneous execution generates the model's complex systems behavior.

- The *social force* assumes that scientists rely heavily on their professional networks to guide their research trajectories. An agent initiates a random walk across its topological graph, selecting a target node within a maximum of three degrees of separation. If the spatial distance to this social target's current epistemic position falls below the absorptive capacity threshold, the agent traverses toward it using the standard logistic velocity.  

- The *semantic closeness force* assumes that scientists are influenced primarily by those working in similar paradigms, regardless of formal social ties. Under this logic, the agent ignores the social graph and scans the continuous spatial environment for the a random active agent within the defined distance threshold, adopting them as the primary focal point.  

- The *gravity force* simulates scenarios where researchers migrate to highly populated, trendy topics. At the beginning of this specific routine, every grid node in the environment recalculates its local population variable by exhaustively querying the number of active agents within a set radius. The agent then evaluates all immediately neighboring grid nodes and adjusts its trajectory to face the neighbor exhibiting the absolute highest population density. The velocity calculation here is uniquely modified; the logistic function substitutes spatial distance with the pure population value of the target location, meaning agents accelerate toward densely packed paradigms.  

- The *centroid coherence force* operates on the assumption that a scientific discipline is anchored by a core, highly coherent summary model. This force directs agents toward the absolute geometric center of their currently occupied topic. Agents identify the specific centroid agent that matches their lattice node's color classification and move directly toward it, simulating a pull toward theoretical purity.  

- Finally, the *conference aggregation force* simulates the effects that academic conferences have in reaching a general consensus. A random subset of twenty agents is dynamically tagged with a boolean flag representing attendance. The system calculates the aggregate center of mass of this specific cohort. All tagged attendees then temporarily bypass their standard routines to traverse toward this collective focal point, artificially forcing mixing between potentially distant paradigms.

#figure(
  image("media/knowledge_forces.pdf", width: 65%),
  caption: "Forces that drive the movement of an agent through the epistemic landscape",
  placement: auto,
) <KnowledgeForces>

=== Experimental input parameters and validation

Evaluating the performance of this model within an HPC framework requires a rigorous, systematic parameter sweep. The experimental space must push the simulation across varied phases of execution. The defined input variables for the model are detailed in @KnowledgeParameters.

The validation of the model will measure the _Epistemic Share_ of each cluster under the same generated epistemic landscape in Netlogo and Repast HPC, to validate that the dynamics of both models are identical under a certain degree of confidence.

#figure(
  table(
    columns: (50pt, 1fr, 90pt),
    inset: (x: 6pt, bottom: 8pt),
    align: (x, y) => if x == 0 { right } else { left },
    stroke: (x, y) => if y == 0 or y == 7 {
      (right: none, top: none, bottom: 0.5pt, left: none)
    } else { none },
    // header
    table.header([*Param*], [*Description*], [*Values*]),
    // rows
    [`dist`], [ Acts as a rigid threshold for absorptive capacity. It defines the maximum permissible spatial distance an agent can traverse toward a focal point in a single evaluation. ], [ $[0.0, 100.0]$ ],
    [`social-network`], [ Determines the initialization protocol for the social graph. The model can invoke file I/O to load historical nodes and edges, or can procedurally generate a scale-free network topology. ], [ {`"data"`, `"preferential attachment"` }],
    [`social`], [Toggles network-driven movement, activating the execution of the social and closeness logic calculations during the tick cycle.], [ { `true`, `false` }],
    [`gravity`], [Toggles density-driven movement, activating the population recalculations across all spatial nodes.], [ { `true`, `false` }],
    [`centroid`], [Toggles coherence-driven movement, directing agents toward the calculated geometric centers of their respective epistemic regions.], [ { `true`, `false` }],
    [`conferences`], [Toggles event-driven aggregation, activating movement towards a center point for a randomly sampled subset of attendee agents.], [ { `true`, `false` }],
    [Ticks], [The temporal duration of the simulation.], [(0, $infinity$)],
  ),
  caption: "Input parameters of the socio-epistemic knowledge spread model",
  placement: auto,
) <KnowledgeParameters>
