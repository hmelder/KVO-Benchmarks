import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys
from glob import glob

def process_csv(file_paths):
    # Combine all CSV files into a single DataFrame
    data_frames = []
    for file_path in file_paths:
        df = pd.read_csv(file_path, header=None, names=["Name", "Options", "Iterations", "ObserverCallbackCount", "Milliseconds"])
        data_frames.append(df)
    data = pd.concat(data_frames, ignore_index=True)

    return data

def generate_statistics(df, category):
    stats = df.describe()
    print(f"Statistics for {category}:\n{stats}\n")

def plot_category(data, category):
    # Filter data by category name
    category_data = data[data["Name"] == category]

    # Generate statistics
    generate_statistics(category_data, category)

    # Create plot
    plt.figure(figsize=(10, 6))
    for option in category_data["Options"].unique():
        option_data = category_data[category_data["Options"] == option]
        plt.plot(option_data["Iterations"], option_data["Milliseconds"], label=f"Option {option}")

    plt.title(category)
    plt.xlabel("Iterations")
    plt.ylabel("Milliseconds")
    plt.legend()
    plt.grid(True)
    plt.show()

def main():
    if len(sys.argv) < 2:
        print("Usage: python benchmark_plot.py <csv_file1> <csv_file2> ...")
        sys.exit(1)

    file_paths = sys.argv[1:]
    data = process_csv(file_paths)

    # Get unique categories
    categories = data["Name"].unique()

    for category in categories:
        plot_category(data, category)

if __name__ == "__main__":
    main()
