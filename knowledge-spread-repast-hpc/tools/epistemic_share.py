import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

plt.style.use('ggplot')

if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser(description='Analyze dynamic graph results')
    argument_parser.add_argument('--input', type=str, default='output/dynamic_results.csv',
                                    help='Path to the CSV file containing dynamic graph results')
    args = argument_parser.parse_args()

    data = pd.read_csv(args.input)

    # Total counts over time
    data.plot(x='tick', y=["total_blue","total_orange","total_red","total_yellow","total_green","total_purple","total_magenta","total_white"], figsize=(16, 9))
    plt.title('Epistemic Share over time')
    plt.xlabel('Tick')
    plt.ylabel('Agent count')
    plt.legend()
    plt.show()
