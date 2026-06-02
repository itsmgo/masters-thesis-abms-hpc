import argparse
import os
import matplotlib.pyplot as plt
import matplotlib as mpl
import networkx as nx
import numpy as np

plt.style.use("ggplot")
plt.rcParams['image.cmap'] = 'viridis'
viridis_colors = plt.cm.viridis(np.linspace(0, 1, 5))
plt.rcParams['axes.prop_cycle'] = mpl.cycler(color=viridis_colors)

if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(description="Generate synthetic networks")
    arg_parser.add_argument("--network", type=str, default="./networks/ws__k_100_p_0.5_network_1000.gml", help="Path to the GML file of the network to visualize")
    args = arg_parser.parse_args()

    # G = nx.read_gml(args.network)
    # G = nx.barabasi_albert_graph(1000, 10)
    # G = nx.erdos_renyi_graph(1000, 0.1)
    # G = nx.watts_strogatz_graph(1000, 100, 0.01)
    G = nx.powerlaw_cluster_graph(n=10000, m=2, p=0.9)

    # print avg degree and cluster coefficient
    avg_degree = sum(dict(G.degree()).values()) / G.number_of_nodes()
    avg_clustering = nx.average_clustering(G)
    print(f"Average Degree: {avg_degree:.2f}")
    print(f"Average Clustering Coefficient: {avg_clustering:.4f}")

    # plot histogram with degree distribution
    plt.figure(figsize=(8, 8))
    degree_sequence = sorted([d for n, d in G.degree()], reverse=True)
    plt.hist(degree_sequence, bins=10, edgecolor="#fefefe")
    plt.xlabel("Degree", fontsize=12)
    plt.ylabel("Log Frequency", fontsize=12)
    plt.yscale("log")
    plt.grid(axis="y", alpha=0.75)
    plt.show()
    

    # plot network nodes
    # plt.figure(figsize=(12, 12))
    # plt.title("GML Network Visualization", fontsize=14, fontweight="bold")
    #
    # pos = nx.spring_layout(G, seed=42)
    # nx.draw_networkx_nodes(
    #     G, pos, node_size=700, node_color="skyblue", edgecolors="black"
    # )
    # nx.draw_networkx_edges(G, pos, width=2, alpha=0.6, edge_color="gray")
    # nx.draw_networkx_labels(G, pos, font_size=12, font_family="sans-serif")
    #
    # plt.axis("off")
    # plt.tight_layout()
    # plt.show()
