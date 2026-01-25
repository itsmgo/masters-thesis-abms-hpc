= Model descriptions

The evaluation of High Performance Computing frameworks for Agent-Based Modelling and Simulation requires the selection of baseline models that are robust, computationally significant, and highly relevant to contemporary science. Following the methodology and objectives outlined in the introductory chapter, the models selected for this performance analysis operate within the domain of computational social science, specifically focusing on the diffusion of information in a social network. This chapter provides an exhaustive analysis of the models internal mechanisms, mathematical foundations, agent interactions, and the specific variables that will govern the subsequent HPC implementation and benchmarking phases.

== Misinformation diffusion model

The first selected model, archived in the COMSES Net Computational Model Library under version 1.0.0, is titled _"Controlling the Misinformation Diffusion in Social Media by the Effect of Different Classes of Agents"_ @misinformationArticle @misinformationComses and describes the spread of misinformation and the corresponding countermeasures in digital social networks.

This model represents a sophisticated architectural extension of the foundational Susceptible-Believer-FactChecker (SBFC) epidemic model originally proposed by Tambuscio et al. @TambuscioRuffoFlamminiMenczer2015 @Tambuscio2020. While the original SBFC framework established the mathematical bedrock for simulating the competitive diffusion of a viral hoax and its debunking information within a homogeneous population, the selected extended model introduces significant topological and behavioral complexities that mirror real-world dynamics. By categorizing the network nodes into distinct, heterogeneous agent types: Scholars, Influencers, Normal Agents, and Bots, the model accurately captures the asymmetric influence and dynamic belief structures present in real-world platforms like Facebook @Willmore2016Analysis.

From a computational perspective, this selected model serves as an ideal stress-test for HPC performance analysis. The introduction of heterogeneous agent classes and targeted intervention strategies significantly increases the computational load required for each agent evaluation cycle. Furthermore, simulating this environment over a large-scale, highly connected graph introduces intricate memory access patterns and inter-agent communication dependencies that are notoriously difficult to parallelize efficiently. These characteristics are precisely what expose the performance bottlenecks, parallelization inefficiencies, and synchronization overheads inherent in distributed-memory platforms such as Repast HPC. 

=== Epidemiological Foundations: The Baseline SBFC Framework

The Susceptible-Believer-FactChecker model conceptualizes the spread of misinformation not as a simple, unidirectional contagion, but as a complex, simultaneous competitive process between a virus (the hoax) and its cure (the debunking information). By modeling hoaxes analogously to biological viruses, the framework borrows heavily from traditional compartmental epidemic models such as the Susceptible-Infected-Recovered (SIR) and Susceptible-Infected-Susceptible (SIS) paradigms. However, it splits the "Infected" compartment into two distinct and adversarial sub-compartments, creating a much more dynamic state space. 

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

From a high-performance computing perspective, the evaluation of $n_i^B (t)$ and $n_i^F (t)$ represents one of the most significant computational burdens in the simulation. For an agent to calculate its spreading functions, the processor must fetch the state data of every single vertex connected to agent $i$. In dense, scale-free networks, a single agent may possess thousands of edges, requiring massive, non-contiguous memory access operations that frequently result in cache misses and degraded performance.

#v(0.5cm)
*IV. Results*

The original authors of the SBFC model conducted extensive mean-field approximations to understand the infinite-time limit behavior of the system, assuming a homogeneous network where all vertices have the same degree $k$. Their mathematical analysis demonstrated that the density of susceptible individuals at equilibrium ($S_infinity$) depends solely on the spreading rate $beta$ and the forgetting probability $p_"forget"$, calculated as:

$ S_infinity = p_"forget" / (beta + p_"forget") $

The core analytical breakthrough of the baseline model, however, was the derivation of a hard threshold for the verification probability that guarantees the complete eradication of the hoax from the network, achieving a state where $B_infinity = 0$. By setting the equilibrium equation for Believers to zero and solving for $p_"verify"$, the sufficient condition for hoax eradication is expressed as:

$ p_"verify" >= (2alpha)/(1-alpha) dot p_"forget" $

This critical equation establishes that the minimum required fact-checking effort to eradicate a hoax is not linear. Instead, it scales non-linearly with the hoax's inherent credibility $alpha$ and proportionally with the network's overall forgetting rate. If a hoax is highly credible ($alpha$ approaches 1), the required verification effort approaches infinity. While this elegant mathematical threshold holds true for homogeneous, mean-field approximations, the dynamics alter significantly, and become vastly more difficult to predict, when network topologies exhibit real-world scale-free properties and when agent behaviors become heterogeneous. This limitation in the baseline model necessitates the transition to the extended model selected for this thesis.

=== Architectural Enhancements: Heterogeneous Agent Classes

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


=== Experimental Input Parameters

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


===  Validation Methodology

To verify that the newly developed C++ Repast HPC implementation correctly captures the intricate dynamics of the original model, a rigorous validation protocol must be established. Because the underlying transition functions are highly stochastic, direct 1:1 validation of a single run is mathematically impossible; instead, the validation framework must rely on demonstrating statistical equivalence over large sample sizes.

The primary metrics for validation will be the mean densities of the three agent states $"B"_infinity$, $"FC"_infinity$, and $"S"_infinity$, at the conclusion of the 168-tick simulation cycle. The baseline experiments in the original literature generated 4 replicates for each of the 13,824 settings. Analysis of these replicates revealed a standard deviation of less than 5% relative to the total agent population, indicating exceptionally high macroscopic model stability despite individual micro-level stochasticity.

The Repast HPC model will be executed using identical input parameter matrices and identical network topology. The resulting macroscopic curves must statistically match the baselines within a strict 95% confidence interval. For example, the explosive, non-linear growth of Believers when hoax credibility is maximized ($alpha=0.8$), versus the total systemic dominance of Fact-Checkers when hoax credibility is minimized ($alpha=0.3$), must be perfectly replicated. Additionally, the localized, systemic effects of the heterogeneous classes, such as the specific 8-9% reduction in the global Believer population when the Scholar class is properly configured and educated, must be demonstrably reproducible in the parallelized environment.

Only once this statistical parity is definitively achieved can the true performance analysis phase commence. The benchmark suite will then systematically scale the agent population and the allocated MPI processes, rigorously recording total execution time, memory overhead, parallel efficiency, and MPI communication latency to fully expose, analyze, and document the architectural bottlenecks of distributing complex social network models across modern High Performance Computing environments.
