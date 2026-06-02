import argparse
import os

import networkx as nx
import numpy as np


def network_factories():
    # ER = lambda N: nx.erdos_renyi_graph(N, 0.01)
    # ER2 = lambda N: nx.erdos_renyi_graph(N, 0.05)
    # ER3 = lambda N: nx.erdos_renyi_graph(N, 0.08)
    # BA = lambda N: nx.barabasi_albert_graph(N, 5)
    # BA2 = lambda N: nx.barabasi_albert_graph(N, 10)
    # BA3 = lambda N: nx.barabasi_albert_graph(N, 100)
    WS = lambda N: nx.connected_watts_strogatz_graph(N, 100, 0.2)
    # WS2 = lambda N: nx.connected_watts_strogatz_graph(N, 40, 0.2)
    # WS3 = lambda N: nx.connected_watts_strogatz_graph(N, 40, 0.8)
    # WS4 = lambda N: nx.connected_watts_strogatz_graph(N, 60, 0.01)
    # WS5 = lambda N: nx.connected_watts_strogatz_graph(N, 60, 0.2)
    # WS6 = lambda N: nx.connected_watts_strogatz_graph(N, 60, 0.8)
    # WS7 = lambda N: nx.connected_watts_strogatz_graph(N, 80, 0.01)
    # WS8 = lambda N: nx.connected_watts_strogatz_graph(N, 80, 0.2)
    # WS9 = lambda N: nx.connected_watts_strogatz_graph(N, 80, 0.8)
    # HK = lambda N: nx.powerlaw_cluster_graph(n=N, m=2, p=0.9)
    # HK2 = lambda N: nx.powerlaw_cluster_graph(n=N, m=10, p=0.9)
    # HK3 = lambda N: nx.powerlaw_cluster_graph(n=N, m=5, p=0.9)
    # HK4 = lambda N: nx.powerlaw_cluster_graph(n=N, m=2, p=0.3)
    # HK5 = lambda N: nx.powerlaw_cluster_graph(n=N, m=10, p=0.3)
    # HK6 = lambda N: nx.powerlaw_cluster_graph(n=N, m=5, p=0.3)
    # HK7 = lambda N: nx.powerlaw_cluster_graph(n=N, m=2, p=0.1)
    # HK8 = lambda N: nx.powerlaw_cluster_graph(n=N, m=10, p=0.1)
    # HK9 = lambda N: nx.powerlaw_cluster_graph(n=N, m=5, p=0.1)


    return {
        # "hk__m_2_p_0.9": HK,
        # "hk__m_10_p_0.9": HK2,
        # "hk__m_5_p_0.9": HK3,
        # "hk__m_2_p_0.3": HK4,
        # "hk__m_10_p_0.3": HK5,
        # "hk__m_5_p_0.3": HK6,
        # "hk__m_2_p_0.1": HK7,
        # "hk__m_10_p_0.1": HK8,
        # "hk__m_5_p_0.1": HK9,
        # "er__p_0.01": ER,
        # "er__p_0.05": ER2,
        # "er__p_0.08": ER3,
        # "ba__m_5": BA,
        # "ba__m_10": BA2,
        # "ba__m_100": BA3,
        "ws__k_100_p_0.2": WS,
        # "ws__k_40_p_0.2": WS2,
        # "ws__k_40_p_0.8": WS3,
        # "ws__k_60_p_0.01": WS4,
        # "ws__k_60_p_0.2": WS5,
        # "ws__k_60_p_0.8": WS6,
        # "ws__k_80_p_0.01": WS7,
        # "ws__k_80_p_0.2": WS8,
        # "ws__k_80_p_0.8": WS9,
    }

if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(description="Generate synthetic networks")
    arg_parser.add_argument("--output_dir", type=str, default=".", help="Directory to save the generated networks")
    args = arg_parser.parse_args()
    networks = network_factories()

    # write to disk in GML format
    for size in [1000, 10000, 20000, 30000, 40000, 50000]:
        for net_name, net_factory in networks.items():
            print(f"Generating {net_name} network with {size} nodes...")
            G = net_factory(size)
            print(f"Avg degree for {net_name} with {size} nodes: {np.mean([d for _, d in G.degree()])}")
            print("Avg clustering coefficient: ", nx.average_clustering(G))
            nx.write_gml(G, os.path.join(args.output_dir, f"{net_name}_network_{size}.gml"))
