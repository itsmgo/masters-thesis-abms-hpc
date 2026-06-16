#v(10pt)
#align(
  center,
  [
    #image("media/Rovira_i_Virgili_University.png", width: 50%)
    #v(10pt)
    #image("media/logo_blau_uoc.png", width: 50%)
  ]
)

    #v(10pt)
#align(center, text(13pt, "Universitat Rovira i Virgili (URV) | Universitat Oberta de Catalunya (UOC)"))
#align(center, text(14pt, "Master's in Computational Engineering and Mathematics"))
#v(50pt)

#align(center, text(22pt, [Final Master Project]))
#align(center, text(16pt, [Area: High Performance Computing]))
#align(center, box(inset: (x: 20pt, y:10pt), text(18pt, [*Performance analysis of social network models in agent based systems*])))

#v(50pt)

#align(center,
table(
  columns: (100pt, 200pt),
  inset: (x: 0pt, y: 5pt),
  align: (x, y) => if x == 0 { left } else { right },
  stroke: (x, y) => if y == 0 {
    (right: none, top: 0.5pt, bottom: none, left: none)
  } else if y == 4 {
    (right: none, bottom: 0.5pt, top: none, left: none)
  } else { none },
  [], [],
  [Author:], [Martí Gimeno Ortí],
  [Tutor:], [Andreu Moreno Vendrell],
  [Professor:], [Josep Jorba Esteve],
  [], [],
))
#v(20pt)

#align(center, text(12pt, "Barcelona, 2025-2026"))

#v(1fr)

#pagebreak()

El Dr. Josep Jorba Esteve, certifica que l'estudiant Martí Gimeno Ortí ha elaborat el treball sota la seva tutoria i autoriza la presentació d'aquesta memòria per la seva evaluació.

Firma del tutor:

#pagebreak()

#text(18pt, [*License*])


#box(
  inset: (left: 1cm, y:0cm, right: 2cm),
  [
   Copyright (c) 2026 MARTI GIMENO ORTI. #linebreak()
   Permission is granted to copy, distribute and/or modify this document 
   under the terms of the GNU Free Documentation License, Version 1.3 
   or any later version published by the Free Software Foundation; 
   with no Invariant Sections, no Front-Cover Texts, and no Back-Cover Texts.
  ]
)

#pagebreak()
#align(center, [*INDEX CARD OF THE FINAL MASTER PROJECT*])
#align(center,
table(
  columns: (auto, 1fr),
  align: (x, y) => if x == 0 { right } else { left },
  stroke: (x, y) => if y == 0 {
    (right: none, top: 0.5pt, bottom: none, left: none)
  } else if y == 10 {
    (right: none, bottom: 0.5pt, top: none, left: none)
  } else { none },
  [], [],
  [Author:], [Martí Gimeno Ortí],
  [Tutor:], [Andreu Moreno Vendrell],
  [Professor:], [Josep Jorba Esteve],
  [Delivery date:], [06/2026],
  [Degree:], [Master's in Computational Engineering and Mathematics],
  [Area of work:], [High Performance Computing],
  [Language:], [English],
  [Keywords:], [High Performance Computing (HPC), Agent-Based Modelling (ABM), Performance analysis],
  [Summary:], [
This work investigates the performance and scalability of distributed Agent-Based Models (ABMs) executed on High-Performance Computing (HPC) platforms. The thesis focuses on two network-based social simulation models: a misinformation diffusion model and a socio-epistemic knowledge spread model.

The original NetLogo implementations were analyzed and reimplemented using the Repast HPC framework, which combines C++ and the Message Passing Interface (MPI) to support distributed-memory parallel execution. Validation experiments confirmed that the Repast HPC versions accurately reproduced the behavior of the original models, ensuring the reliability of the subsequent performance analysis.

Performance measurements were obtained using the TAU Performance System, which allowed detailed profiling of execution time, communication overhead, and process synchronization costs. Extensive experiments were conducted to evaluate the effects of network topology, partitioning strategy, problem size, computational workload, communication requirements, and the number of MPI processes.

The results show that partitioning quality is the primary factor affecting performance in distributed network-based ABMs. Community-aware partitioning significantly reduces ghost-agent synchronization overhead by preserving network locality and minimizing inter-process communication. The study also reveals that performance bottlenecks differ between models: the misinformation diffusion model is mainly communication-bound, whereas the socio-epistemic model is dominated by the cost of managing extended neighborhood information. Overall, the findings demonstrate that distributed execution can substantially improve the performance of large-scale agent-based simulations when network topology and partitioning strategies are carefully considered.
],
[], [],
))
#pagebreak()
#align(center,
table(
  columns: (auto, 1fr),
  align: left,
  stroke: (x, y) => if y == 0 {
    (right: none, top: 0.5pt, bottom: none, left: none)
  } else if y == 2 {
    (right: none, bottom: 0.5pt, top: none, left: none)
  } else { none },
  [], [],
  [Abstract:],
  [
  Agent-Based Modeling (ABM) is widely used to study complex social systems, but large-scale simulations often require computational resources beyond those available in sequential environments. High-Performance Computing (HPC) provides a means to overcome these limitations through distributed parallel execution. This thesis evaluates the performance of distributed ABMs and identifies the factors that determine their scalability.

  Two network-based social simulation models were selected as case studies: a misinformation diffusion model and a socio-epistemic knowledge spread model. Both models were originally implemented in NetLogo and were reengineered using the Repast HPC framework, a distributed-memory simulation platform based on C++ and MPI. Validation experiments verified that the distributed implementations preserved the behavior of the original models.

  The performance analysis was conducted using the TAU Performance System, which provided detailed measurements of execution time and communication overhead. A comprehensive experimental evaluation explored the influence of network topology, partitioning strategy, network size, computational load, communication requirements, and the number of MPI ranks.

  The results indicate that partitioning quality is the dominant factor governing performance in distributed network-based simulations. Community-aware partitioning strategies significantly reduce synchronization costs by minimizing the number of ghost agents and preserving network locality. Furthermore, the study shows that different models may exhibit distinct bottlenecks, ranging from communication volume to the overhead associated with maintaining distributed neighborhood information. The findings confirm that HPC can substantially accelerate large-scale ABMs, provided that network structure and partitioning strategies are carefully considered during model design and deployment.
  ],
  [], [],
))
