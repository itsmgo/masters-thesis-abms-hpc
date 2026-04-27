import argparse
import os
import networkx as nx
import matplotlib.pyplot as plt
from glob import glob

plt.style.use("ggplot")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Visualize social network evolution from GML data.")
    parser.add_argument("rank", type=int, help="Rank of the process (used to identify the correct files).")
    parser.add_argument("network_files", type=str, help="Path to the GML files containing the network data.")
    args = parser.parse_args()

    # Load all files
    files = sorted(glob(args.network_files))

    # Colormap
    cmap = plt.get_cmap("tab20b", 8)

    # Extract tick number
    def extract_tick(filename):
        base = os.path.basename(filename)
        name, _ = os.path.splitext(base)
        parts = name.split("_")
        return int(parts[-1])

    files = sorted(files, key=extract_tick)

    for file in files:

        tick = extract_tick(file)

        # Load graph
        G = nx.read_gml(file, label = 'id')

        # Positions
        pos = {n: (float(d["x"]) + 0.5, float(d["y"]) + 0.5) for n, d in G.nodes(data=True)}

        # Separate nodes
        normal_nodes = []
        ghost_nodes = []

        normal_colors = []
        ghost_colors = []

        for n, d in G.nodes(data=True):
            c = int(d.get("color", 0))

            if int(d.get("isGhost", 0)) == 1:
                ghost_nodes.append(n)
                ghost_colors.append(cmap(c))
            else:
                normal_nodes.append(n)
                normal_colors.append(cmap(c))

        fig, ax = plt.subplots(figsize=(8, 8))

        # Draw edges
        nx.draw_networkx_edges(
            G,
            pos,
            ax=ax,
            edge_color="gray",
            width=1,
            alpha=0.6
        )

        # Draw normal nodes
        nx.draw_networkx_nodes(
            G,
            pos,
            nodelist=normal_nodes,
            node_color=normal_colors,
            node_size=25,
            ax=ax
        )

        # Draw ghost nodes
        nx.draw_networkx_nodes(
            G,
            pos,
            nodelist=ghost_nodes,
            node_color=ghost_colors,
            node_size=10,
            alpha=0.25,
            ax=ax
        )

        ax.set_title(f"Network evolution — tick {tick}")
        ax.set_aspect("equal")
        ax.set_xlim(-49, 49)
        ax.set_ylim(-49, 49)
        ax.axis("off")

        # Save frame
        frame_path = os.path.join(f"frames/frame_{args.rank}_{tick:05d}.png")
        plt.savefig(frame_path, dpi=150, bbox_inches="tight")
        plt.close()

