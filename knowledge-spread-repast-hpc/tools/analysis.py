import argparse
from glob import glob

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

plt.style.use("ggplot")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Visualize grid and centroids from CSV data.")
    parser.add_argument("space_file", type=str, help="Path to the CSV file containing the spatial data.")
    parser.add_argument("agents_file", type=str, help="Path to the CSV file containing the network data.")
    args = parser.parse_args()

    # Load CSV
    df = pd.read_csv(args.space_file)

    # Grid size
    x_min, x_max = -49, 49
    y_min, y_max = -49, 49

    width = x_max - x_min + 1
    height = y_max - y_min + 1

    # Create grid initialized with NaN
    grid = np.full((height, width), np.nan)

    # Fill grid with colors
    for _, row in df.iterrows():
        x = int(row["x"])
        y = int(row["y"])
        color = int(row["color"])

        gx = x - x_min
        gy = y - y_min
        grid[gy, gx] = color

    # Define discrete colormap (8 colors)
    cmap = plt.get_cmap("tab20b", 8)

    # Plot grid
    plt.figure(figsize=(12, 12))
    plt.imshow(
        grid,
        origin="lower",
        extent=[x_min, x_max + 1, y_min, y_max + 1],
        cmap=cmap,
        interpolation="nearest"
    )

    # Extract unique centroids
    centroids = df[["centroid_x", "centroid_y"]].drop_duplicates()

    # Plot centroids
    plt.scatter(
        centroids["centroid_x"] + 0.5,
        centroids["centroid_y"] + 0.5,
        c="white",
        marker="x",
        linewidth=4,
        s=150,
        label="Centroids"
    )

    # id,name,x,y,color
    files = sorted(glob(args.agents_file))
    df = pd.concat([pd.read_csv(f) for f in files], ignore_index=True)

    cmap = plt.get_cmap("tab10", 8)
    plt.scatter(
        df["x"] + 0.5,
        df["y"] + 0.5,
        c=cmap(df["color"]),
        marker="o",
        s=30,
        label="Agents"
    )

    plt.xlim(x_min, x_max)
    plt.ylim(y_min, y_max)
    plt.xlabel("x")
    plt.ylabel("y")
    plt.title("Grid Colored by Cell Color with Centroids")
    plt.legend()
    plt.grid(False)
    plt.tight_layout()
    plt.show()
