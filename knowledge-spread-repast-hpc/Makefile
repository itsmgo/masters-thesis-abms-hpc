include ./.env

.PHONY: all
all:

.PHONY: clean_output_files
clean_output_files:
	rm -f *.csv rm - f*.txt rm - f./ output/*.csv
	rm -f ./output/*.txt
	rm -f ./logs/*.*

.PHONY: clean_compiled_files
clean_compiled_files:
	rm -f *.exe
	rm -f ./bin/*.exe
	rm -f *.o
	rm -f ./object/*.o
	
.PHONY: clean
clean: clean_compiled_files clean_output_files

.PHONY: build
build: clean_compiled_files
	$(MPICXX) $(REPAST_HPC_DEFINES) $(BOOST_INCLUDE) $(REPAST_HPC_INCLUDE) -I./include -c ./src/main.cpp -o ./objects/main.o
	$(MPICXX) $(REPAST_HPC_DEFINES) $(BOOST_INCLUDE) $(REPAST_HPC_INCLUDE) -I./include -c ./src/KnowledgeModel.cpp -o ./objects/KnowledgeModel.o
	$(MPICXX) $(REPAST_HPC_DEFINES) $(BOOST_INCLUDE) $(REPAST_HPC_INCLUDE) -I./include -c ./src/KnowledgeAgent.cpp -o ./objects/KnowledgeAgent.o
	$(MPICXX) $(BOOST_LIB_DIR) $(REPAST_HPC_LIB_DIR) -o ./bin/knowledge  ./objects/main.o ./objects/KnowledgeModel.o ./objects/KnowledgeAgent.o $(REPAST_HPC_LIB) $(BOOST_LIBS)
