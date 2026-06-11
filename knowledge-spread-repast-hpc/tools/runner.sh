# !/bin/bash

RUN_RANK_ANALYSIS=false
RUN_SIZE_ANALYSIS=false
RUN_COMBINED_RANK_AND_SIZE_ANALYSIS=false
RUN_STRUCTURE_ANALYSIS=false
RUN_PARTITION_ANALYSIS=true
RUN_COMPUTE_ANALYSIS=false
RUN_MESSAGE_SIZE_ANALYSIS=false

NETWORK_FOLDER="./props/networks"
DEFAULT_NETWORK_SIZE="1000"
DEFAULT_NETWORK_STRUCTURE="hk__m_2_p_0.9"

# Run the knowledge model with from 1 to 10 processes and 5 samples
if [ "$RUN_RANK_ANALYSIS" = true ]; then
  echo "Running rank analysis..."
  MAX_PROCESSES=10
  SAMPLES=3
  for i in $(seq 1 $MAX_PROCESSES)
  do
    for j in $(seq 1 $SAMPLES)
    do
      echo "Running with $i processes..."
      export TAU_PROFILE=1
      export TAU_TRACE=1
      export TAU_BFD=1

      export PROFILEDIR=./output/tau/rank/$i/$j
      export TRACEDIR=./output/tau/rank/$i/$j
      mkdir -p $PROFILEDIR
      mkdir -p $TRACEDIR
      mpirun -n $i ./bin/knowledge ./props/config.props ./props/model.props run_id=$j birthFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${DEFAULT_NETWORK_SIZE}_birth.csv" edgeFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${DEFAULT_NETWORK_SIZE}_edges.csv"
    done
  done
else
  echo "Skipping rank analysis..."
fi

if [ "$RUN_SIZE_ANALYSIS" = true ]; then
  echo "Running size analysis..."
  SIZES=("100" "500" "1000" "1500" "2000")
  SAMPLES=3
  for size in $SIZES
  do
    for j in $(seq 1 $SAMPLES)
    do
      echo "Running with $size network size..."
      export TAU_PROFILE=1
      export TAU_TRACE=1
      export TAU_BFD=1

      export PROFILEDIR=./output/tau/network_size/$size/$j
      export TRACEDIR=./output/tau/network_size/$size/$j
      mkdir -p $PROFILEDIR
      mkdir -p $TRACEDIR
      mpirun -n 6 ./bin/knowledge ./props/config.props ./props/model.props run_id=$j birthFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${size}_birth.csv" edgeFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${size}_edges.csv"
   done
  done
else
  echo "Skipping size analysis..."
fi

if [ "$RUN_COMBINED_RANK_AND_SIZE_ANALYSIS" = true ]; then
  echo "Running combined rank and size analysis..."
  SIZES=("100" "500" "1000" "1500" "2000")
  MAX_PROCESSES=10
  SAMPLES=3
  for size in $SIZES
  do
    for i in $(seq 1 $MAX_PROCESSES)
    do
      for j in $(seq 1 $SAMPLES)
      do
        echo "Running with $i processes and $size network size..."
        export TAU_PROFILE=1
        export TAU_TRACE=1
        export TAU_BFD=1

        export PROFILEDIR=./output/tau/combined/rank_$i/size_$size/$j
        export TRACEDIR=./output/tau/combined/rank_$i/size_$size/$j
        mkdir -p $PROFILEDIR
        mpirun -n $i ./bin/knowledge ./props/config.props ./props/model.props run_id=$j birthFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${size}_birth.csv" edgeFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${size}_edges.csv"
      done
    done
  done
else
  echo "Skipping combined rank and size analysis..."
fi

# Run with multiple network structures
if [ "$RUN_STRUCTURE_ANALYSIS" = true ]; then
  echo "Running structure analysis..."
  STRUCTURES=("hk__m_2_p_0.9" "hk__m_10_p_0.9" "hk__m_5_p_0.9" "hk__m_2_p_0.3" "hk__m_10_p_0.3" "hk__m_5_p_0.3" "hk__m_2_p_0.1" "hk__m_10_p_0.1" "hk__m_5_p_0.1" "ws__k_40_p_0.01" "ws__k_40_p_0.2" "ws__k_40_p_0.8" "ws__k_60_p_0.01" "ws__k_60_p_0.2" "ws__k_60_p_0.8" "ws__k_80_p_0.01" "ws__k_80_p_0.2" "ws__k_80_p_0.8" "ws__k_100_p_0.01" "ws__k_100_p_0.1" "ws__k_100_p_0.05" "ws__k_100_p_0.5" "ws__k_100_p_0.8" "ws__k_100_p_0.2")
  SAMPLES=1
  for structure in $STRUCTURES
  do
    for j in $(seq 1 $SAMPLES)
    do
      echo "Running with $structure network structure..."
      export TAU_PROFILE=1
      export TAU_TRACE=1
      export TAU_BFD=1

      export PROFILEDIR=./output/tau/structure/$structure/$j
      export TRACEDIR=./output/tau/structure/$structure/$j
      mkdir -p $PROFILEDIR
      mkdir -p $TRACEDIR
      mpirun -n 6 ./bin/knowledge ./props/config.props ./props/model.props run_id=$j birthFile="${NETWORK_FOLDER}/${structure}_network_${DEFAULT_NETWORK_SIZE}_birth.csv" edgeFile="${NETWORK_FOLDER}/${structure}_network_${DEFAULT_NETWORK_SIZE}_edges.csv"
    done
  done
else
  echo "Skipping structure analysis..."
fi

if [ "$RUN_PARTITION_ANALYSIS" = true ]; then
  echo "Running partition analysis..."
  PARTITION_STRATEGIES=("node_id_modulo" "node_community_modulo")
  SAMPLES=3
  for strategy in $PARTITION_STRATEGIES
  do
    for j in $(seq 1 $SAMPLES)
    do
      echo "Running with $strategy partition strategy..."
      export TAU_PROFILE=1
      export TAU_TRACE=1
      export TAU_BFD=1

      export PROFILEDIR=./output/tau/partition/$strategy/$j
      export TRACEDIR=./output/tau/partition/$strategy/$j
      mkdir -p $PROFILEDIR
      mkdir -p $TRACEDIR
      mpirun -n 6 ./bin/knowledge ./props/config.props ./props/model.props run_id=$j birthFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${DEFAULT_NETWORK_SIZE}_birth.csv" edgeFile="${NETWORK_FOLDER}/${DEFAULT_NETWORK_STRUCTURE}_network_${DEFAULT_NETWORK_SIZE}_edges.csv" partitionStrategy=$strategy
    done
  done
else
  echo "Skipping partition analysis..."
fi
