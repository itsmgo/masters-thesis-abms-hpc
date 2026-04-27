import argparse
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
import numpy as np
from glob import glob

plt.style.use("ggplot")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Visualize agent trajectories from CSV data.")
    parser.add_argument("locations_file", type=str, help="Path to the CSV file containing the locations data.")
    args = parser.parse_args()

    # Load all files
    files = sorted(glob(args.locations_file))
    df = pd.concat([pd.read_csv(f) for f in files], ignore_index=True)

    # Ensure sorted trajectories
    df = df.sort_values(["agent_id", "tick"])

    fig, ax = plt.subplots(figsize=(12, 12))

    for agent_id, g in df.groupby("agent_id"):
        g = g.sort_values("tick")

        x = g["x"].values
        y = g["y"].values
        ticks = g["tick"].values
        colors = g["color"].values

        # Build line segments
        points = np.array([x, y]).T.reshape(-1, 1, 2)
        segments = np.concatenate([points[:-1], points[1:]], axis=1)
        segments += 0.5  # Center segments in the grid cells

        # Color segments by time
        lc = LineCollection(
            segments,
            cmap="viridis",
            norm=plt.Normalize(0, 90)
        )
        lc.set_array(ticks[:-1])
        lc.set_linewidth(2)

        ax.add_collection(lc)

        # Detect color changes
        color_change_idx = np.where(np.diff(colors) != 0)[0] + 1
        #
        # Define discrete colormap (8 colors)
        cmap = plt.get_cmap("tab20b", 8)

        # Mark color change points with actual colors
        ax.scatter(x[color_change_idx] + 0.5, y[color_change_idx] + 0.5, c=cmap(colors[color_change_idx]), s=20, zorder=15, marker="x")

        color_change_idx = np.concatenate(([0], [len(colors) - 1]))  # First and the last point
        ax.scatter(x[color_change_idx] + 0.5, y[color_change_idx] + 0.5, c=cmap(colors[color_change_idx]), s=30, zorder=5)


    ax.autoscale()
    ax.set_aspect("equal")
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    ax.set_xlim(-49, 49)
    ax.set_ylim(-49, 49)
    ax.set_title("Agent Trails (color shows time, markers show color changes)")

    plt.tight_layout()
    plt.show()
