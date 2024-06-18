import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys
import os

def extract_info_from_filename(filename):
    basename = os.path.basename(filename)
    parts = basename.replace('.csv', '').split('-')
    machine = parts[0]
    cpu = parts[1]
    implementation = parts[2].replace('_', ' ')
    test = parts[3].replace('_', ' ')
    options = ' '.join(parts[4:]).replace('_', ' ') if len(parts) > 4 else ''
    return machine, cpu, implementation, test, options

def process_csv(file_path):
    df = pd.read_csv(file_path, header=None, names=["Name", "Options", "Iterations", "ObserverCallbackCount", "Milliseconds"])
    return df

def generate_statistics(df, label):
    stats = df.describe()
    print(f"Statistics for {label}:\n{stats}\n")

def plot_comparison(data_frames, labels):
    options_set = set()
    name_set = set()
    options_name_set = set()
    
    for df in data_frames:
        options_set.update(df["Options"].unique())
        name_set.update(df["Name"].unique())

    # Cartesian product of options and names
    for option in options_set:
        for name in name_set:
            options_name_set.add((option, name))

    num_plots = len(options_name_set)
    num_cols = 2  # Number of columns in the tiled plot
    num_rows = (num_plots + num_cols - 1) // num_cols  # Calculate rows needed
    
    fig, axs = plt.subplots(num_rows, num_cols, figsize=(15, num_rows * 5))
    axs = axs.flatten()  # Flatten in case of 2D array

    for ax, (option, name) in zip(axs, options_name_set):
        for df, label in zip(data_frames, labels):
            option_data = df[(df["Options"] == option) & (df["Name"] == name)]
            if not option_data.empty:
                ax.plot(option_data["Iterations"], option_data["Milliseconds"], label=label)
        
        ax.set_title(f"Comparison of {name} for Option {option}")
        ax.set_xlabel("Iterations")
        ax.set_ylabel("Milliseconds")
        ax.legend()
        ax.grid(True)
    
    plt.tight_layout()
    plt.show()


def main():
    if len(sys.argv) < 2:
        print("Usage: python benchmark_plot.py <csv_file1> <csv_file2> ...")
        sys.exit(1)

    file_paths = sys.argv[1:]
    data_frames = []
    labels = []

    for file_path in file_paths:
        df = process_csv(file_path)
        machine, cpu, implementation, test, options = extract_info_from_filename(file_path)
        label = f"{machine} {cpu} {implementation} {test} {options}".strip()
        generate_statistics(df, label)
        data_frames.append(df)
        labels.append(label)

    plot_comparison(data_frames, labels)

if __name__ == "__main__":
    main()
