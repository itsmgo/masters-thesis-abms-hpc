import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

plt.style.use('ggplot')

if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser(description='Analyze dynamic graph results')
    argument_parser.add_argument('--input', type=str, default='output/validation/dynamic_results.csv',
                                    help='Path to the CSV file containing dynamic graph results')
    args = argument_parser.parse_args()

    data = pd.read_csv(args.input)

    # Total counts over time
    data.plot(x='tick', y=['total_believers', 'total_fact_checkers', 'total_susceptibles'], figsize=(16, 9))
    plt.title('Believers vs FactCheckers vs Susceptibles over time')
    plt.xlabel('Tick')
    plt.ylabel('Agent count')
    plt.legend()
    plt.show()

    # Influencer counts over time
    data.plot(x='tick', y=['influencer_believers', 'influencer_fact_checkers', 'influencer_susceptibles'], figsize=(16, 9))
    plt.xlabel('Tick')
    plt.ylabel('Influencer count')
    plt.legend()
    plt.show()

    # Scholar counts over time
    data.plot(x='tick', y=['scholar_believers', 'scholar_fact_checkers', 'scholar_susceptibles'], figsize=(16, 9))
    plt.xlabel('Tick')
    plt.ylabel('Scholar count')
    plt.legend()
    plt.show()

    # Normal counts over time
    data.plot(x='tick', y=['normal_believers', 'normal_fact_checkers', 'normal_susceptibles'], figsize=(16, 9))
    plt.xlabel('Tick')
    plt.ylabel('Normal count')
    plt.legend()
    plt.show()

    # stacked area chart of influencers believe state over time
    data.plot(x='tick', y=['influencer_believers', 'influencer_fact_checkers', 'influencer_susceptibles'], kind='area', stacked=True, figsize=(16, 9))
    plt.title('Influencers Belief State over time')
    plt.xlabel('Tick')
    plt.ylabel('Count')
    plt.legend()
    plt.show()

    # stacked area chart of scholars believe state over time
    data.plot(x='tick', y=['scholar_believers', 'scholar_fact_checkers', 'scholar_susceptibles'], kind='area', stacked=True, figsize=(16, 9))
    plt.title('Scholars Belief State over time')
    plt.xlabel('Tick')
    plt.ylabel('Count')
    plt.legend()
    plt.show()

    # stacked area chart of normals believe state over time
    data.plot(x='tick', y=['normal_believers', 'normal_fact_checkers', 'normal_susceptibles'], kind='area', stacked=True, figsize=(16, 9))
    plt.title('Normals Belief State over time')
    plt.xlabel('Tick')
    plt.ylabel('Count')
    plt.legend()
    plt.show()

